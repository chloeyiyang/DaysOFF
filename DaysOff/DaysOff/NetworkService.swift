//
//  NetworkService.swift
//  DaysOff
//

import Foundation
import UIKit

/// Network service wrapper using URLSession to communicate with the local backend.
final class NetworkService {
    static let shared = NetworkService()

    private let baseURL = URL(string: "https://daysoff-app.com")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    /// 服务器返回的 ISO8601 时间戳含毫秒小数（如 2026-08-19T15:40:34.634Z），
    /// 而 .iso8601 策略默认不支持小数秒 → 解码失败。此处自定义策略兼容两种格式。
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let sharedDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = iso8601WithFractional.date(from: str) { return date }
            if let date = iso8601Standard.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return decoder
    }()

    // MARK: - Auth Token（登录令牌）

    /// 当前会话 Bearer 令牌：登录/注册成功后写入，App 启动时从 Keychain 恢复
    var authToken: String?

    /// 为受保护接口附加 Authorization 头
    private func applyAuth(_ request: inout URLRequest) {
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    /// 校验响应状态码；401 = 令牌失效 → 清令牌并广播，App 层收到后强制重新登录
    private func check(_ response: URLResponse, status expected: Int) throws {
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }
        if http.statusCode == 401 {
            authToken = nil
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        guard http.statusCode == expected else { throw NetworkError.badResponse }
    }

    // MARK: - User Data Sync API（通用数据块云同步）

    /// 匿名活跃上报（DAU 统计用）：静默失败，不影响任何功能
    func pingActivity(userId: String) {
        var request = URLRequest(url: baseURL.appendingPathComponent("stats/ping"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["userId": userId])
        Task { _ = try? await session.data(for: request) }
    }

    /// 匿名事件上报（异常退出/网络错误）：静默失败
    func postStatEvent(type: String, screen: String, detail: String, userId: String?) {
        var request = URLRequest(url: baseURL.appendingPathComponent("stats/event"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["type": type, "screen": screen, "detail": detail]
        if let userId { body["userId"] = userId }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task { _ = try? await session.data(for: request) }
    }

    /// 全量覆盖推送该用户的某个数据块到云端
    func pushUserData(userId: String, key: String, value: Any) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["value": value])
        var request = URLRequest(url: baseURL.appendingPathComponent("user-data/\(userId)/\(key)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        try check(response, status: 200)
    }

    /// 拉取该用户全部云端数据块：{ key: value }
    func fetchUserData(userId: String) async throws -> [String: Any] {
        var request = URLRequest(url: baseURL.appendingPathComponent("user-data/\(userId)"))
        applyAuth(&request)
        let (data, response) = try await session.data(for: request)
        try check(response, status: 200)
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    // MARK: - Exhibition API

    /// Fetch all exhibitions from the server (all users).
    /// If userId is provided, exhibitions from blocked users are filtered out.
    func fetchExhibitions(requesterUserId: String? = nil) async throws -> [NetworkExhibition] {
        var url = baseURL.appendingPathComponent("exhibitions")
        if let userId = requesterUserId {
            url = URL(string: url.absoluteString + "?userId=\(userId)")!
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.badResponse
        }
        return try Self.sharedDecoder.decode([NetworkExhibition].self, from: data)
    }

    /// Publish a new exhibition to the server.
    /// Images are first uploaded to OSS via /upload-image, then the returned URLs
    /// are sent to /exhibitions (the remote backend stores URLs, not binary data).
    func createExhibition(
        id: UUID? = nil,
        userId: String,
        userName: String,
        name: String,
        introduction: String,
        startDate: String,
        endDate: String,
        firstPictureData: Data?,
        paintings: [Data],
        paintingIntroductions: [String]
    ) async throws -> NetworkExhibition {
        // 1. Upload first picture (if any) and collect its OSS URL.
        let firstPictureURL = try await uploadImageIfPresent(firstPictureData)

        // 2. Upload each painting and collect OSS URLs (skip empty data).
        var paintingURLs: [String] = []
        for painting in paintings {
            let url = try await uploadImageIfPresent(painting)
            paintingURLs.append(url ?? "")
        }

        // 3. Build JSON body using URL fields (remote backend schema).
        let body: [String: Any] = [
            "id": id?.uuidString as Any,
            "userId": userId,
            "userName": userName,
            "name": name,
            "introduction": introduction,
            "startDate": startDate,
            "endDate": endDate,
            "firstPictureURL": firstPictureURL as Any,
            "paintingURLs": paintingURLs,
            "paintingIntroductions": paintingIntroductions,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

        var request = URLRequest(url: baseURL.appendingPathComponent("exhibitions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }
        if http.statusCode == 401 {
            authToken = nil
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        // 422 = 内容审核拒绝，透传服务端错误文案
        if http.statusCode == 422 {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw NetworkError.server(message: msg ?? "图片包含违规内容，无法发布")
        }
        guard http.statusCode == 201 else { throw NetworkError.badResponse }
        return try Self.sharedDecoder.decode(NetworkExhibition.self, from: data)
    }

    /// Upload an image to OSS via /upload-image. Returns the OSS URL, or nil if data is nil/empty.
    func uploadImageIfPresent(_ data: Data?, ext: String = "jpg") async throws -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("upload-image"))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.\(ext)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/\(ext)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"ext\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(ext)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        applyAuth(&request)

        let (responseData, response) = try await session.data(for: request)
        // 非 201：优先透传服务端错误文案（如格式/违规拒绝），401 走统一重登
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }
        if http.statusCode == 401 {
            authToken = nil
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        guard http.statusCode == 201 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: responseData))?["error"]
            throw NetworkError.server(message: msg ?? "上传失败")
        }
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let url = json["url"] as? String else {
            throw NetworkError.badResponse
        }
        return url
    }

    // MARK: - Report & Block API

    /// 举报展览
    func reportExhibition(exhibitionId: UUID, reporterUserId: String, reason: String) async throws {
        let body: [String: Any] = [
            "exhibitionId": exhibitionId.uuidString,
            "reporterUserId": reporterUserId,
            "reason": reason
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: baseURL.appendingPathComponent("exhibitions").appendingPathComponent("report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (_, response) = try await session.data(for: request)
        try check(response, status: 200)
    }

    /// 拉黑用户（拉黑后不再看到该用户的展览）
    func blockUser(blockerUserId: String, blockedUserId: String) async throws {
        let body: [String: Any] = [
            "blockerUserId": blockerUserId,
            "blockedUserId": blockedUserId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent("block"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (_, response) = try await session.data(for: request)
        try check(response, status: 200)
    }

    // MARK: - Travel Ideas API

    /// Fetch all travel ideas from the server (all users).
    func fetchTravelIdeas() async throws -> [NetworkTravelIdea] {
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("travel-ideas"))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NetworkError.badResponse
        }
        return try Self.sharedDecoder.decode([NetworkTravelIdea].self, from: data)
    }

    /// Sync (replace) this user's travel ideas on the server. Returns all ideas from all users.
    func syncTravelIdeas(userId: String, userName: String, ideas: [TravelIdea]) async throws -> [NetworkTravelIdea] {
        let payloads = ideas.map { idea in
            TravelIdeaPayload(
                id: idea.id,
                title: idea.title,
                content: idea.content,
                destination: idea.destination,
                landmark: idea.landmark,
                date: idea.date,
                startDate: idea.startDate,
                endDate: idea.endDate
            )
        }
        let body = SyncTravelIdeasRequest(userId: userId, userName: userName, ideas: payloads)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bodyData = try encoder.encode(body)

        var request = URLRequest(url: baseURL.appendingPathComponent("travel-ideas"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try check(response, status: 200)
        return try Self.sharedDecoder.decode([NetworkTravelIdea].self, from: data)
    }

    // MARK: - User Auth API

    private struct AuthResponse: Codable {
        let userId: String
        let username: String
        let token: String
    }

    private struct AuthErrorResponse: Codable {
        let error: String
    }

    /// 注册新用户。成功返回 (userId, username, token)。
    func register(username: String, password: String) async throws -> (userId: String, username: String, token: String) {
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "deviceType": Self.deviceType
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }

        if http.statusCode == 201 {
            let result = try JSONDecoder().decode(AuthResponse.self, from: data)
            return (result.userId, result.username, result.token)
        }
        let err = (try? JSONDecoder().decode(AuthErrorResponse.self, from: data))?.error ?? "注册失败"
        throw NetworkError.server(message: err)
    }

    /// 登录用户。成功返回 (userId, username, token)。
    func login(username: String, password: String) async throws -> (userId: String, username: String, token: String) {
        let body: [String: Any] = [
            "username": username,
            "password": password,
            "deviceType": Self.deviceType
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }

        if http.statusCode == 200 {
            let result = try JSONDecoder().decode(AuthResponse.self, from: data)
            return (result.userId, result.username, result.token)
        }
        let err = (try? JSONDecoder().decode(AuthErrorResponse.self, from: data))?.error ?? "登录失败"
        throw NetworkError.server(message: err)
    }

    /// 当前设备类型：iPhone → "iphone"，iPad → "ipad"
    private static var deviceType: String {
        UITraitCollection.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    }

    // MARK: - Feedback API

    /// 提交用户留言。需登录（Bearer token），后端会通过 token 解析用户名。
    /// 成功返回 true；失败（格式错误、网络错误等）抛 NetworkError。
    func submitFeedback(email: String, message: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "message": message
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: baseURL.appendingPathComponent("feedback"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }
        if http.statusCode == 401 {
            authToken = nil
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        guard http.statusCode == 201 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw NetworkError.server(message: msg ?? "提交失败")
        }
    }

    // MARK: - Account Deletion API

    /// 注销当前登录账号：服务器将删除该用户的所有数据（用户、令牌、展览、留言、数据块等）。
    /// 需登录；可选 reason 记录注销原因。成功后令牌已失效，调用方应清本地数据并回到登录页。
    func deleteAccount(reason: String?) async throws {
        var bodyData: Data?
        if let reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
            bodyData = try? JSONSerialization.data(withJSONObject: ["reason": reason])
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("users").appendingPathComponent("me"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.badResponse }
        if http.statusCode == 401 {
            authToken = nil
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
            throw NetworkError.unauthorized
        }
        guard http.statusCode == 200 else {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw NetworkError.server(message: msg ?? "注销失败")
        }
        // 服务器已删除该账号所有令牌，本地令牌同样失效
        authToken = nil
    }
}

// MARK: - Errors

enum NetworkError: Error {
    case badResponse
    case unauthorized
    case server(message: String)
}

extension Notification.Name {
    /// 服务端返回 401（令牌缺失/失效）时广播，App 层收到后强制回到登录页
    static let daysOffSessionExpired = Notification.Name("DaysOffSessionExpired")
}
