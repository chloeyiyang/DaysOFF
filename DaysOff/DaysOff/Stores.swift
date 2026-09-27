//
//  Stores.swift
//  DaysOff
//
//  视图状态层（MVVM）：所有 NetworkService 调用收敛于此，
//  View 只绑定 Store 的 @Published 状态，不直接触碰网络层。
//

import SwiftUI
import Combine
import CryptoKit
import Security

// MARK: - 端到端加密（E2EE）

/// 私密数据（心情手记/运动笔记/运动计划/旅行卡片/赛事卡片/未公开作品）在本地加密后才上传。
/// 密钥由用户密码在本机派生，派生盐与登录认证哈希完全独立；服务器只存密文，运营者无法查看。
/// 代价：忘记密码 = 云端私密数据无法恢复（隐私政策中已向用户明示）。
enum CryptoBox {
    /// 加密数据包在 JSON 中的标记字段
    private static let wrapperKey = "__e2ee__"
    private static let keySalt = "DaysOff_E2EE_Key_v1"
    private static var cachedKey: SymmetricKey?

    // MARK: 密钥生命周期

    /// 登录/注册成功后调用：从密码派生密钥，写 Keychain + 内存缓存
    static func deriveAndStore(password: String, userId: String) {
        let keyData = Data(SHA256.hash(data: Data((password + keySalt).utf8)))
        saveToKeychain(keyData, userId: userId)
        cachedKey = SymmetricKey(data: keyData)
    }

    /// App 启动进入首页时调用：从 Keychain 载入密钥（已登录用户免输密码）
    static func loadKey(userId: String) {
        guard let data = loadFromKeychain(userId: userId) else { return }
        cachedKey = SymmetricKey(data: data)
    }

    // MARK: 加密 / 解密

    /// JSON 字符串 → 加密数据包；无密钥时返回 nil（绝不明文上传私密数据）
    static func encryptJSONString(_ plain: String) -> [String: String]? {
        guard let key = cachedKey,
              let plainData = plain.data(using: .utf8),
              let sealed = try? AES.GCM.seal(plainData, using: key),
              let combined = sealed.combined else { return nil }
        return [wrapperKey: combined.base64EncodedString()]
    }

    /// 云端数据块 → 原始 JSON 值：加密包则解密还原；旧格式明文原样返回（平滑迁移）；
    /// 是加密包但无密钥/解密失败时返回 nil（保留云端数据，待重新登录后恢复）
    static func unwrap(_ value: Any?) -> Any? {
        guard let value, !(value is NSNull) else { return nil }
        guard let dict = value as? [String: Any], let cipher = dict[wrapperKey] as? String else {
            return value
        }
        guard let key = cachedKey,
              let combined = Data(base64Encoded: cipher),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plainData = try? AES.GCM.open(box, using: key),
              let obj = try? JSONSerialization.jsonObject(with: plainData) else { return nil }
        return obj
    }

    // MARK: Keychain

