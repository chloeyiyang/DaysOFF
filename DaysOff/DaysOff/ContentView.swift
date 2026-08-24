import SwiftUI

enum ModuleTab: Hashable, Identifiable {
    case mood(word: String, isPositive: Bool, presentationID: UUID = UUID())
    case moodHeart(word: String, presentationID: UUID = UUID())
    case travel, sports, gallery, crystal, homeModule

    var id: String {
        switch self {
        case .mood(let word, let isPositive, let pid):
            return "mood_\(word)_\(isPositive)_\(pid.uuidString.prefix(6))"
        case .moodHeart(let word, let pid):
            return "moodHeart_\(word)_\(pid.uuidString.prefix(6))"
        case .travel: return "travel"
        case .sports: return "sports"
        case .gallery: return "gallery"
        case .crystal: return "crystal"
        case .homeModule: return "homeModule"
        }
    }

    var title: String {
        switch self {
        case .mood, .moodHeart: return "心情"
        case .travel: return "旅行"
        case .sports: return "运动"
        case .gallery: return "创作"
        case .crystal: return "水晶"
        case .homeModule: return "首页"
        }
    }

    var icon: String {
        switch self {
        case .mood, .moodHeart: return "heart.fill"
        case .travel: return "airplane"
        case .sports: return "figure.run"
        case .gallery: return "paintpalette.fill"
        case .crystal: return "sparkles"
        case .homeModule: return "house.fill"
        }
    }
}

enum TabDestination: Hashable {
    case home
    case module(ModuleTab)
    case myPage
}

struct ContentView: View {
    let userId: String
    let userName: String

    /// 五个负面心情词——与 HomeModuleView/SilverGrid 保持一致
    static let negativeMoods: Set<String> = ["压抑", "忧虑", "烦躁", "无聊", "不安"]

    @State private var selectedTab: Int = 0  // 默认首页
    @State private var activeModule: ModuleTab?

    // 心情宝石词序：app 启动时打乱一次，切 tab / 进出手记页保持稳定
    // @State 的 initialValue 仅在 view 首次创建时被 SwiftUI 记录一次，后续 init 被忽略
    @State private var moodTexts: [Int: String] = {
        let allMoods = [
            "压抑", "忧虑", "烦躁", "无聊", "不安", "接纳", "轻松", "平静",
            "乐观", "喜悦", "期待", "激动", "惊喜", "满足", "甜蜜", "幸福"
        ]
        let shuffled = allMoods.shuffled()
        var dict: [Int: String] = [:]
        for (i, word) in shuffled.enumerated() {
            dict[i + 1] = word
        }
        return dict
    }()
    /// 恢复/加载本地数据期间置 true，避免触发回推云端
    @State private var suppressSync = false
    @State private var savedDiaries: [HappyDiaryData] = [] {
        didSet {
            guard !suppressSync else { return }
            if savedDiaries.isEmpty {
                UserDefaults.standard.removeObject(forKey: "\(userId)_mood_diary")
            } else if let data = try? JSONEncoder().encode(savedDiaries) {
                UserDefaults.standard.set(data, forKey: "\(userId)_mood_diary")
            }
            UserSyncStore.shared.pushMoodDiaries(userId: userId, diaries: savedDiaries)
        }
    }
    @State private var packedTrips: [PackedTrip] = [] {
        didSet {
            guard !suppressSync else { return }
            if let data = try? JSONEncoder().encode(packedTrips) {
                UserDefaults.standard.set(data, forKey: "\(userId)_packed_trips")
            }
            UserSyncStore.shared.pushPackedTrips(userId: userId, trips: packedTrips)
        }
    }
    @State private var savedEvents: [EventsMatchEntry] = [] {
        didSet {
            guard !suppressSync else { return }
            if let data = try? JSONEncoder().encode(savedEvents) {
                UserDefaults.standard.set(data, forKey: "\(userId)_events_matches")
            }
            UserSyncStore.shared.pushEvents(userId: userId, events: savedEvents)
        }
    }
    @State private var savedExhibitions: [ExhibitionRecord] = []
    @State private var savedMilestones: [MilestoneRecord] = [] {
        didSet {
            guard !suppressSync else { return }
            if let data = try? JSONEncoder().encode(savedMilestones) {
                UserDefaults.standard.set(data, forKey: "\(userId)_milestones")
            }
            UserSyncStore.shared.pushMilestones(userId: userId, milestones: savedMilestones)
        }
    }
    @StateObject private var exhibitionStore = ExhibitionStore.shared

