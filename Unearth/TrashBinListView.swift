//
//  TrashBinListView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import CoreLocation
import Photos

// MARK: - 距离筛选选项
enum DistanceFilter: String, CaseIterable {
    case m500 = "500m"
    case km1 = "1km"
    case km2 = "2km"
    case km5 = "5km"

    var meters: Double {
        switch self {
        case .m500: return 500
        case .km1: return 1000
        case .km2: return 2000
        case .km5: return 5000
        }
    }
}

// MARK: - 带距离的垃圾箱模型
struct TrashBinWithDistance: Identifiable {
    let id: String
    let trashBin: TrashBinData
    let distance: String
    let distanceValue: Double
    var isMine: Bool = false
}

// MARK: - 垃圾箱列表视图
struct TrashBinListView: View {
    @Binding var isPresented: Bool
    @Binding var selectedTrashBin: TrashBinData?
    @Binding var showTrashBinInfo: Bool
    @Binding var refreshTrigger: Bool
    let initialTrashBins: [TrashBinData]
    let initialUserLocation: CLLocationCoordinate2D?
    @State private var trashBins: [TrashBinData] = []
    @State private var currentUserLocation: CLLocationCoordinate2D? = nil
    @State private var expandedBinId: String? = nil
    @State private var selectedFilter: DistanceFilter = .km2
    @State private var binsWithDistance: [TrashBinWithDistance] = []
    @State private var showPermissionAlert: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var editingBinId: String? = nil
    @State private var showLoginRequired: Bool = false
    @State private var editingTrashBin: TrashBinData? = nil
    @ObservedObject var loginManager = LoginManager.shared