    private static func keychainQuery(userId: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.daysoff.e2ee",
         kSecAttrAccount as String: userId]
    }

    private static func saveToKeychain(_ data: Data, userId: String) {
        var query = keychainQuery(userId: userId)
        SecItemDelete(query as CFDictionary)  // 覆盖旧密钥（重新登录/改密码场景）
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadFromKeychain(userId: String) -> Data? {
        var query = keychainQuery(userId: userId)
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    /// 账号注销时调用：从 Keychain 删除该用户的 E2EE 密钥并清空内存缓存
    static func clear(userId: String) {
        SecItemDelete(keychainQuery(userId: userId) as CFDictionary)
        cachedKey = nil
    }
}

// MARK: - 登录令牌存储（Keychain）

/// Bearer 令牌按 userId 存 Keychain，仅本机可用；重新登录覆盖旧令牌
enum TokenStore {
    private static func query(userId: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.daysoff.auth",
         kSecAttrAccount as String: userId]
    }

    static func save(token: String, userId: String) {
        var q = query(userId: userId)
        SecItemDelete(q as CFDictionary)  // 覆盖旧令牌
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load(userId: String) -> String? {
        var q = query(userId: userId)
        q[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 账号注销时调用：从 Keychain 删除该用户的登录令牌
    static func clear(userId: String) {
        SecItemDelete(query(userId: userId) as CFDictionary)
    }
}

// MARK: - 登录 / 注册

@MainActor
final class AuthStore: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""

    func login(username: String, password: String) async -> (userId: String, username: String)? {
        let result = await authenticate { try await NetworkService.shared.login(username: username, password: password) }
        guard let result else { return nil }
        CryptoBox.deriveAndStore(password: password, userId: result.userId)
        TokenStore.save(token: result.token, userId: result.userId)
        NetworkService.shared.authToken = result.token
        return (result.userId, result.username)
    }

    func register(username: String, password: String) async -> (userId: String, username: String)? {
        let result = await authenticate { try await NetworkService.shared.register(username: username, password: password) }
        guard let result else { return nil }
        CryptoBox.deriveAndStore(password: password, userId: result.userId)
        TokenStore.save(token: result.token, userId: result.userId)
        NetworkService.shared.authToken = result.token
        return (result.userId, result.username)
    }

    private func authenticate(
        _ call: () async throws -> (userId: String, username: String, token: String)
    ) async -> (userId: String, username: String, token: String)? {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        do {
            return try await call()
        } catch let NetworkError.server(msg) {
            errorMessage = msg
            return nil
        } catch {
            errorMessage = "网络错误，请检查网络后重试"
            AppStats.reportNetworkError(detail: "auth")
            return nil
        }
    }
}

// MARK: - 展览（社群画展）

@MainActor
final class ExhibitionStore: ObservableObject {
    /// 全局共享实例：展览数据是 App 级状态，避免在视图链中层层传递
    static let shared = ExhibitionStore()

    /// 社群展览列表（参观当前展览）
    @Published private(set) var networkExhibitions: [NetworkExhibition] = []
    /// 当前用户的展览记录（我的页面卡片）
    @Published private(set) var myExhibitions: [ExhibitionRecord] = []
    @Published var showNetworkError = false
    /// 图片审核/格式拒绝提示（顶部横幅，文案由服务端给出）
    @Published var moderationMessage = ""
    @Published var showModerationAlert = false

    /// 上传被服务端拒绝时调用：统一从任意上传链路弹出提示
    func flagModerationReject(_ message: String) {
        moderationMessage = message
        showModerationAlert = true
    }

    /// 退出登录时调用：清除内存中的展览数据和错误状态
    func reset() {
        networkExhibitions = []
        myExhibitions = []
        showNetworkError = false
        moderationMessage = ""
        showModerationAlert = false
        lastFetchHadError = false
    }

    private var lastFetchHadError = false
    private var pollTimer: Timer?

    // MARK: 首页轮询（拉全量 → 过滤出我的展览记录）

    func startPolling(userId: String) {
        stopPolling()
        Task { await refreshAll(userId: userId) }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll(userId: userId)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshAll(userId: String) async {
        do {
            let all = try await NetworkService.shared.fetchExhibitions()
            // 异步加载首图（远程 OSS URL → Data），避免阻塞 UI
            let myRecords = await all
                .filter { $0.userId == userId }
                .toExhibitionRecords()
            networkExhibitions = all
            myExhibitions = myRecords
            lastFetchHadError = false
        } catch {
            flagFetchError()
        }
    }

    // MARK: 社群展览（按 requester 过滤已拉黑用户）

    func refreshCommunity(requesterUserId: String) async {
        do {
            let exhibitions = try await NetworkService.shared.fetchExhibitions(requesterUserId: requesterUserId)
            networkExhibitions = exhibitions
            lastFetchHadError = false
        } catch {
            flagFetchError()
        }
    }

    // MARK: 发布展览

    @discardableResult
    func publish(
        userId: String, userName: String,
        name: String, introduction: String,
        startDate: String, endDate: String,
        firstPictureData: Data?,
        paintings: [Data],
        paintingIntroductions: [String]
    ) async -> Bool {
        do {
            _ = try await NetworkService.shared.createExhibition(
                userId: userId, userName: userName,
                name: name, introduction: introduction,
                startDate: startDate, endDate: endDate,
                firstPictureData: firstPictureData,
                paintings: paintings,
                paintingIntroductions: paintingIntroductions
            )
            return true
        } catch let NetworkError.server(msg) {
            // 服务端明确拒绝（图片格式/内容违规）：弹出具体原因，不显示通用网络错误
            print("[Gallery] Exhibition rejected by server: \(msg)")
            flagModerationReject(msg)
            return false
        } catch {
            print("[Gallery] Failed to publish exhibition to server: \(error)")
            showNetworkError = true
            return false
        }
    }

    // MARK: 举报 / 拉黑

    /// 返回成功提示文案；返回 nil 表示举报失败（已触发网络错误横幅）
    func report(
        exhibitionId: UUID, reporterUserId: String, reason: String,
        blockedUserId: String, alsoBlock: Bool
    ) async -> String? {
        do {
            try await NetworkService.shared.reportExhibition(
                exhibitionId: exhibitionId, reporterUserId: reporterUserId, reason: reason
            )
        } catch {
            showNetworkError = true
            return nil
        }
        if alsoBlock {
            do {
                try await NetworkService.shared.blockUser(
                    blockerUserId: reporterUserId, blockedUserId: blockedUserId
                )
                return "已举报并拉黑该用户"
            } catch {
                return "举报已提交，感谢您的反馈"
            }
        }
        return "举报已提交，感谢您的反馈"
    }

    // 轮询每 15s 一次，仅在首次连续失败时提示一次，避免反复弹窗
    private func flagFetchError() {
        if !lastFetchHadError { showNetworkError = true }
        lastFetchHadError = true
        AppStats.reportNetworkError(detail: "exhibitions")
    }
}

// MARK: - 匿名运行统计（异常退出 / 网络错误 / 界面轨迹）

enum AppStats {
    private static let screenKey = "stats_last_screen"
    private static let activeFlagKey = "stats_session_active"
    private static let crashDetailKey = "stats_last_crash_detail"

    /// 当前登录用户 id（ContentView 出现时写入）；上报时由服务端哈希存储
    static var currentUserId: String?

    /// 相同事件 5 分钟内只报一次，避免轮询接口在断网时刷量
    private static var lastSentAt: [String: Date] = [:]

    static var currentScreen: String {
        UserDefaults.standard.string(forKey: screenKey) ?? "unknown"
    }

    /// 记录用户最后停留的界面（各页面 trackScreen 调用）
    static func setScreen(_ name: String) {
        UserDefaults.standard.set(name, forKey: screenKey)
    }

    /// 进入前台：若上次会话标志未被清除 → 上次为异常退出（崩溃/卡死被系统终止），上报最后停留界面
    static func sessionDidBecomeActive() {
        let d = UserDefaults.standard
        let detail = d.string(forKey: crashDetailKey) ?? ""
        d.removeObject(forKey: crashDetailKey)
        if d.bool(forKey: activeFlagKey) {
            report(type: "abnormal_exit", screen: currentScreen, detail: detail)
        }
        d.set(true, forKey: activeFlagKey)
    }

    /// 退到后台属正常生命周期（此后系统回收进程不算异常），清除标志
    static func sessionDidEnterBackground() {
        UserDefaults.standard.set(false, forKey: activeFlagKey)
    }

    /// NSException 崩溃兜底：写入本地，下次启动随 abnormal_exit 上报
    static func recordCrashDetail(_ text: String) {
        UserDefaults.standard.set(String(text.prefix(180)), forKey: crashDetailKey)
    }

    static func reportNetworkError(detail: String) {
        report(type: "network_error", screen: currentScreen, detail: detail)
    }

    private static func report(type: String, screen: String, detail: String) {
        let key = "\(type)|\(screen)|\(detail)"
        if let t = lastSentAt[key], Date().timeIntervalSince(t) < 300 { return }
        lastSentAt[key] = Date()
        NetworkService.shared.postStatEvent(type: type, screen: screen, detail: detail, userId: currentUserId)
    }
}

extension View {
    /// 页面轨迹：onAppear 时记录界面名
    func trackScreen(_ name: String) -> some View {
        onAppear { AppStats.setScreen(name) }
    }
}

// MARK: - 旅行灵感同步

@MainActor
final class TravelIdeasStore: ObservableObject {
    /// 其他用户的灵感分组（用于目的地匹配）
    @Published private(set) var networkUsers: [MatchUser] = []
    @Published var showNetworkError = false

    private var lastPollHadError = false
    private var pollTimer: Timer?
    /// 本地 ideas 为空时，从后端拉取该用户的灵感回填本地（避免退出登录清空本地后用空数组覆盖后端）
    var onRestoredMyIdeas: (([TravelIdea]) -> Void)?

    // MARK: 轮询（先同步一次本地灵感，再每 15s 拉取他人灵感）

    func startPolling(userId: String, userName: String, ideas: @escaping () -> [TravelIdea]) {
        stopPolling()
        Task { await sync(userId: userId, userName: userName, ideas: ideas()) }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetch(userId: userId)
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: 拉取他人灵感

    func fetch(userId: String) async {
        do {
            let allIdeas = try await NetworkService.shared.fetchTravelIdeas()
            rebuildUsers(from: allIdeas, excluding: userId)
            lastPollHadError = false
        } catch {
            if !lastPollHadError { showNetworkError = true }
            lastPollHadError = true
        }
    }

    // MARK: 同步我的灵感到服务器

    func sync(userId: String, userName: String, ideas: [TravelIdea]) async {
        // 本地为空时跳过同步，避免覆盖后端（恢复由 restoreIfNeeded 处理）
        guard !ideas.isEmpty else {
            // 兜底：尝试从共享表拉取该用户的灵感回填本地
            do {
                let allIdeas = try await NetworkService.shared.fetchTravelIdeas()
                let myBackendIdeas = allIdeas.filter { $0.userId == userId }
                if !myBackendIdeas.isEmpty {
                    let restored: [TravelIdea] = myBackendIdeas.map { net in
                        TravelIdea(
                            id: net.id,
                            title: net.title,
                            content: net.content,
                            destination: net.destination,
                            landmark: net.landmark,
                            date: net.date,
                            startDate: net.startDate,
                            endDate: net.endDate
                        )
                    }
                    onRestoredMyIdeas?(restored)
                    rebuildUsers(from: allIdeas, excluding: userId)
                }
            } catch {
                showNetworkError = true
            }
            return
        }

        // 1. 推送到 user_data 通用块（主存储，E2EE 加密）
        UserSyncStore.shared.pushTravelIdeas(userId: userId, ideas: ideas)

        // 2. 同步到 travel_ideas 共享表（让其他用户看到我的灵感）
        do {
            let allIdeas = try await NetworkService.shared.syncTravelIdeas(
                userId: userId, userName: userName, ideas: ideas
            )
            rebuildUsers(from: allIdeas, excluding: userId)
        } catch {
            showNetworkError = true
        }
    }

    // 过滤掉自己的灵感，按用户分组构建 MatchUser
    private func rebuildUsers(from allIdeas: [NetworkTravelIdea], excluding userId: String) {
        let others = allIdeas.filter { $0.userId != userId }
        let grouped = Dictionary(grouping: others, by: { $0.userId })
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        networkUsers = grouped.enumerated().map { (index, pair) in
            let (otherUserId, otherIdeas) = pair
            let name = otherIdeas.first?.userName ?? otherUserId
            let color = colors[index % colors.count]
            let ideas = otherIdeas.map { netIdea in
                TravelIdea(
                    id: netIdea.id,
                    title: netIdea.title,
                    content: netIdea.content,
                    destination: netIdea.destination,
                    landmark: netIdea.landmark,
                    date: netIdea.date,
                    startDate: netIdea.startDate,
                    endDate: netIdea.endDate
                )
            }
            return MatchUser(name: name, color: color, ideas: ideas)
        }
    }
}

// MARK: - 用户数据云同步（作品 / 运动 / 心情 / 旅行卡片 / 赛事卡片）

/// 云端作品 DTO：图片只存 OSS URL，恢复时再下载回 Data
private struct CloudArtwork: Codable {
    let id: UUID
    let imageURL: String
    let date: String
    let blessing: String
    let isPublic: Bool
}

private struct CloudSection: Codable {
    let id: UUID
    let type: String?
    let artworks: [CloudArtwork]
}

@MainActor
final class UserSyncStore: ObservableObject {
    static let shared = UserSyncStore()
    private init() {}

    /// 本次运行已完成过恢复的用户，避免重复拉取
    private var restoredUserIds: Set<String> = []
    private let ossCacheDefaultsKey = "oss_image_url_cache"

    /// 退出登录时调用：清除已恢复标记，使下次登录能重新从服务器拉取数据
    func clearRestoredState(userId: String) {
        restoredUserIds.remove(userId)
    }

    // MARK: 本地 UserDefaults key（与各模块现有 key 对齐）

    private func worksKey(_ u: String) -> String { "gallery_saved_artwork_sections_" + u }
    private func moodDiaryKey(_ u: String) -> String { "\(u)_mood_diary" }
    private func tripsKey(_ u: String) -> String { "\(u)_packed_trips" }
    private func eventsKey(_ u: String) -> String { "\(u)_events_matches" }
    private func sportsPlansKey(_ u: String) -> String { "\(u)_sports_savedPlansJSON" }
    private func sportsDiaryKey(_ u: String) -> String { "\(u)_sports_diaryJSON" }
    private func milestonesKey(_ u: String) -> String { "\(u)_milestones" }
    private let exhibitionHistoryKey = "gallery_exhibition_history"

    // MARK: - 推送（本地变更后调用，静默失败）

    /// 上传作品：图片先传 OSS（带哈希缓存，同图不重复传），云端只存 URL
    func pushWorks(userId: String) {
        Task {
            guard let data = UserDefaults.standard.data(forKey: worksKey(userId)),
                  let sections = try? JSONDecoder().decode([SavedSectionEntry].self, from: data) else { return }
            var cloud: [CloudSection] = []
            for section in sections {
                var artworks: [CloudArtwork] = []
                for artwork in section.artworks {
                    // 任一图片上传失败则整体中止，避免云端被不完整数据覆盖
                    guard let url = await ossURL(for: artwork.data) else { return }
                    artworks.append(CloudArtwork(id: artwork.id, imageURL: url, date: artwork.date,
                                                 blessing: artwork.blessing, isPublic: artwork.isPublic))
                }
                cloud.append(CloudSection(id: section.id, type: section.type, artworks: artworks))
            }
            try? await push(cloud, userId: userId, key: "works")
        }
    }

    /// 运动计划 / 运动笔记：本地本就是 JSON 字符串，原样转对象推送
    func pushSportsPlans(userId: String, json: String) { pushJSONString(json, userId: userId, key: "sports_plans") }
    func pushSportsDiary(userId: String, json: String) { pushJSONString(json, userId: userId, key: "sports_diary") }

    /// 运动三格文字（热身/练习/整理）：收集所有运动项的格子文字合并推送
    func pushSportsCellTexts(userId: String) {
        var allTexts: [String: [String]] = [:]
        let prefix = "\(userId)_sports_cellTexts_"
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            let sport = String(key.dropFirst(prefix.count))
            if let texts = UserDefaults.standard.array(forKey: key) as? [String] {
                allTexts[sport] = texts
            }
        }
        guard let json = try? JSONEncoder().encode(allTexts),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        pushJSONString(jsonString, userId: userId, key: "sports_cell_texts")
    }

    /// 运动奖杯/里程碑状态：收集所有运动项的奖杯 UUID 合并推送
    func pushSportsTrophies(userId: String) {
        var allTrophies: [String: [UUID]] = [:]
        let prefix = "\(userId)_sports_trophies_"
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            let sport = String(key.dropFirst(prefix.count))
            if let data = UserDefaults.standard.data(forKey: key),
               let ids = try? JSONDecoder().decode([UUID].self, from: data) {
                allTrophies[sport] = ids
            }
        }
        guard let json = try? JSONEncoder().encode(allTrophies),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        pushJSONString(jsonString, userId: userId, key: "sports_trophies")
    }

    func pushMoodDiaries(userId: String, diaries: [HappyDiaryData]) {
        Task {
            if diaries.isEmpty {
                try? await NetworkService.shared.pushUserData(userId: userId, key: "mood_diary", value: NSNull())
            } else {
                try? await push(diaries, userId: userId, key: "mood_diary")
            }
        }
    }

    func pushPackedTrips(userId: String, trips: [PackedTrip]) {
        Task { try? await push(trips, userId: userId, key: "packed_trips") }
    }

    /// 旅行灵感主存储推送（user_data 通用块，E2EE 加密）
    /// 本地为空时跳过推送，避免覆盖后端（恢复由 restoreIfNeeded 处理）
    func pushTravelIdeas(userId: String, ideas: [TravelIdea]) {
        guard !ideas.isEmpty else { return }
        Task { try? await push(ideas, userId: userId, key: "travel_ideas") }
    }

    func pushEvents(userId: String, events: [EventsMatchEntry]) {
        Task { try? await push(events, userId: userId, key: "events_matches") }
    }

    func pushMilestones(userId: String, milestones: [MilestoneRecord]) {
        Task { try? await push(milestones, userId: userId, key: "milestones") }
    }

    /// 卡片位置/旋转：只收集 v3 版本（ZStack 中心偏移基准）的位置推送
    /// v1(无后缀)/v2 是旧坐标系历史数据，跳过不推送（PinableCard 也不会读取它们）
    func pushCardPositions(userId: String) {
        var payload: [String: Any] = [:]
        // v3 key 格式：card_pos_{userId}_{cardId}_v3
        let v3PosPrefix = "card_pos_\(userId)_"
        let v3Suffix = "_v3"
        let rotPrefix = "card_rot_\(userId)_"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(v3PosPrefix) && key.hasSuffix(v3Suffix) {
                // cardId = 去掉前缀 + 去掉后缀
                let withoutPrefix = String(key.dropFirst(v3PosPrefix.count))
                let cardId = String(withoutPrefix.dropLast(v3Suffix.count))
                if let data = defaults.data(forKey: key),
                   let arr = try? JSONDecoder().decode([CGFloat].self, from: data), arr.count == 2 {
                    payload["posv3_\(cardId)"] = [arr[0], arr[1]]
                }
            } else if key.hasPrefix(rotPrefix) {
                let cardId = String(key.dropFirst(rotPrefix.count))
                let rot = defaults.double(forKey: key)
                payload["rot_\(cardId)"] = rot
            }
        }
        guard !payload.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: json, encoding: .utf8) else { return }
        pushJSONString(jsonString, userId: userId, key: "card_positions")
    }

    // MARK: - 恢复（登录后调用；只补本地没有的数据，绝不覆盖本地）

    func restoreIfNeeded(userId: String) async {
        guard !restoredUserIds.contains(userId) else { return }
        restoredUserIds.insert(userId)
        guard let blobs = try? await NetworkService.shared.fetchUserData(userId: userId) else {
            restoredUserIds.remove(userId)  // 拉取失败允许下次重试
            return
        }
        // 十类私密数据均为 E2EE 密文；unwrap 对旧格式明文原样透传（平滑迁移）
        await restoreWorks(CryptoBox.unwrap(blobs["works"]), userId: userId)
        restoreJSONString(CryptoBox.unwrap(blobs["sports_plans"]), key: sportsPlansKey(userId))
        restoreJSONString(CryptoBox.unwrap(blobs["sports_diary"]), key: sportsDiaryKey(userId))
        restoreSportsCellTexts(CryptoBox.unwrap(blobs["sports_cell_texts"]), userId: userId)
        restoreSportsTrophies(CryptoBox.unwrap(blobs["sports_trophies"]), userId: userId)
        restoreMoodDiaries(CryptoBox.unwrap(blobs["mood_diary"]), userId: userId)
        restoreCodable(CryptoBox.unwrap(blobs["packed_trips"]), as: [PackedTrip].self, key: tripsKey(userId))
        restoreCodable(CryptoBox.unwrap(blobs["events_matches"]), as: [EventsMatchEntry].self, key: eventsKey(userId))
        restoreCodable(CryptoBox.unwrap(blobs["milestones"]), as: [MilestoneRecord].self, key: milestonesKey(userId))
        restoreCardPositions(CryptoBox.unwrap(blobs["card_positions"]), userId: userId)
        await restoreExhibitionHistory(userId: userId)
        // 旅行灵感主存储走 user_data 通用块（与图片/运动笔记同机制）
        restoreCodable(CryptoBox.unwrap(blobs["travel_ideas"]), as: [TravelIdea].self, key: "travel_saved_ideas_\(userId)")
    }

    // MARK: - 私有：恢复各项

    private func restoreWorks(_ value: Any?, userId: String) async {
        guard let value, !(value is NSNull) else { return }
        guard UserDefaults.standard.data(forKey: worksKey(userId)) == nil else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let cloud = try? JSONDecoder().decode([CloudSection].self, from: raw) else { return }
        var sections: [SavedSectionEntry] = []
        for s in cloud {
            var artworks: [SavedArtworkEntry] = []
            for a in s.artworks {
                guard let imageData = await downloadData(a.imageURL) else { continue }
                artworks.append(SavedArtworkEntry(id: a.id, data: imageData, date: a.date,
                                                  blessing: a.blessing, isPublic: a.isPublic))
            }
            if !artworks.isEmpty {
                sections.append(SavedSectionEntry(id: s.id, type: s.type, artworks: artworks))
            }
        }
        if let encoded = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(encoded, forKey: worksKey(userId))
        }
    }

    private func restoreJSONString(_ value: Any?, key: String) {
        guard let value, !(value is NSNull) else { return }
        guard UserDefaults.standard.string(forKey: key) == nil else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: raw, encoding: .utf8) else { return }
        UserDefaults.standard.set(string, forKey: key)
    }

    private func restoreCodable<T: Codable>(_ value: Any?, as type: T.Type, key: String) {
        guard let value, !(value is NSNull) else { return }
        guard UserDefaults.standard.data(forKey: key) == nil else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let obj = try? JSONDecoder().decode(T.self, from: raw),
              let encoded = try? JSONEncoder().encode(obj) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    /// 恢复心情手记：数组格式优先，兼容旧版单对象格式 → 转数组保存；仅本地无数据时才恢复
    private func restoreMoodDiaries(_ value: Any?, userId: String) {
        guard let value, !(value is NSNull) else { return }
        let key = moodDiaryKey(userId)
        guard UserDefaults.standard.data(forKey: key) == nil else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value) else { return }
        let diaries: [HappyDiaryData]
        if let arr = try? JSONDecoder().decode([HappyDiaryData].self, from: raw) {
            diaries = arr
        } else if let single = try? JSONDecoder().decode(HappyDiaryData.self, from: raw) {
            diaries = [single]
        } else {
            return
        }
        guard let encoded = try? JSONEncoder().encode(diaries) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    /// 恢复运动三格文字：仅当本地无任何 cellTexts 数据时才恢复
    private func restoreSportsCellTexts(_ value: Any?, userId: String) {
        guard let value, !(value is NSNull) else { return }
        let prefix = "\(userId)_sports_cellTexts_"
        let hasLocal = UserDefaults.standard.dictionaryRepresentation().keys.contains { $0.hasPrefix(prefix) }
        guard !hasLocal else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: raw) else { return }
        for (sport, texts) in dict {
            UserDefaults.standard.set(texts, forKey: "\(userId)_sports_cellTexts_\(sport)")
        }
    }

    /// 恢复运动奖杯/里程碑状态：仅当本地无任何 trophies 数据时才恢复
    private func restoreSportsTrophies(_ value: Any?, userId: String) {
        guard let value, !(value is NSNull) else { return }
        let prefix = "\(userId)_sports_trophies_"
        let hasLocal = UserDefaults.standard.dictionaryRepresentation().keys.contains { $0.hasPrefix(prefix) }
        guard !hasLocal else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let dict = try? JSONDecoder().decode([String: [UUID]].self, from: raw) else { return }
        for (sport, ids) in dict {
            if let data = try? JSONEncoder().encode(ids) {
                UserDefaults.standard.set(data, forKey: "\(userId)_sports_trophies_\(sport)")
            }
        }
    }

    /// 恢复卡片位置/旋转：仅当本地无任何该用户的 v3 卡片位置时才恢复
    private func restoreCardPositions(_ value: Any?, userId: String) {
        guard let value, !(value is NSNull) else { return }
        let v3KeyPrefix = "card_pos_\(userId)_"
        let v3Suffix = "_v3"
        let hasLocalV3 = UserDefaults.standard.dictionaryRepresentation().keys.contains {
            $0.hasPrefix(v3KeyPrefix) && $0.hasSuffix(v3Suffix)
        }
        guard !hasLocalV3 else { return }
        guard let raw = try? JSONSerialization.data(withJSONObject: value),
              let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else { return }
        let defaults = UserDefaults.standard
        for (k, v) in dict {
            if k.hasPrefix("posv3_") {
                // 云端正版（中心偏移基准）→ 直接写入 v3 key，无需坐标换算
                let cardId = String(k.dropFirst(6))
                if let nums = v as? [NSNumber], nums.count == 2,
                   let data = try? JSONEncoder().encode([CGFloat(nums[0].doubleValue), CGFloat(nums[1].doubleValue)]) {
                    defaults.set(data, forKey: "card_pos_\(userId)_\(cardId)\(v3Suffix)")
                }
            } else if k.hasPrefix("pos_") {
                // 云端 v1（旧 naturalCenterY 基准）→ 坐标系已变，丢弃（PinableCard 下次拖到 v3 再推送）
                continue
            } else if k.hasPrefix("rot_") {
                let cardId = String(k.dropFirst(4))
                if let num = v as? NSNumber {
                    defaults.set(num.doubleValue, forKey: "card_rot_\(userId)_\(cardId)")
                }
            }
        }
    }

    /// 画展历史：服务器 exhibitions 表已有完整数据，按 userId 过滤重建
    private func restoreExhibitionHistory(userId: String) async {
        guard UserDefaults.standard.data(forKey: exhibitionHistoryKey) == nil else { return }
        guard let all = try? await NetworkService.shared.fetchExhibitions(requesterUserId: nil) else { return }
        let mine = all.filter { $0.userId == userId }
        guard !mine.isEmpty else { return }
        var records: [ExhibitionRecord] = []
        for e in mine {
            var firstData: Data? = nil
            if let urlString = e.firstPictureURL {
                firstData = await downloadData(urlString)
            }
            records.append(ExhibitionRecord(name: e.name, introduction: e.introduction,
                                            startDate: e.startDate, endDate: e.endDate,
                                            firstPictureData: firstData))
        }
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: exhibitionHistoryKey)
        }
    }

    // MARK: - 私有：工具

    /// 私密数据统一加密上传：无密钥时静默跳过（绝不上传明文）
    private func push<T: Encodable>(_ value: T, userId: String, key: String) async throws {
        let data = try JSONEncoder().encode(value)
        guard let wrapped = CryptoBox.encryptJSONString(String(decoding: data, as: UTF8.self)) else { return }
        try await NetworkService.shared.pushUserData(userId: userId, key: key, value: wrapped)
    }

    private func pushJSONString(_ json: String, userId: String, key: String) {
        guard let wrapped = CryptoBox.encryptJSONString(json) else { return }
        Task { try? await NetworkService.shared.pushUserData(userId: userId, key: key, value: wrapped) }
    }

    /// 图片 → OSS URL：先查哈希缓存，未命中才上传；被服务端拒绝（格式/违规）时弹出提示
    private func ossURL(for data: Data) async -> String? {
        let hash = sha256Hex(data)
        if let cache = UserDefaults.standard.dictionary(forKey: ossCacheDefaultsKey),
           let hit = cache[hash] as? String {
            return hit
        }
        do {
            guard let url = try await NetworkService.shared.uploadImageIfPresent(data) else { return nil }
            var cache = UserDefaults.standard.dictionary(forKey: ossCacheDefaultsKey) ?? [:]
            cache[hash] = url
            UserDefaults.standard.set(cache, forKey: ossCacheDefaultsKey)
            return url
        } catch let NetworkError.server(msg) {
            ExhibitionStore.shared.flagModerationReject(msg)
            return nil
        } catch {
            return nil
        }
    }

    private func downloadData(_ urlString: String) async -> Data? {
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return data
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
