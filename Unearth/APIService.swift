//
//  APIService.swift
//  Unearth
//
//  Created by Theo on 2026/6/11.
//

import Foundation

// MARK: - API 配置
struct APIConfig {
    static let baseURL = "http://110.40.169.213:8081"
    static var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }
}

// MARK: - API 错误
enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)
    case unauthorized
}

// MARK: - 空响应
struct EmptyResponse: Codable {}

// MARK: - API 响应
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
}

struct PageResult<T: Codable>: Codable {
    let records: [T]
    let total: Int
    let size: Int
    let current: Int
    let pages: Int
}

// MARK: - API 服务
class APIService {
    static let shared = APIService()
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {}

    // MARK: - 通用请求方法

    private func request<T: Codable>(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = APIConfig.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(.noData))
                }
                return
            }

            // 检查 HTTP 状态码
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    DispatchQueue.main.async {
                        completion(.failure(.unauthorized))
                    }
                    return
                }
            }

            do {
                let result = try self.decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                // 尝试解析错误信息
                if let errorResponse = try? self.decoder.decode(APIResponse<String>.self, from: data) {
                    DispatchQueue.main.async {
                        completion(.failure(.serverError(errorResponse.message)))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(.decodingError(error)))
                    }
                }
            }
        }.resume()
    }

    // MARK: - 认证接口

    /// 获取图形验证码
    func getCaptcha(completion: @escaping (Result<APIResponse<CaptchaResult>, APIError>) -> Void) {
        request(path: "/api/captcha", completion: completion)
    }

    /// 发送验证码（需要图形验证码）
    func sendCode(phone: String, captchaId: String, captchaCode: String, completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        let body: [String: Any] = [
            "phone": phone,
            "captchaId": captchaId,
            "captchaCode": captchaCode
        ]
        request(path: "/api/sms/send", method: "POST", body: body, completion: completion)
    }

    /// 注销账号
    func deleteAccount(phone: String, code: String, completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        let body: [String: Any] = [
            "phone": phone,
            "code": code
        ]
        request(path: "/api/user/delete", method: "POST", body: body, completion: completion)
    }

    /// 登录
    func login(phone: String, code: String, captchaId: String, captchaCode: String, completion: @escaping (Result<APIResponse<LoginResult>, APIError>) -> Void) {
        let body: [String: Any] = [
            "phone": phone,
            "code": code,
            "captchaId": captchaId,
            "captchaCode": captchaCode
        ]
        request(path: "/api/auth/login", method: "POST", body: body, completion: completion)
    }

    /// 检查 token
    func checkToken(completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        request(path: "/api/auth/check", completion: completion)
    }

    // MARK: - 垃圾箱接口

    /// 获取附近垃圾箱
    func getNearbyTrashBins(
        latitude: Double,
        longitude: Double,
        radius: Double = 2000,
        completion: @escaping (Result<APIResponse<[TrashBinVO]>, APIError>) -> Void
    ) {
        let path = "/api/trashbins/nearby?latitude=\(latitude)&longitude=\(longitude)&radius=\(radius)"
        request(path: path, completion: completion)
    }

    /// 获取垃圾箱列表（分页）
    func getTrashBins(
        page: Int = 1,
        size: Int = 25,
        completion: @escaping (Result<APIResponse<PageResult<TrashBinVO>>, APIError>) -> Void
    ) {
        request(path: "/api/trashbins?page=\(page)&size=\(size)", completion: completion)
    }

    /// 获取垃圾箱详情
    func getTrashBinDetail(id: Int, completion: @escaping (Result<APIResponse<TrashBinVO>, APIError>) -> Void) {
        request(path: "/api/trashbins/\(id)", completion: completion)
    }

    /// 点赞/取消点赞
    func toggleLike(id: Int, completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        request(path: "/api/user/trashbins/\(id)/like", method: "POST", completion: completion)
    }

    /// 收藏/取消收藏
    func toggleFavorite(id: Int, completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        request(path: "/api/user/trashbins/\(id)/favorite", method: "POST", completion: completion)
    }

    /// 发现垃圾箱
    func discoverTrashBin(
        name: String,
        latitude: Double,
        longitude: Double,
        type: String,
        address: String?,
        completion: @escaping (Result<APIResponse<TrashBinVO>, APIError>) -> Void
    ) {
        var body: [String: Any] = [
            "name": name,
            "latitude": latitude,
            "longitude": longitude,
            "type": type
        ]
        if let address = address {
            body["address"] = address
        }
        request(path: "/api/user/trashbins/discover", method: "POST", body: body, completion: completion)
    }

    /// 更新垃圾箱信息
    func updateTrashBin(
        id: Int,
        name: String?,
        type: String?,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        completion: @escaping (Result<APIResponse<TrashBinVO>, APIError>) -> Void
    ) {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let type = type { body["type"] = type }
        if let address = address { body["address"] = address }
        if let latitude = latitude { body["latitude"] = latitude }
        if let longitude = longitude { body["longitude"] = longitude }
        request(path: "/api/user/trashbins/\(id)", method: "PUT", body: body, completion: completion)
    }

    /// 获取用户发现的垃圾箱
    func getMyTrashBins(completion: @escaping (Result<APIResponse<[TrashBinVO]>, APIError>) -> Void) {
        request(path: "/api/user/trashbins/my", completion: completion)
    }

    // MARK: - 用户接口

    /// 获取用户信息
    func getUserProfile(completion: @escaping (Result<APIResponse<UserVO>, APIError>) -> Void) {
        request(path: "/api/user/profile", completion: completion)
    }

    // MARK: - 宫格/积分接口

    /// 获取我的宫格信息
    func getMyGrid(completion: @escaping (Result<APIResponse<UserGridVO>, APIError>) -> Void) {
        request(path: "/api/user/grid/me", completion: completion)
    }

    /// 每日签到
    func checkIn(completion: @escaping (Result<APIResponse<CheckInResult>, APIError>) -> Void) {
        request(path: "/api/user/grid/checkin", method: "POST", completion: completion)
    }

    /// 保存像素数据
    func savePixelData(pixelData: String, completion: @escaping (Result<APIResponse<EmptyResponse>, APIError>) -> Void) {
        request(path: "/api/user/grid/pixel-data", method: "PUT", body: ["pixelData": pixelData], completion: completion)
    }

    /// 获取积分变动记录
    func getPointsLogs(
        page: Int = 1,
        size: Int = 25,
        completion: @escaping (Result<APIResponse<PageResult<PointsLogVO>>, APIError>) -> Void
    ) {
        request(path: "/api/user/grid/points-logs?page=\(page)&size=\(size)", completion: completion)
    }

    /// 获取宫格规则
    func getGridRules(completion: @escaping (Result<APIResponse<GridRulesVO>, APIError>) -> Void) {
        request(path: "/api/user/grid/rules", completion: completion)
    }
}