    init(userId: String = "user1", userName: String = "User 1") {
        self.userId = userId
        self.userName = userName
    }

    var body: some View {
        mainTabView
            .networkErrorBanner(show: $exhibitionStore.showNetworkError)
            .onAppear {
                exhibitionStore.startPolling(userId: userId)
                NetworkService.shared.pingActivity(userId: userId)  // 匿名日活上报
                AppStats.currentUserId = userId
                AppStats.setScreen(selectedTab == 0 ? "home" : "mypage")
                CryptoBox.loadKey(userId: userId)  // 已登录会话从 Keychain 载入 E2EE 密钥
                NetworkService.shared.authToken = TokenStore.load(userId: userId)  // 恢复登录令牌
                Task {
                    // 登录后从云端恢复该账号数据（仅补本地缺失），再加载卡片
                    await UserSyncStore.shared.restoreIfNeeded(userId: userId)
                    loadPersistedCards()
                }
            }
            .onDisappear { exhibitionStore.stopPolling() }
            .onReceive(exhibitionStore.$myExhibitions) { savedExhibitions = $0 }
    }

    /// 从 UserDefaults 加载心情手记 / 旅行卡片 / 赛事卡片
    private func loadPersistedCards() {
        suppressSync = true
        defer { suppressSync = false }
        // 兼容旧版：单对象格式 → 新版：数组格式
        if let data = UserDefaults.standard.data(forKey: "\(userId)_mood_diary") {
            if let arr = try? JSONDecoder().decode([HappyDiaryData].self, from: data) {
                savedDiaries = arr
            } else if let single = try? JSONDecoder().decode(HappyDiaryData.self, from: data) {
                savedDiaries = [single]
            }
        }
        if let data = UserDefaults.standard.data(forKey: "\(userId)_packed_trips"),
           let trips = try? JSONDecoder().decode([PackedTrip].self, from: data) {
            packedTrips = trips
        }
        if let data = UserDefaults.standard.data(forKey: "\(userId)_events_matches"),
           let events = try? JSONDecoder().decode([EventsMatchEntry].self, from: data) {
            savedEvents = events
        }
        if let data = UserDefaults.standard.data(forKey: "\(userId)_milestones"),
           let milestones = try? JSONDecoder().decode([MilestoneRecord].self, from: data) {
            savedMilestones = milestones
        }
    }

    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            // Content area
            if selectedTab == 0 {
                HomeModuleView(
                    onClose: { /* HomeModuleView is the tab itself; onClose is a no-op here */ },
                    onLavender: { word in
                        // 紫宝石点击：正面心情 → HappyView 信纸；负面心情 → BrainDeclutterView 信纸
                        let isNegative = ContentView.negativeMoods.contains(word)
                        activeModule = .mood(word: word, isPositive: !isNegative)
                    },
                    onIcecream: {
                        // 冰淇淋 → 旅行 (旅行 button)
                        activeModule = .travel
                    },
                    onBurgundy: {
                        // 勃艮第酒红 → 创作 (画展 / Gallery button)
                        activeModule = .gallery
                    },
                    onOceanBlue: {
                        // 海洋蓝 → 运动 (运动 button)
                        activeModule = .sports
                    },
                    onNegativeMood: { word in
                        // 粉色爱心点击 → 气泡页 → 水晶页
                        activeModule = .moodHeart(word: word)
                    },
                    moodTexts: moodTexts
                )
            } else {
                // tab bar 高度作为底部 inset 传给 MyPageView，让 ScrollView 底部停在 tab bar 上沿
                // 胶囊(52) + 距底(24) = 76
                MyPageView(
                    username: userName,
                    diaries: savedDiaries,
                    trips: packedTrips,
                    events: savedEvents,
                    exhibitions: savedExhibitions,
                    milestones: savedMilestones,
                    bottomInset: 76
                )
                .trackScreen("mypage")
            }

