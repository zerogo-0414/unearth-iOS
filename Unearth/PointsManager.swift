//
//  PointsManager.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import Foundation
import Combine

// MARK: - 积分类型
enum PointsType: String, Codable, CaseIterable {
    case signIn = "signIn"                    // 签到
    case like = "like"                        // 点赞
    case favorite = "favorite"                // 收藏
    case discover = "discover"                // 发现
    case beLiked = "beLiked"                  // 被点赞
    case beFavorited = "beFavorited"          // 被收藏
    case unlike = "unlike"                    // 取消点赞
    case unfavorite = "unfavorite"            // 取消收藏
    case beUnliked = "beUnliked"              // 被取消点赞
    case beUnfavorited = "beUnfavorited"      // 被取消收藏
    case consecutiveSignIn = "consecutiveSignIn" // 连续签到7倍数

    var displayName: String {
        switch self {
        case .signIn: return "签到"
        case .like: return "点赞"
        case .favorite: return "收藏"
        case .discover: return "发现"
        case .beLiked: return "被点赞"
        case .beFavorited: return "被收藏"
        case .unlike: return "取消点赞"
        case .unfavorite: return "取消收藏"
        case .beUnliked: return "被取消点赞"
        case .beUnfavorited: return "被取消收藏"
        case .consecutiveSignIn: return "连续签到奖励"
        }
    }

    var iconName: String {
        switch self {
        case .signIn: return "checkmark.circle.fill"
        case .like: return "heart.fill"
        case .favorite: return "star.fill"
        case .discover: return "magnifyingglass.circle.fill"
        case .beLiked: return "heart.circle.fill"
        case .beFavorited: return "star.circle.fill"
        case .unlike: return "heart.slash"
        case .unfavorite: return "star.slash"
        case .beUnliked: return "heart.slash.circle"
        case .beUnfavorited: return "star.slash.circle"
        case .consecutiveSignIn: return "flame.fill"
        }
    }

    var points: Int {
        switch self {
        case .signIn: return 10
        case .like: return 2
        case .favorite: return 5
        case .discover: return 20
        case .beLiked: return 3
        case .beFavorited: return 5
        case .unlike: return -2
        case .unfavorite: return -5
        case .beUnliked: return -3
        case .beUnfavorited: return -5
        case .consecutiveSignIn: return 0 // 动态计算
        }
    }
}

// MARK: - 积分记录
struct PointsRecord: Codable, Identifiable {
    let id: String
    let type: PointsType
    let points: Int
    let description: String
    let timestamp: Date
    let relatedId: String?  // 关联的垃圾箱ID

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: timestamp)
    }
}

// MARK: - 积分管理器
class PointsManager: ObservableObject {
    static let shared = PointsManager()

    @Published var totalPoints: Int = 0
    @Published var records: [PointsRecord] = []
    @Published var isSignedInToday: Bool = false
    @Published var consecutiveDays: Int = 0

    private let pointsKey = "userPoints"
    private let recordsKey = "pointsRecords"
    private let lastSignInKey = "lastSignInDate"
    private let consecutiveDaysKey = "consecutiveSignInDays"

    private init() {
        loadData()
        checkSignInStatus()
    }

    // MARK: - 加载数据

    private func loadData() {
        totalPoints = UserDefaults.standard.integer(forKey: pointsKey)

        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([PointsRecord].self, from: data) {
            records = decoded
        }

        consecutiveDays = UserDefaults.standard.integer(forKey: consecutiveDaysKey)
    }

    private func saveData() {
        UserDefaults.standard.set(totalPoints, forKey: pointsKey)
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
        UserDefaults.standard.set(consecutiveDays, forKey: consecutiveDaysKey)
    }

    // MARK: - 签到

    func checkSignInStatus() {
        let lastSignIn = UserDefaults.standard.object(forKey: lastSignInKey) as? Date
        let calendar = Calendar.current

        if let lastDate = lastSignIn {
            isSignedInToday = calendar.isDateInToday(lastDate)
        } else {
            isSignedInToday = false
        }
    }

    @discardableResult
    func signIn() -> Bool {
        guard !isSignedInToday else { return false }

        let calendar = Calendar.current
        let now = Date()

        // 检查是否连续签到
        let lastSignIn = UserDefaults.standard.object(forKey: lastSignInKey) as? Date
        if let lastDate = lastSignIn {
            if calendar.isDateInYesterday(lastDate) {
                consecutiveDays += 1
            } else {
                consecutiveDays = 1
            }
        } else {
            consecutiveDays = 1
        }

        // 计算积分
        var signInPoints = PointsType.signIn.points

        // 连续签到7天倍数奖励
        if consecutiveDays > 0 && consecutiveDays % 7 == 0 {
            let bonusPoints = consecutiveDays * 2
            signInPoints += bonusPoints

            // 记录连续签到奖励
            let bonusRecord = PointsRecord(
                id: UUID().uuidString,
                type: .consecutiveSignIn,
                points: bonusPoints,
                description: "连续签到\(consecutiveDays)天奖励",
                timestamp: now,
                relatedId: nil
            )
            records.insert(bonusRecord, at: 0)
        }

        // 记录签到
        let record = PointsRecord(
            id: UUID().uuidString,
            type: .signIn,
            points: signInPoints,
            description: "每日签到",
            timestamp: now,
            relatedId: nil
        )
        records.insert(record, at: 0)
        totalPoints += signInPoints

        // 保存
        UserDefaults.standard.set(now, forKey: lastSignInKey)
        isSignedInToday = true
        saveData()

        return true
    }

    // MARK: - 积分操作

    func addPoints(type: PointsType, relatedId: String? = nil, description: String? = nil) {
        let points = calculatePoints(type: type)
        let record = PointsRecord(
            id: UUID().uuidString,
            type: type,
            points: points,
            description: description ?? type.displayName,
            timestamp: Date(),
            relatedId: relatedId
        )
        records.insert(record, at: 0)
        totalPoints += points
        saveData()
    }

    private func calculatePoints(type: PointsType) -> Int {
        // 连续签到奖励在signIn方法中单独处理
        return type.points
    }

    // MARK: - 获取统计

    func getPointsByType(_ type: PointsType) -> Int {
        return records.filter { $0.type == type }.reduce(0) { $0 + $1.points }
    }

    func getRecentRecords(limit: Int = 50) -> [PointsRecord] {
        return Array(records.prefix(limit))
    }
}
