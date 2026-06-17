//
//  TrashBinData.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import Foundation
import CoreLocation

// MARK: - 垃圾箱数据模型

struct TrashBinData: Codable, Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let type: String
    let iconURL: String?
    let address: String?
    let capacity: Int?
    let status: String?
    let discoveredAt: String?
    let discoverer: String?
    let updatedAt: String?
    let updater: String?
    let updateContent: String?
    let likeCount: Int?
    let favoriteCount: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var typeName: String {
        switch type {
        case "recyclable": return "可回收"
        case "general": return "其他"
        case "hazardous": return "有害"
        default: return "垃圾箱"
        }
    }

    var defaultIconName: String {
        return "trash.fill"
    }

    var statusColor: String {
        switch status {
        case "full": return "red"
        case "maintenance": return "orange"
        default: return "green"
        }
    }
}

struct TrashBinResponse: Codable {
    let code: Int
    let message: String
    let data: [TrashBinData]
}

// MARK: - 垃圾箱数据管理
class TrashBinDataManager {
    static let shared = TrashBinDataManager()

    private init() {}

    // MARK: - 从本地加载

    func loadTrashBins() -> [TrashBinData] {
        var trashBins: [TrashBinData] = []

        if let url = Bundle.main.url(forResource: "trashbins", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let response = try? JSONDecoder().decode(TrashBinResponse.self, from: data) {
            trashBins = response.data
        } else {
            trashBins = defaultTrashBins
        }

        return trashBins.map { getTrashBinWithMetadata(trashBin: $0) }
    }

    // MARK: - 从后端 API 加载

    /// 从后端获取附近垃圾箱
    func fetchNearbyTrashBins(
        latitude: Double,
        longitude: Double,
        radius: Double = 2000,
        completion: @escaping ([TrashBinData]) -> Void
    ) {
        APIService.shared.getNearbyTrashBins(latitude: latitude, longitude: longitude, radius: radius) { result in
            switch result {
            case .success(let response):
                if let bins = response.data {
                    let trashBins = bins.map { self.convertFromAPI($0) }
                    completion(trashBins)
                } else {
                    completion([])
                }
            case .failure(let error):
                print("获取附近垃圾箱失败: \(error)")
                // 降级使用本地数据
                completion(self.loadTrashBins())
            }
        }
    }

    /// 从后端获取用户发现的垃圾箱
    func fetchMyTrashBins(completion: @escaping ([TrashBinData]) -> Void) {
        APIService.shared.getMyTrashBins { result in
            switch result {
            case .success(let response):
                if let bins = response.data {
                    let trashBins = bins.map { self.convertFromAPI($0) }
                    completion(trashBins)
                } else {
                    completion([])
                }
            case .failure(let error):
                print("获取我的垃圾箱失败: \(error)")
                completion([])
            }
        }
    }

    /// 从后端 API 转换为本地模型
    private func convertFromAPI(_ vo: TrashBinVO) -> TrashBinData {
        return TrashBinData(
            id: "\(vo.id)",
            name: vo.name,
            latitude: vo.latitude,
            longitude: vo.longitude,
            type: vo.type,
            iconURL: vo.iconUrl,
            address: vo.address,
            capacity: nil,
            status: vo.status,
            discoveredAt: vo.discoveredAt,
            discoverer: vo.discoverer,
            updatedAt: vo.updatedAt,
            updater: vo.updater,
            updateContent: vo.updateContent,
            likeCount: vo.likeCount ?? 0,
            favoriteCount: vo.favoriteCount ?? 0
        )
    }

    func saveCustomIcon(trashBinId: String, imageData: Data, updaterName: String, updateContent: String) {
        let fileName = "trashbin_icon_\(trashBinId)"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        try? imageData.write(to: url)

        var savedIcons = UserDefaults.standard.dictionary(forKey: "savedIcons") as? [String: String] ?? [:]
        savedIcons[trashBinId] = url.path
        UserDefaults.standard.set(savedIcons, forKey: "savedIcons")

        updateTrashBinMetadata(trashBinId: trashBinId, updaterName: updaterName, updateContent: updateContent)
    }

    func updateTrashBinMetadata(trashBinId: String, updaterName: String, updateContent: String) {
        var savedMetadata = UserDefaults.standard.dictionary(forKey: "savedMetadata") as? [String: [String: String]] ?? [:]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        let currentTime = dateFormatter.string(from: Date())

        var metadata = savedMetadata[trashBinId] ?? [:]
        metadata["updatedAt"] = currentTime
        metadata["updater"] = updaterName
        metadata["updateContent"] = updateContent

        savedMetadata[trashBinId] = metadata
        UserDefaults.standard.set(savedMetadata, forKey: "savedMetadata")
    }

    func getTrashBinWithMetadata(trashBin: TrashBinData) -> TrashBinData {
        let savedMetadata = UserDefaults.standard.dictionary(forKey: "savedMetadata") as? [String: [String: String]] ?? [:]

        guard let metadata = savedMetadata[trashBin.id] else {
            return trashBin
        }

        return TrashBinData(
            id: trashBin.id,
            name: trashBin.name,
            latitude: trashBin.latitude,
            longitude: trashBin.longitude,
            type: trashBin.type,
            iconURL: trashBin.iconURL,
            address: trashBin.address,
            capacity: trashBin.capacity,
            status: trashBin.status,
            discoveredAt: metadata["discoveredAt"] ?? trashBin.discoveredAt,
            discoverer: metadata["discoverer"] ?? trashBin.discoverer,
            updatedAt: metadata["updatedAt"] ?? trashBin.updatedAt,
            updater: metadata["updater"] ?? trashBin.updater,
            updateContent: metadata["updateContent"] ?? trashBin.updateContent,
            likeCount: trashBin.likeCount ?? 0,
            favoriteCount: trashBin.favoriteCount ?? 0
        )
    }

    func getCustomIconPath(trashBinId: String) -> String? {
        let savedIcons = UserDefaults.standard.dictionary(forKey: "savedIcons") as? [String: String]
        return savedIcons?[trashBinId]
    }

    // MARK: - 点赞功能

    func isLiked(trashBinId: String) -> Bool {
        let likedIds = UserDefaults.standard.stringArray(forKey: "likedTrashBins") ?? []
        return likedIds.contains(trashBinId)
    }

    func toggleLike(trashBinId: String) -> Bool {
        var likedIds = UserDefaults.standard.stringArray(forKey: "likedTrashBins") ?? []

        if likedIds.contains(trashBinId) {
            likedIds.removeAll { $0 == trashBinId }
            UserDefaults.standard.set(likedIds, forKey: "likedTrashBins")
            return false
        } else {
            likedIds.append(trashBinId)
            UserDefaults.standard.set(likedIds, forKey: "likedTrashBins")
            return true
        }
    }

    // MARK: - 收藏功能

    func isFavorited(trashBinId: String) -> Bool {
        let favoritedIds = UserDefaults.standard.stringArray(forKey: "favoritedTrashBins") ?? []
        return favoritedIds.contains(trashBinId)
    }

    func toggleFavorite(trashBinId: String) -> Bool {
        var favoritedIds = UserDefaults.standard.stringArray(forKey: "favoritedTrashBins") ?? []

        if favoritedIds.contains(trashBinId) {
            favoritedIds.removeAll { $0 == trashBinId }
            UserDefaults.standard.set(favoritedIds, forKey: "favoritedTrashBins")
            return false
        } else {
            favoritedIds.append(trashBinId)
            UserDefaults.standard.set(favoritedIds, forKey: "favoritedTrashBins")
            return true
        }
    }

    func getFavoritedIds() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "favoritedTrashBins") ?? []
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - 默认数据
let defaultTrashBins: [TrashBinData] = [
    TrashBinData(id: "bin_001", name: "可回收垃圾箱", latitude: 32.0608, longitude: 118.7975, type: "recyclable", iconURL: nil, address: "信泰创新中心东门", capacity: 35, status: "normal", discoveredAt: "2026-06-01 10:30", discoverer: "张三", updatedAt: "2026-06-01 10:30", updater: "张三", updateContent: "初次发现并记录", likeCount: 12, favoriteCount: 5),
    TrashBinData(id: "bin_002", name: "不可回收垃圾箱", latitude: 32.0598, longitude: 118.7965, type: "general", iconURL: nil, address: "信泰创新中心南侧", capacity: 72, status: "normal", discoveredAt: "2026-06-02 14:20", discoverer: "李四", updatedAt: "2026-06-05 09:15", updater: "王五", updateContent: "更新垃圾箱状态", likeCount: 8, favoriteCount: 3),
    TrashBinData(id: "bin_003", name: "有害垃圾箱", latitude: 32.0612, longitude: 118.7958, type: "hazardous", iconURL: nil, address: "信泰创新中心西门", capacity: 15, status: "normal", discoveredAt: "2026-06-03 16:45", discoverer: "王五", updatedAt: "2026-06-03 16:45", updater: "王五", updateContent: "初次发现并记录", likeCount: 25, favoriteCount: 10),
    TrashBinData(id: "bin_004", name: "厨余垃圾箱", latitude: 32.0595, longitude: 118.7980, type: "general", iconURL: nil, address: "信泰创新中心北门", capacity: 58, status: "normal", discoveredAt: "2026-06-04 08:10", discoverer: "赵六", updatedAt: "2026-06-04 08:10", updater: "赵六", updateContent: "初次发现并记录", likeCount: 6, favoriteCount: 2),
    TrashBinData(id: "bin_005", name: "可回收垃圾箱", latitude: 32.0618, longitude: 118.7970, type: "recyclable", iconURL: nil, address: "创新路与科技大道交叉口", capacity: 42, status: "normal", discoveredAt: "2026-06-05 11:25", discoverer: "钱七", updatedAt: "2026-06-08 15:30", updater: "张三", updateContent: "更换垃圾箱图标", likeCount: 18, favoriteCount: 7),
    TrashBinData(id: "bin_006", name: "其他垃圾箱", latitude: 32.0588, longitude: 118.7955, type: "general", iconURL: nil, address: "科技大道公交站", capacity: 85, status: "full", discoveredAt: "2026-06-06 13:50", discoverer: "孙八", updatedAt: "2026-06-09 10:20", updater: "李四", updateContent: "标记垃圾箱已满", likeCount: 32, favoriteCount: 15),
    TrashBinData(id: "bin_007", name: "有害垃圾箱", latitude: 32.0622, longitude: 118.7985, type: "hazardous", iconURL: nil, address: "创新路停车场入口", capacity: 8, status: "normal", discoveredAt: "2026-06-07 17:35", discoverer: "周九", updatedAt: "2026-06-07 17:35", updater: "周九", updateContent: "初次发现并记录", likeCount: 4, favoriteCount: 1),
    TrashBinData(id: "bin_008", name: "可回收垃圾箱", latitude: 32.0582, longitude: 118.7962, type: "recyclable", iconURL: nil, address: "南京软件谷入口", capacity: 60, status: "maintenance", discoveredAt: "2026-06-08 09:00", discoverer: "吴十", updatedAt: "2026-06-09 14:45", updater: "王五", updateContent: "记录垃圾箱维护信息", likeCount: 15, favoriteCount: 6)
]