// MARK: - API 数据模型

struct LoginResult: Codable {
    let token: String
    let userId: Int
    let phone: String
    let nickname: String?
}

struct TrashBinVO: Codable, Identifiable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let type: String
    let iconUrl: String?
    let photoUrl: String?
    let address: String?
    let status: String?
    let reviewStatus: String?
    let reviewComment: String?
    let reviewedAt: String?
    let reviewer: String?
    let likeCount: Int?
    let favoriteCount: Int?
    let liked: Bool?
    let favorited: Bool?
    let discoveredAt: String?
    let discoverer: String?
    let updatedAt: String?
    let updater: String?
    let updateContent: String?

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
}

struct UserVO: Codable {
    let id: Int
    let phone: String
    let nickname: String?
    let avatar: String?
    let createdAt: String?
}

struct UserGridVO: Codable {
    let userId: Int
    let nickname: String?
    let points: Int
    let level: Int
    let realmName: String?
    let stageName: String?
    let fullRealmName: String?
    let gridSize: Int
    let pixelData: String?
    let pointsToNextLevel: Int
    let nextGridSize: Int
    let nextRealmName: String?
    let todayPoints: Int
    let lastCheckInAt: String?
    let checkedInToday: Bool
}

struct PointsLogVO: Codable, Identifiable {
    let id: Int
    let points: Int
    let type: String
    let typeName: String
    let remark: String?
    let createdAt: String?
}

struct GridRulesVO: Codable {
    let levels: [LevelConfigVO]?
    let pointsRules: [PointsRuleVO]?
}

struct LevelConfigVO: Codable {
    let level: Int
    let gridSize: Int
    let realmName: String?
    let stageName: String?
    let requiredPoints: Int
}

struct PointsRuleVO: Codable {
    let type: String
    let points: Int
    let description: String?
}

struct CheckInResult: Codable {
    let points: Int
    let consecutiveDays: Int
    let bonusPoints: Int?
}

struct CaptchaResult: Codable {
    let captchaId: String
    let image: String  // Base64 编码的图片
}
