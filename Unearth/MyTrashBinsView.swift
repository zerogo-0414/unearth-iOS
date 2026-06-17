//
//  MyTrashBinsView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import Photos
import CoreLocation
import MapKit

// MARK: - 我的垃圾箱页面
struct MyTrashBinsView: View {
    @State private var selectedTab: TrashBinTab = .pending
    @State private var pendingBins: [MyTrashBin] = []
    @State private var approvedBins: [MyTrashBin] = []
    @State private var isLoadingPending = false
    @State private var isLoadingApproved = false
    @State private var hasMorePending = true
    @State private var hasMoreApproved = true
    @State private var editingBin: MyTrashBin? = nil

    enum TrashBinTab: String, CaseIterable {
        case pending = "待审核"
        case approved = "已审核"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab 标签
            HStack(spacing: 0) {
                ForEach(TrashBinTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.subheadline)
                                .fontWeight(selectedTab == tab ? .semibold : .regular)
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)

                            Rectangle()
                                .fill(selectedTab == tab ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(.systemBackground))
            .padding(.top, 8)

            Divider()

            // 内容
            TabView(selection: $selectedTab) {
                TrashBinList(
                    bins: $pendingBins,
                    isLoading: $isLoadingPending,
                    hasMore: $hasMorePending,
                    tab: .pending,
                    onSelect: { _ in }
                )
                .tag(TrashBinTab.pending)

                TrashBinList(
                    bins: $approvedBins,
                    isLoading: $isLoadingApproved,
                    hasMore: $hasMoreApproved,
                    tab: .approved,
                    onSelect: { bin in
                        editingBin = bin
                    }
                )
                .tag(TrashBinTab.approved)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("我的垃圾箱")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData(for: .pending)
            loadData(for: .approved)
        }
        .sheet(item: $editingBin) { bin in
            MyTrashBinDetailView(trashBin: bin, isPresented: Binding(
                get: { editingBin != nil },
                set: { if !$0 { editingBin = nil } }
            ))
        }
    }

    private func loadData(for tab: TrashBinTab) {
        switch tab {
        case .pending:
            guard !isLoadingPending else { return }
            isLoadingPending = true
            MockTrashBinService.shared.fetchMyTrashBins(status: .pending, page: 1) { result in
                DispatchQueue.main.async {
                    isLoadingPending = false
                    pendingBins = result
                    hasMorePending = result.count >= 25
                }
            }
        case .approved:
            guard !isLoadingApproved else { return }
            isLoadingApproved = true
            MockTrashBinService.shared.fetchMyTrashBins(status: .approved, page: 1) { result in
                DispatchQueue.main.async {
                    isLoadingApproved = false
                    approvedBins = result
                    hasMoreApproved = result.count >= 25
                }
            }
        }
    }
}

// MARK: - 垃圾箱列表
struct TrashBinList: View {
    @Binding var bins: [MyTrashBin]
    @Binding var isLoading: Bool
    @Binding var hasMore: Bool
    let tab: MyTrashBinsView.TrashBinTab
    let onSelect: (MyTrashBin) -> Void
    @State private var isRefreshing = false