            // Custom compact tab bar: 首页 + 我的 close together
            HStack(spacing: 16) {
                tabButton(index: 0, title: "首页", icon: "house.fill")
                tabButton(index: 1, title: "我的", icon: "person.circle.fill")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color(red: 245/255, green: 245/255, blue: 242/255))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: -2)
            .padding(.bottom, 24)
        }
        .tint(Color(red: 0.55, green: 0.45, blue: 0.75))
        .fullScreenCover(item: $activeModule) { module in
            NavigationStack {
                moduleView(for: module)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            if case .mood = module {
                                // mood (HappyView/BrainDeclutterView) 的 xmark 由 MoodView 内部统一管理
                                EmptyView()
                            } else if case .moodHeart = module {
                                Button(action: { activeModule = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            } else if module != .travel, module != .homeModule {
                                Button(action: { activeModule = nil }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
            }
        }
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(selectedTab == index
                ? Color(red: 0.55, green: 0.45, blue: 0.75)
                : Color(red: 0.55, green: 0.45, blue: 0.75).opacity(0.45))
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func moduleView(for module: ModuleTab) -> some View {
        switch module {
        case .mood(let word, let isPositive, _):
            // 紫宝石点击：正面 → HappyView 信纸；负面 → BrainDeclutterView 信纸
            MoodView(feeling: word, isPositive: isPositive, onEnvelopeSaved: { data in
                savedDiaries.append(data)
                activeModule = nil
                selectedTab = 1
            }, onClose: {
                activeModule = nil
            })
            .trackScreen("mood")
        case .moodHeart(let word, _):
            // 粉色爱心点击 → 气泡页 (FeelingResultView) → 水晶页 (CrystalView)
            MoodView(feeling: word, isPositive: false, isHeartTap: true, onEnvelopeSaved: { _ in }, onClose: {
                activeModule = nil
            })
            .trackScreen("mood-heart")
        case .travel:
            TravelView(username: userName, userId: userId, onTripPacked: { rawTrip in
                // 统计当前用户已有的同目的地卡数量，决定新卡是第几张
                let sameDestCount = packedTrips
                    .filter { $0.destination == rawTrip.destination }
                    .count
                let index = sameDestCount + 1 // 1 = 首卡，2 = 第二，3 = 第三…
                let displayName: String
                if index == 1 {
                    displayName = rawTrip.destination
                } else {
                    displayName = "\(rawTrip.destination)\(index)"
                }
                let trip = PackedTrip(
                    destination: rawTrip.destination,
                    displayName: displayName,
                    duplicateIndex: index,
                    ideas: rawTrip.ideas,
                    startDate: rawTrip.startDate,
                    endDate: rawTrip.endDate,
                    userName: rawTrip.userName
                )
                packedTrips.append(trip)
                activeModule = nil
                selectedTab = 1
            }, onClose: {
                activeModule = nil
            })
            .trackScreen("travel")
        case .sports:
            SportsView(
                userId: userId,
                onEventSaved: { entry in
                    savedEvents.append(entry)
                },
                onSaveAndJumpToMyPage: { entry in
                    // Save if not already saved, then close sports module & jump to 我的 tab
                    if !savedEvents.contains(where: { $0.id == entry.id }) {
                        savedEvents.append(entry)
                    }
                    activeModule = nil
                    selectedTab = 1
                },
                onCreateMilestone: { milestone in
                    savedMilestones.append(milestone)
                }
            )
            .trackScreen("sports")
        case .gallery:
            GalleryView(username: userName, userId: userId, onExhibitionConfirmed: { _ in
                Task { await exhibitionStore.refreshAll(userId: userId) }
            })
            .trackScreen("gallery")
        case .crystal:
            CrystalView(onClose: { activeModule = nil })
                .trackScreen("crystal")
        case .homeModule:
            HomeModuleView(
                onClose: { activeModule = nil },
                onLavender: { word in
                    let isNegative = ContentView.negativeMoods.contains(word)
                    activeModule = .mood(word: word, isPositive: !isNegative)
                },
                onIcecream: {
                    activeModule = .travel
                },
                onBurgundy: {
                    activeModule = .gallery
                },
                onOceanBlue: {
                    activeModule = .sports
                },
                onNegativeMood: { word in
                    activeModule = .moodHeart(word: word)
                },
                moodTexts: moodTexts
            )
        }
    }
}
