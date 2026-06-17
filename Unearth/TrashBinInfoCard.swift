//
//  TrashBinInfoCard.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI

// MARK: - 垃圾箱信息卡片
struct TrashBinInfoCard: View {
    let trashBin: TrashBinData
    @Binding var isPresented: Bool
    @State private var customIcon: UIImage? = nil
    @State private var isLiked: Bool = false
    @State private var isFavorited: Bool = false
    @State private var likeCount: Int = 0
    @State private var favoriteCount: Int = 0
    @State private var showLoginRequired: Bool = false
    @State private var showEditPage: Bool = false
    @ObservedObject var loginManager = LoginManager.shared

    // 是否是用户自己发现的
    private var isMine: Bool {
        return trashBin.discoverer == loginManager.userName && !loginManager.userName.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // 顶部间距
            Spacer()
                .frame(height: 8)

            // 主内容
            HStack(spacing: 16) {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 80, height: 80)

                    if let image = customIcon {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: trashBin.defaultIconName)
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }
                }

                // 右侧信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(trashBin.name)
                        .font(.title3)
                        .fontWeight(.bold)

                    if let address = trashBin.address {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Text(trashBin.typeName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(typeColor.opacity(0.2))
                            .foregroundColor(typeColor)
                            .cornerRadius(8)

                        if let status = trashBin.status {
                            Text(status == "full" ? "已满" : status == "maintenance" ? "维护中" : "正常")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor.opacity(0.2))
                                .foregroundColor(statusColor)
                                .cornerRadius(8)
                        }
                    }

                    // 点赞和收藏
                    HStack(spacing: 16) {
                        // 点赞按钮
                        Button(action: {
                            toggleLike()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .red : .gray)
                                Text("\(likeCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 收藏按钮
                        Button(action: {
                            toggleFavorite()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isFavorited ? "star.fill" : "star")
                                    .foregroundColor(isFavorited ? .yellow : .gray)
                                Text("\(favoriteCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)

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
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                // 按钮区域
                VStack(spacing: 8) {
                    // 编辑按钮（仅用户自己发现的垃圾箱）
                    if isMine {
                        Button(action: {
                            showEditPage = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 24))
                                Text("编辑")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }

                    // 导航按钮
                    Button(action: {
                        startNavigation()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 24))
                            Text("导航")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .frame(width: 60)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .onAppear {
            loadCustomIcon()
            loadLikeFavoriteStatus()
        }
        .sheet(isPresented: $showEditPage) {
            MyTrashBinDetailView(trashBin: MyTrashBin(
                id: trashBin.id,
                name: trashBin.name,
                address: trashBin.address ?? "",
                type: trashBin.type,
                latitude: trashBin.latitude,
                longitude: trashBin.longitude,
                submitTime: trashBin.discoveredAt ?? "",
                status: .approved
            ), isPresented: $showEditPage)
        }
        .sheet(isPresented: $showLoginRequired) {
            LoginView()
        }
    }

    // 加载自定义图标
    private func loadCustomIcon() {
        if let path = TrashBinDataManager.shared.getCustomIconPath(trashBinId: trashBin.id),
           let image = UIImage(contentsOfFile: path) {
            customIcon = image
        }
    }

    // 加载点赞收藏状态
    private func loadLikeFavoriteStatus() {
        isLiked = TrashBinDataManager.shared.isLiked(trashBinId: trashBin.id)
        isFavorited = TrashBinDataManager.shared.isFavorited(trashBinId: trashBin.id)
        likeCount = trashBin.likeCount ?? 0
        favoriteCount = trashBin.favoriteCount ?? 0

        // 如果已点赞/收藏，加上本地状态
        if isLiked { likeCount += 1 }
        if isFavorited { favoriteCount += 1 }
    }

    // 切换点赞
    private func toggleLike() {
        guard loginManager.isLoggedIn else {
            showLoginRequired = true
            return
        }

        let newStatus = TrashBinDataManager.shared.toggleLike(trashBinId: trashBin.id)
        isLiked = newStatus
        likeCount += newStatus ? 1 : -1
    }

    // 切换收藏
    private func toggleFavorite() {
        guard loginManager.isLoggedIn else {
            showLoginRequired = true
            return
        }

        let newStatus = TrashBinDataManager.shared.toggleFavorite(trashBinId: trashBin.id)
        isFavorited = newStatus
        favoriteCount += newStatus ? 1 : -1
    }

    // 直接打开导航
    private func startNavigation() {
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

    // 图标背景颜色
    private var iconBackgroundColor: Color {
        if customIcon != nil { return .clear }
        switch trashBin.type {
        case "recyclable": return .green
        case "general": return .orange
        case "hazardous": return .red
        default: return .gray
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

    private var statusColor: Color {
        switch trashBin.status {
        case "full": return .red
        case "maintenance": return .orange
        default: return .green
        }
    }
}

#Preview {
    TrashBinInfoCard(
        trashBin: defaultTrashBins[0],
        isPresented: .constant(true)
    )
}