    var body: some View {
        List {
            if isRefreshing {
                HStack {
                    Spacer()
                    ProgressView().padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            ForEach(bins) { bin in
                MyTrashBinRow(bin: bin, isEditable: tab == .approved)
                    .onTapGesture {
                        if tab == .approved {
                            onSelect(bin)
                        }
                    }
            }

            if isLoading && !isRefreshing {
                HStack {
                    Spacer()
                    ProgressView().padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if !hasMore && !bins.isEmpty {
                HStack {
                    Spacer()
                    Text("没有更多了")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if bins.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(tab == .pending ? "暂无待审核垃圾箱" : "暂无已审核垃圾箱")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            isRefreshing = true
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isRefreshing = false
        }
    }
}

// MARK: - 垃圾箱行视图
struct MyTrashBinRow: View {
    let bin: MyTrashBin
    let isEditable: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bin.statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: bin.typeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(bin.statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(bin.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(bin.address)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(bin.submitTime)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bin.statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(bin.statusColor.opacity(0.2))
                    .foregroundColor(bin.statusColor)
                    .cornerRadius(8)

                if isEditable {
                    HStack(spacing: 4) {
                        Text("编辑")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 我的垃圾箱详情编辑页
struct MyTrashBinDetailView: View {
    let trashBin: MyTrashBin
    @Binding var isPresented: Bool

    @State private var name: String
    @State private var selectedTypes: Set<String>
    @State private var address: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var originalLatitude: Double
    @State private var originalLongitude: Double
    @State private var customIcon: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var isSaving: Bool = false
    @State private var showSaveSuccess: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var nameError: String? = nil

    init(trashBin: MyTrashBin, isPresented: Binding<Bool>) {
        self.trashBin = trashBin
        self._isPresented = isPresented

        // 直接初始化状态变量
        self._name = State(initialValue: trashBin.name)
        self._selectedTypes = State(initialValue: Set([trashBin.type]))
        self._address = State(initialValue: trashBin.address)
        self._latitude = State(initialValue: trashBin.latitude)
        self._longitude = State(initialValue: trashBin.longitude)
        self._originalLatitude = State(initialValue: trashBin.latitude)
        self._originalLongitude = State(initialValue: trashBin.longitude)
    }

    let trashBinTypes = [
        ("recyclable", "可回收", Color.green),
        ("general", "其他", Color.orange),
        ("hazardous", "有害", Color.red)
    ]

    // 名称字节数限制
    private let maxNameBytes = 100

    // 计算名称字节数
    private var nameBytes: Int {
        return name.utf8.count
    }

    // 名称是否有效
    private var isNameValid: Bool {
        return nameBytes <= maxNameBytes && !name.isEmpty
    }

    // 位置是否在50米范围内
    private var isLocationValid: Bool {
        let originalLocation = CLLocation(latitude: originalLatitude, longitude: originalLongitude)
        let newLocation = CLLocation(latitude: latitude, longitude: longitude)
        return originalLocation.distance(from: newLocation) <= 50
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 图标
                    Button(action: {
                        checkPhotoPermission()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 100, height: 100)

                            if let icon = customIcon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: trashBin.typeIcon)
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                            }

                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                            .frame(width: 100, height: 100)
                        }
                    }

                    // 名称输入（最多100字节）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("垃圾箱名称")
                                .font(.headline)
                            Spacer()
                            Text("\(nameBytes)/\(maxNameBytes) 字节")
                                .font(.caption)
                                .foregroundColor(nameBytes > maxNameBytes ? .red : .secondary)
                        }
                        TextField("请输入名称", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: name) { _, newValue in
                                // 限制字节数
                                while newValue.utf8.count > maxNameBytes {
                                    name = String(newValue.dropLast())
                                }
                            }

                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)

                    // 类型多选
                    VStack(alignment: .leading, spacing: 8) {
                        Text("垃圾类别（可多选）")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(trashBinTypes, id: \.0) { type in
                                Button(action: {
                                    if selectedTypes.contains(type.0) {
                                        selectedTypes.remove(type.0)
                                    } else {
                                        selectedTypes.insert(type.0)
                                    }
                                }) {
                                    Text(type.1)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTypes.contains(type.0) ? type.2 : Color(.systemGray5))
                                        .foregroundColor(selectedTypes.contains(type.0) ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 地址输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("地址信息")
                            .font(.headline)
                        TextField("请输入地址", text: $address)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // 经纬度调整（50米范围内）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("位置坐标")
                                .font(.headline)
                            Spacer()
                            Text("可调整范围: 50米内")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("纬度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.6f", latitude))
                                    .font(.subheadline)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("经度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.6f", longitude))
                                    .font(.subheadline)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }

                        if !isLocationValid {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("位置调整超出50米范围")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

                        Button(action: {
                            showLocationPicker = true
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("在地图上选择位置")
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    // 原始信息展示
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "提交时间", value: trashBin.submitTime)
                        InfoRow(label: "状态", value: trashBin.status == .pending ? "待审核" : "已审核")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 保存按钮
                    Button(action: saveChanges) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("保存修改")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isSaving)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("编辑垃圾箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $customIcon, onImagePicked: { _ in })
            }
            .sheet(isPresented: $showLocationPicker) {
                EditLocationPickerView(
                    latitude: $latitude,
                    longitude: $longitude,
                    originalLatitude: originalLatitude,
                    originalLongitude: originalLongitude
                )
            }
            .alert("相册权限未开启", isPresented: $showPermissionAlert) {
                Button("去开启") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("关闭", role: .cancel) {}
            } message: {
                Text("需要获取相册权限才能更换图标")
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("确定") {
                    isPresented = false
                }
            } message: {
                Text("垃圾箱信息已更新")
            }
        }
    }

    private var canSave: Bool {
        return isNameValid && !selectedTypes.isEmpty && isLocationValid
    }

    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showImagePicker = true
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func saveChanges() {
        guard canSave else { return }
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSaving = false
            showSaveSuccess = true
        }
    }
}

// MARK: - 编辑位置选择器（50米范围限制）
struct EditLocationPickerView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    let originalLatitude: Double
    let originalLongitude: Double
    @Environment(\.dismiss) var dismiss

    @State private var region: MKCoordinateRegion

    init(latitude: Binding<Double>, longitude: Binding<Double>, originalLatitude: Double, originalLongitude: Double) {
        self._latitude = latitude
        self._longitude = longitude
        self.originalLatitude = originalLatitude
        self.originalLongitude = originalLongitude

        // 50米范围的 span
        let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: originalLatitude, longitude: originalLongitude),
            span: span
        ))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: region.center)]) { item in
                    MapPin(coordinate: item.coordinate, tint: .red)
                }
                .ignoresSafeArea()

                // 范围指示器
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("拖动地图调整位置")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if !isWithinRange {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("超出50米范围")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }

                            Text(String(format: "纬度: %.6f", region.center.latitude))
                                .font(.caption2)
                            Text(String(format: "经度: %.6f", region.center.longitude))
                                .font(.caption2)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        latitude = region.center.latitude
                        longitude = region.center.longitude
                        dismiss()
                    }
                    .disabled(!isWithinRange)
                }
            }
        }
    }

    private var isWithinRange: Bool {
        let original = CLLocation(latitude: originalLatitude, longitude: originalLongitude)
        let current = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        return original.distance(from: current) <= 50
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - 我的垃圾箱模型
struct MyTrashBin: Identifiable {
    let id: String
    let name: String
    let address: String
    let type: String
    let latitude: Double
    let longitude: Double
    let submitTime: String
    let status: Status

    enum Status {
        case pending
        case approved
        case rejected
    }

    var typeName: String {
        switch type {
        case "recyclable": return "可回收"
        case "general": return "其他"
        case "hazardous": return "有害"
        default: return "垃圾箱"
        }
    }

    var typeIcon: String {
        return "trash.fill"
    }

    var statusText: String {
        switch status {
        case .pending: return "待审核"
        case .approved: return "已通过"
        case .rejected: return "已拒绝"
        }
    }

    var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Mock 服务
class MockTrashBinService {
    static let shared = MockTrashBinService()

    func fetchMyTrashBins(status: MyTrashBin.Status, page: Int, completion: @escaping ([MyTrashBin]) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let startIndex = (page - 1) * 25
            var bins: [MyTrashBin] = []

            for i in startIndex..<(startIndex + 25) {
                // 已审核列表混合已通过和已拒绝
                let itemStatus: MyTrashBin.Status
                if status == .approved {
                    itemStatus = i % 3 == 0 ? .rejected : .approved
                } else {
                    itemStatus = status
                }

                let bin = MyTrashBin(
                    id: "bin_\(i)",
                    name: "垃圾箱 \(i + 1)",
                    address: "南京市\(status == .pending ? "信泰创新中心" : "科技大道")\(i % 10 + 1)号",
                    type: ["recyclable", "general", "hazardous"][i % 3],
                    latitude: 32.024963 + Double.random(in: -0.001...0.001),
                    longitude: 118.912718 + Double.random(in: -0.001...0.001),
                    submitTime: "2026-06-\(String(format: "%02d", (i % 28) + 1)) \(String(format: "%02d", i % 24)):\(String(format: "%02d", i % 60))",
                    status: itemStatus
                )
                bins.append(bin)
            }

            completion(bins)
        }
    }
}

#Preview {
    NavigationView {
        MyTrashBinsView()
    }
}