    var body: some View {
        ZStack(alignment: .leading) {
            // 左侧透明区域 - 点击关闭列表
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }

            // 右侧列表
            HStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // 顶部标题
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("附近垃圾箱")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("\(selectedFilter.rawValue)范围内 \(binsWithDistance.count) 个")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))

                    // 距离筛选
                    HStack(spacing: 8) {
                        ForEach(DistanceFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                    expandedBinId = nil
                                    calculateDistances()
                                }
                            }) {
                                Text(filter.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedFilter == filter ? .semibold : .regular)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))

                    Divider()

                    // 列表
                    if binsWithDistance.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("附近暂无垃圾箱")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(binsWithDistance) { bin in
                                    VStack(spacing: 0) {
                                        // 列表行
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if expandedBinId == bin.id {
                                                    expandedBinId = nil
                                                } else {
                                                    expandedBinId = bin.id
                                                }
                                            }
                                        }) {
                                            TrashBinRow(
                                                trashBin: bin.trashBin,
                                                distance: bin.distance,
                                                isExpanded: expandedBinId == bin.id,
                                                customIcon: loadCustomIcon(for: bin.trashBin.id),
                                                isMine: bin.isMine
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                        // 展开的详情
                                        if expandedBinId == bin.id {
                                            TrashBinExpandedDetail(
                                                trashBin: bin.trashBin,
                                                distance: bin.distance,
                                                customIcon: loadCustomIcon(for: bin.trashBin.id),
                                                isMine: bin.isMine,
                                                onNavigate: {
                                                    startNavigation(trashBin: bin.trashBin)
                                                },
                                                onEdit: bin.isMine ? {
                                                    editingTrashBin = bin.trashBin
                                                } : nil
                                            )
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }

                                        if bin.id != binsWithDistance.last?.id {
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color(.systemGray6))
                    }
                }
                .frame(width: 320)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10, x: -5, y: 0)
            }
        }
        .onAppear {
            // 从 API 获取数据
            TrashBinDataManager.shared.fetchTrashBins { [self] bins in
                DispatchQueue.main.async {
                    self.trashBins = bins
                    self.fetchCurrentUserLocation()
                }
            }
        }
        .onChange(of: selectedFilter) { _, _ in
            calculateDistances()
        }
        // 相册选择器
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: .constant(nil), onImagePicked: { image in
                if let binId = editingBinId {
                    compressAndSave(image: image, binId: binId)
                }
            })
        }
        // 权限提示弹窗
        .alert("相册权限未开启", isPresented: $showPermissionAlert) {
            Button("去开启") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("关闭", role: .cancel) {}
        } message: {
            Text("需要获取相册权限才能选择图片，请在设置中开启相册权限")
        }
        // 登录页面
        .sheet(isPresented: $showLoginRequired) {
            LoginView()
        }
        // 编辑页面
        .sheet(item: $editingTrashBin) { bin in
            MyTrashBinDetailView(trashBin: MyTrashBin(
                id: bin.id,
                name: bin.name,
                address: bin.address ?? "",
                type: bin.type,
                latitude: bin.latitude,
                longitude: bin.longitude,
                submitTime: bin.discoveredAt ?? "",
                status: .approved
            ), isPresented: Binding(
                get: { editingTrashBin != nil },
                set: { if !$0 { editingTrashBin = nil } }
            ))
        }
    }

    // 获取当前用户位置
    private func fetchCurrentUserLocation() {
        // 使用传入的位置（来自地图的实时定位）
        if let location = initialUserLocation {
            self.currentUserLocation = location
            print("📍 使用地图位置: \(location.latitude), \(location.longitude)")
        } else {
            // 备用：使用 AMapLocationService 缓存
            self.currentUserLocation = AMapLocationService.shared.currentLocation
            print("📍 使用缓存位置: \(self.currentUserLocation?.latitude ?? 0), \(self.currentUserLocation?.longitude ?? 0)")
        }
        // 计算距离
        self.calculateDistances()
    }

    // 计算距离并排序（用户发现的排在前面）
    private func calculateDistances() {
        guard let userLocation = currentUserLocation else {
            print("⚠️ 用户位置为空，无法计算距离")
            binsWithDistance = []
            return
        }

        print("📊 开始计算距离")
        print("📊 用户位置: \(userLocation.latitude), \(userLocation.longitude)")
        print("📊 垃圾箱总数: \(trashBins.count)")
        print("📊 筛选范围: \(selectedFilter.meters)m")

        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let currentUserName = loginManager.userName

        let allBins = trashBins
            .compactMap { bin -> (bin: TrashBinWithDistance, isMine: Bool)? in
                let binLoc = CLLocation(latitude: bin.latitude, longitude: bin.longitude)
                let distanceValue = userLoc.distance(from: binLoc)

                guard distanceValue <= selectedFilter.meters else { return nil }

                let distanceString: String
                if distanceValue >= 1000 {
                    distanceString = String(format: "%.1fkm", distanceValue / 1000)
                } else {
                    distanceString = "\(Int(distanceValue))m"
                }

                // 判断是否是用户自己发现的
                let isMine = bin.discoverer == currentUserName && !currentUserName.isEmpty

                let binWithDistance = TrashBinWithDistance(
                    id: bin.id,
                    trashBin: bin,
                    distance: distanceString,
                    distanceValue: distanceValue,
                    isMine: isMine
                )

                return (bin: binWithDistance, isMine: isMine)
            }

        // 用户发现的排前面，然后按距离排序
        let myBins = allBins.filter { $0.isMine }.sorted { $0.bin.distanceValue < $1.bin.distanceValue }
        let otherBins = allBins.filter { !$0.isMine }.sorted { $0.bin.distanceValue < $1.bin.distanceValue }

        binsWithDistance = myBins.map { $0.bin } + otherBins.map { $0.bin }

        print("📊 计算完成")
        print("📊 筛选后数量: \(binsWithDistance.count)")
        if let first = binsWithDistance.first {
            print("📊 最近垃圾箱: \(first.trashBin.name) - \(first.distance)")
        }
    }

    // 加载自定义图标
    private func loadCustomIcon(for binId: String) -> UIImage? {
        guard let path = TrashBinDataManager.shared.getCustomIconPath(trashBinId: binId) else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }

    // 直接打开导航
    private func startNavigation(trashBin: TrashBinData) {
        let lat = trashBin.latitude
        let lon = trashBin.longitude
        let name = trashBin.name

        // 使用高德地图导航（步行模式）
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "垃圾箱"
        let urlString = "iosamap://path?sourceApplication=Unearth&dlat=\(lat)&dlon=\(lon)&dname=\(encodedName)&dev=0&t=2"

        print("🗺️ 导航 URL: \(urlString)")
        print("🗺️ 目的地名称: \(name)")

        // 直接尝试打开高德地图
        if let url = URL(string: urlString) {
            print("🗺️ 尝试打开高德地图导航")
            UIApplication.shared.open(url) { success in
                if !success {
                    print("🗺️ 高德地图打开失败，使用 Apple 地图")
                    // 使用 Apple 地图
                    let appleMapString = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=w"
                    if let appleMapURL = URL(string: appleMapString) {
                        UIApplication.shared.open(appleMapURL)
                    }
                }
            }
        }
    }

    // 检查相册权限
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

    // 压缩并保存图片
    private func compressAndSave(image: UIImage, binId: String) {
        // 获取当前登录用户名
        let currentUserName = LoginManager.shared.userName.isEmpty ? "匿名用户" : LoginManager.shared.userName

        DispatchQueue.global(qos: .userInitiated).async {
            if let compressedData = compressImage(image, maxSizeKB: 100) {
                DispatchQueue.main.async {
                    TrashBinDataManager.shared.saveCustomIcon(
                        trashBinId: binId,
                        imageData: compressedData,
                        updaterName: currentUserName,
                        updateContent: "更换垃圾箱图标"
                    )
                    // 从 API 重新加载数据
                    TrashBinDataManager.shared.fetchTrashBins { [self] bins in
                        DispatchQueue.main.async {
                            self.trashBins = bins
                            self.calculateDistances()
                            self.refreshTrigger.toggle()
                            print("✅ 列表上传图标，触发地图刷新")
                        }
                    }
                }
            }
        }
    }

    // 压缩图片
    private func compressImage(_ image: UIImage, maxSizeKB: Int) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 1.0
        guard var data = image.jpegData(compressionQuality: compression) else { return nil }

        if data.count <= maxBytes { return data }

        var min: CGFloat = 0.0
        var max: CGFloat = 1.0

        for _ in 0..<6 {
            compression = (min + max) / 2
            data = image.jpegData(compressionQuality: compression) ?? data
            if data.count <= maxBytes {
                min = compression
            } else {
                max = compression
            }
        }

        if data.count > maxBytes {
            var currentImage = image
            while data.count > maxBytes {
                let newSize = CGSize(
                    width: currentImage.size.width * 0.9,
                    height: currentImage.size.height * 0.9
                )
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                currentImage.draw(in: CGRect(origin: .zero, size: newSize))
                currentImage = UIGraphicsGetImageFromCurrentImageContext() ?? currentImage
                UIGraphicsEndImageContext()
                data = currentImage.jpegData(compressionQuality: compression) ?? data
            }
        }

        return data.count <= maxBytes ? data : nil
    }
}

