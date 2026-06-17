//
//  RouteConfirmView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import CoreLocation

// MARK: - 路线确认页面
struct RouteConfirmView: View {
    let trashBin: TrashBinData
    @Binding var isPresented: Bool
    @State private var startLocation: String = "当前位置"
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var showStartPicker: Bool = false
    @State private var isCalculating: Bool = false
    @State private var routeCalculated: Bool = false
    @State private var routeDistance: String = ""
    @State private var routeTime: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 路线信息卡片
                VStack(spacing: 16) {
                    // 起点 - 点击文字可更改
                    Button(action: {
                        showStartPicker = true
                    }) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("起点")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(startLocation)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 连接线
                    HStack {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 2, height: 20)
                        }
                        .padding(.leading, 22)
                        Spacer()
                    }

                    // 终点
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("终点")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(trashBin.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            if let address = trashBin.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(trashBin.typeName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.2))
                            .foregroundColor(typeColor)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()

                // 路线结果
                if routeCalculated {
                    VStack(spacing: 16) {
                        Divider()

                        HStack(spacing: 30) {
                            VStack {
                                Text(routeDistance)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("距离")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text(routeTime)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("预计时间")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Image(systemName: "figure.walk")
                                    .font(.title2)
                                Text("步行")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // 底部按钮
                VStack(spacing: 12) {
                    if !routeCalculated {
                        Button(action: calculateRoute) {
                            HStack {
                                if isCalculating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text("计算路线")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isCalculating)
                    } else {
                        Button(action: startNavigation) {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                Text("开始导航")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("路线规划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showStartPicker) {
                StartLocationPicker(
                    selectedName: $startLocation,
                    selectedCoordinate: $startCoordinate
                )
            }
            .onAppear {
                if let userLocation = AMapLocationService.shared.currentLocation {
                    startCoordinate = userLocation
                }
            }
        }
    }

    private var typeColor: Color {
        switch trashBin.type {
        case "recyclable": return .green
        case "general": return .orange
        case "hazardous": return .red
        default: return .gray
        }
    }

    private func calculateRoute() {
        isCalculating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isCalculating = false
            routeCalculated = true
            routeDistance = "350米"
            routeTime = "5分钟"
        }
    }

    private func startNavigation() {
        let lat = trashBin.latitude
        let lon = trashBin.longitude
        let name = trashBin.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "垃圾箱"

        let urlString = "iosamap://path?sourceApplication=Unearth&dlat=\(lat)&dlon=\(lon)&dname=\(name)&dev=0&t=0"

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            let appleMapURL = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=w"
            if let url = URL(string: appleMapURL) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - 起点选择器
struct StartLocationPicker: View {
    @Binding var selectedName: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss

    let presetLocations = [
        PresetLocation(name: "当前位置", coordinate: nil),
        PresetLocation(name: "信泰创新中心", coordinate: CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969)),
        PresetLocation(name: "新街口", coordinate: CLLocationCoordinate2D(latitude: 32.0406, longitude: 118.7846)),
        PresetLocation(name: "夫子庙", coordinate: CLLocationCoordinate2D(latitude: 32.0226, longitude: 118.7916)),
        PresetLocation(name: "南京站", coordinate: CLLocationCoordinate2D(latitude: 32.0896, longitude: 118.7968)),
        PresetLocation(name: "南京南站", coordinate: CLLocationCoordinate2D(latitude: 31.9724, longitude: 118.8025))
    ]

    var body: some View {
        NavigationView {
            List {
                Section("选择起点") {
                    ForEach(presetLocations) { location in
                        Button(action: {
                            selectedName = location.name
                            selectedCoordinate = location.coordinate
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: location.name == "当前位置" ? "location.fill" : "mappin.circle.fill")
                                    .foregroundColor(location.name == "当前位置" ? .blue : .red)

                                Text(location.name)
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedName == location.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择起点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PresetLocation: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D?
}

#Preview {
    RouteConfirmView(
        trashBin: defaultTrashBins[0],
        isPresented: .constant(true)
    )
}
