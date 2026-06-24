//
//  FavoriteListView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import CoreLocation

// MARK: - 我的收藏页面
struct FavoriteListView: View {
    @State private var favoriteBins: [TrashBinData] = []
    @State private var isLoading = false
    @State private var expandedBinId: String? = nil
    @ObservedObject var loginManager = LoginManager.shared

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if favoriteBins.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无收藏的垃圾箱")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("在地图上点击垃圾箱后可收藏")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
                .listRowSeparator(.hidden)
            }

            ForEach(favoriteBins) { bin in
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
                        FavoriteRow(bin: bin, isExpanded: expandedBinId == bin.id)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 展开的详情
                    if expandedBinId == bin.id {
                        FavoriteExpandedDetail(
                            trashBin: bin,
                            onNavigate: {
                                startNavigation(trashBin: bin)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("我的收藏")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadFavorites()
        }
    }

    private func loadFavorites() {
        isLoading = true

        let favoritedIds = TrashBinDataManager.shared.getFavoritedIds()

        TrashBinDataManager.shared.fetchTrashBins { [self] bins in
            DispatchQueue.main.async {
                self.favoriteBins = bins.filter { favoritedIds.contains($0.id) }
                self.isLoading = false
            }
        }
    }

    private func startNavigation(trashBin: TrashBinData) {
        let lat = trashBin.latitude
        let lon = trashBin.longitude
        let name = trashBin.name

        if let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            let urlString = "iosamap://path?sourceApplication=Unearth&dlat=\(lat)&dlon=\(lon)&dname=\(encodedName)&dev=0&t=2"
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }

        let appleMapString = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=w"
        if let appleMapURL = URL(string: appleMapString) {
            UIApplication.shared.open(appleMapURL)
        }
    }
}

// MARK: - 收藏行视图
struct FavoriteRow: View {
    let bin: TrashBinData
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(bin.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let address = bin.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Label(bin.typeName, systemImage: bin.defaultIconName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let likeCount = bin.likeCount {
                        Label("\(likeCount)", systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    if let favoriteCount = bin.favoriteCount {
                        Label("\(favoriteCount)", systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 收藏展开详情
struct FavoriteExpandedDetail: View {
    let trashBin: TrashBinData
    let onNavigate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

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
                        Text(status == "full" ? "已满" : status == "maintenance" ? "维护中" : "正常")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(trashBin.status).opacity(0.2))
                            .foregroundColor(statusColor(trashBin.status))
                            .cornerRadius(8)
                    }

                    Spacer()
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

                // 发现信息
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
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
            .padding(.horizontal)

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

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "full": return .red
        case "maintenance": return .orange
        default: return .green
        }
    }
}

#Preview {
    NavigationView {
        FavoriteListView()
    }
}