// MARK: - 垃圾箱行视图
struct TrashBinRow: View {
    let trashBin: TrashBinData
    let distance: String
    let isExpanded: Bool
    let customIcon: UIImage?
    var isMine: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: isMine ? 52 : 44, height: isMine ? 52 : 44)

                if let icon = customIcon {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isMine ? 36 : 30, height: isMine ? 36 : 30)
                        .clipShape(Circle())
                } else {
                    Image(systemName: trashBin.defaultIconName)
                        .font(.system(size: isMine ? 24 : 20))
                        .foregroundColor(iconColor)
                }

                // 用户发现的标记
                if isMine {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                                .background(Circle().fill(.white).frame(width: 14, height: 14))
                        }
                        Spacer()
                    }
                    .frame(width: isMine ? 52 : 44, height: isMine ? 52 : 44)
                }
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(trashBin.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if isMine {
                        Text("我发现的")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let address = trashBin.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 距离（直线距离）
            VStack(alignment: .trailing, spacing: 4) {
                Text(distance)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var iconColor: Color {
        switch trashBin.type {
        case "recyclable": return .green
        case "general": return .orange
        case "hazardous": return .red
        default: return .gray
        }
    }
}

// MARK: - 展开的详情视图
struct TrashBinExpandedDetail: View {
    let trashBin: TrashBinData
    let distance: String
    let customIcon: UIImage?
    var isMine: Bool = false
    let onNavigate: () -> Void
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            // 详细信息
            VStack(alignment: .leading, spacing: 8) {
                // 类型和状态
                HStack {
                    Label(trashBin.typeName, systemImage: trashBin.defaultIconName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor(trashBin.type).opacity(0.2))
                        .foregroundColor(typeColor(trashBin.type))
                        .cornerRadius(8)

                    if let status = trashBin.status {
                        Label(statusText(status), systemImage: statusIcon(status))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(status).opacity(0.2))
                            .foregroundColor(statusColor(status))
                            .cornerRadius(8)
                    }

                    Spacer()

                    Text("直线距离 \(distance)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 地址
                if let address = trashBin.address {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .frame(width: 16)
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                // 发现和更新信息
                VStack(alignment: .leading, spacing: 4) {
                    if let discoveredAt = trashBin.discoveredAt,
                       let discoverer = trashBin.discoverer {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(width: 16)
                            Text("\(discoveredAt) \(discoverer)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    if let updatedAt = trashBin.updatedAt,
                       let updater = trashBin.updater {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(width: 16)
                            Text("\(updatedAt) \(updater)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    if let updateContent = trashBin.updateContent {
                        HStack(spacing: 8) {
                            Image(systemName: "text.alignleft")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .frame(width: 16)
                            Text(updateContent)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal)

            // 按钮区域
            HStack(spacing: 12) {
                // 编辑按钮（仅用户自己发现的垃圾箱）
                if isMine, let onEdit = onEdit {
                    Button(action: onEdit) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("编辑")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }

                // 导航按钮
                Button(action: onNavigate) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("导航到此处")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "recyclable": return .green
        case "general": return .orange
        case "hazardous": return .red
        default: return .gray
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "full": return .red
        case "maintenance": return .orange
        default: return .green
        }
    }

    private func statusText(_ status: String) -> String {
        switch status {
        case "full": return "已满"
        case "maintenance": return "维护中"
        default: return "正常"
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status {
        case "full": return "exclamationmark.circle.fill"
        case "maintenance": return "wrench.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

#Preview {
    TrashBinListView(
        isPresented: .constant(true),
        selectedTrashBin: .constant(nil),
        showTrashBinInfo: .constant(false),
        refreshTrigger: .constant(false),
        initialTrashBins: defaultTrashBins,
        initialUserLocation: CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969)
    )
}
