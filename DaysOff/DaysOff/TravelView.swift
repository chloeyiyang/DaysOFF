import SwiftUI

private extension Color {
    static let tripNavy = Color(red: 0.0, green: 0.0, blue: 0.3)
    static let tripPeach = Color(red: 0.96, green: 0.85, blue: 0.78)
    static let tripMintGreen = Color(red: 0.82, green: 0.92, blue: 0.82)
    static let tripPostItYellow = Color(red: 0.98, green: 0.94, blue: 0.78)
    static let tripPostItWhite = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let tripTextBrown = Color(red: 0.45, green: 0.35, blue: 0.30)
    static let tripMatchPink = Color(red: 0.92, green: 0.70, blue: 0.78)
}

// MARK: - 与漩涡气泡页同款 aurora 背景 + 白色十字/四角星光点
private struct WhippedCreamMintBackground: View {
    @State private var sparklePhase: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let phase = sparklePhase

            ZStack {
                // 1. 冷调牛奶白基底（与漩涡气泡页 auroraBackground 一致）
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 1.0),
                        Color(red: 0.97, green: 0.98, blue: 1.0),
                        Color(red: 0.98, green: 0.97, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 2. 左上粉色不规则色斑
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.80, blue: 0.88).opacity(0.85),
                        Color(red: 0.96, green: 0.70, blue: 0.82).opacity(0.45),
                        .clear
                    ],
                    center: UnitPoint(x: 0.15 + sin(phase) * 0.05,
                                      y: 0.20 + cos(phase * 0.8) * 0.05),
                    startRadius: 20,
                    endRadius: w * 0.60
                )
                .blur(radius: 55)
                .ignoresSafeArea()

                // 3. 右上薄荷绿不规则色斑
                RadialGradient(
                    colors: [
                        Color(red: 0.75, green: 0.95, blue: 0.85).opacity(0.80),
                        Color(red: 0.65, green: 0.90, blue: 0.78).opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.85 + sin(phase * 0.9 + 0.5) * 0.06,
                                      y: 0.18 + cos(phase * 1.1) * 0.05),
                    startRadius: 20,
                    endRadius: w * 0.55
                )
                .blur(radius: 60)
                .ignoresSafeArea()

                // 4. 中间天蓝色不规则色斑
                RadialGradient(
                    colors: [
                        Color(red: 0.75, green: 0.88, blue: 0.98).opacity(0.80),
                        Color(red: 0.60, green: 0.80, blue: 0.95).opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50 + sin(phase * 1.2) * 0.07,
                                      y: 0.50 + cos(phase * 0.7) * 0.06),
                    startRadius: 20,
                    endRadius: w * 0.65
                )
                .blur(radius: 65)
                .ignoresSafeArea()

                // 5. 底部梦幻紫不规则色斑
                RadialGradient(
                    colors: [
                        Color(red: 0.85, green: 0.78, blue: 0.96).opacity(0.78),
                        Color(red: 0.75, green: 0.68, blue: 0.92).opacity(0.38),
                        .clear
                    ],
                    center: UnitPoint(x: 0.40 + sin(phase * 0.6 + 0.8) * 0.06,
                                      y: 0.82 + cos(phase * 1.0) * 0.05),
                    startRadius: 20,
                    endRadius: w * 0.60
                )
                .blur(radius: 60)
                .ignoresSafeArea()

                // 6. 60 颗白色微尘闪烁（与 auroraBackground 同款）
                Canvas { context, size in
                    for i in 0..<60 {
                        let s = Double(i)
                        let x = sin(s * 130.3) * 0.5 + 0.5
                        let y = cos(s * 271.9) * 0.5 + 0.5
                        let r = CGFloat(0.8 + sin(s * 31.7) * 0.7)
                        let opacity = 0.25 + sin(s * 53.2 + phase * 1.4) * 0.18
                        let pt = CGPoint(x: x * size.width, y: y * size.height)
                        context.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r,
                                                            width: r * 2, height: r * 2)),
                                     with: .color(Color.white.opacity(Double(opacity))))
                    }
                }
                .ignoresSafeArea()

                // 7. 保留：24 颗白色十字/四角星随机舞动光点
                Canvas { context, size in
                    // 星点参数：(seed, yRatio, isStar, speed)
                    // isStar: 0 = 十字, 1 = 四角星
                    let sunSpots: [(Double, Double, Double, Double)] = [
                        (12.7,  0.25, 0, 1.0),
                        (47.3,  0.32, 1, 0.8),
                        (83.1,  0.28, 0, 1.2),
                        (29.5,  0.40, 1, 0.9),
                        (64.8,  0.38, 0, 1.1),
                        (5.2,   0.45, 1, 1.3),
                        (91.6,  0.48, 0, 0.7),
                        (38.9,  0.52, 1, 1.0),
                        (76.4,  0.55, 0, 0.85),
                        (19.1,  0.60, 1, 1.15),
                        (54.7,  0.63, 0, 0.95),
                        (88.2,  0.66, 1, 1.05),
                        (25.8,  0.70, 0, 0.9),
                        (61.3,  0.74, 1, 1.0),
                        (9.4,   0.78, 0, 1.1),
                        (43.7,  0.82, 1, 0.8),
                        (78.9,  0.85, 0, 1.2),
                        (33.2,  0.88, 1, 0.95),
                        (67.1,  0.30, 0, 1.1),
                        (15.8,  0.50, 1, 0.9),
                        (52.4,  0.58, 0, 1.0),
                        (95.3,  0.72, 1, 0.85),
                        (7.6,   0.65, 0, 1.15),
                        (40.2,  0.80, 1, 0.95)
                    ]

                    let width: Double = Double(size.width)
                    let height: Double = Double(size.height)

                    for spot in sunSpots {
                        let seed: Double = spot.0
                        let yRatio: Double = spot.1
                        let isStar: Bool = spot.2 > 0.5
                        let speed: Double = spot.3

                        // 轻微漂移
                        let driftX: Double = sin(phase * speed + seed) * 6.0
                        let driftY: Double = cos(phase * speed * 0.7 + seed * 1.3) * 4.0
                        let cx: Double = (seed / 100.0) * width + driftX
                        let cy: Double = yRatio * height + driftY

                        // 闪烁
                        let twinkle: Double = (sin(phase * 2.5 + seed * 3.1) + 1.0) * 0.5
                        let opacity: Double = 0.3 + twinkle * 0.6
                        let sz: Double = 3.0 + twinkle * 2.5

                        // 中心亮点
                        let center = CGPoint(x: cx, y: cy)
                        let dotRect = CGRect(x: cx - 0.8, y: cy - 0.8, width: 1.6, height: 1.6)
                        context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(opacity)))

                        if isStar {
                            // 四角星：两条短线交叉 + 对角线
                            var hLine = Path()
                            hLine.move(to: CGPoint(x: cx - sz, y: cy))
                            hLine.addLine(to: CGPoint(x: cx + sz, y: cy))
                            context.stroke(hLine, with: .color(Color.white.opacity(opacity * 0.85)), lineWidth: 0.8)

                            var vLine = Path()
                            vLine.move(to: CGPoint(x: cx, y: cy - sz))
                            vLine.addLine(to: CGPoint(x: cx, y: cy + sz))
                            context.stroke(vLine, with: .color(Color.white.opacity(opacity * 0.85)), lineWidth: 0.8)

                            let d: Double = sz * 0.5
                            var d1 = Path()
                            d1.move(to: CGPoint(x: cx - d, y: cy - d))
                            d1.addLine(to: CGPoint(x: cx + d, y: cy + d))
                            context.stroke(d1, with: .color(Color.white.opacity(opacity * 0.4)), lineWidth: 0.5)

                            var d2 = Path()
                            d2.move(to: CGPoint(x: cx - d, y: cy + d))
                            d2.addLine(to: CGPoint(x: cx + d, y: cy - d))
                            context.stroke(d2, with: .color(Color.white.opacity(opacity * 0.4)), lineWidth: 0.5)
                        } else {
                            // 细十字
                            var hLine = Path()
                            hLine.move(to: CGPoint(x: cx - sz, y: cy))
                            hLine.addLine(to: CGPoint(x: cx + sz, y: cy))
                            context.stroke(hLine, with: .color(Color.white.opacity(opacity * 0.8)), lineWidth: 0.7)

                            var vLine = Path()
                            vLine.move(to: CGPoint(x: cx, y: cy - sz))
                            vLine.addLine(to: CGPoint(x: cx, y: cy + sz))
                            context.stroke(vLine, with: .color(Color.white.opacity(opacity * 0.8)), lineWidth: 0.7)
                        }
                        _ = center
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            // 与漩涡气泡页同样的 5.5s 往复循环动画，保持跨页面视觉统一
            withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: true)) {
                sparklePhase = .pi * 2
            }
        }
    }
}

struct TravelView: View {
    let username: String
    let userId: String
    let onTripPacked: (PackedTrip) -> Void
    let onClose: () -> Void

    var body: some View {
        MatchView(username: username, userId: userId, onTripPacked: onTripPacked, onClose: onClose)
    }
}

struct MatchUser: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let color: Color
    var ideas: [TravelIdea]
}

struct TravelIdea: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let content: String
    let destination: String
    let landmark: String
    let date: String
    var startDate: Date?
    var endDate: Date?
}

struct MatchInfo: Identifiable, Equatable {
    let id = UUID()
    let landmark: String
    let matchedUserName: String
}

struct DeleteConfirmation: Identifiable {
    let id = UUID()
    let ideaId: UUID
    let destination: String
}

struct PackedTrip: Identifiable, Equatable, Codable {
    let id = UUID()
    let destination: String
    /// 展示名称：首卡 = 东京，第二卡 = 东京(2)，第三卡 = 东京(3) …
    var displayName: String
    /// 同目的地的第几张卡：1 首卡，2 第二卡，3 第三卡…
    var duplicateIndex: Int
    /// 非 nil 时覆盖卡片底色（用于偶数张卡：桑椹 + 云母 + 桑椹三色渐变，白字）
    var duplicateCardColors: (top: Color, mid: Color, bottom: Color, text: Color)? {
        guard duplicateIndex > 1 else { return nil }
        if duplicateIndex % 2 == 0 {
            // 2nd, 4th, 6th...: mulberry → yunmu → mulberry triple ombre, white text
            return (
                Color(red: 197/255, green: 75/255, blue: 140/255),
                Color(red: 198/255, green: 190/255, blue: 177/255),
                Color(red: 197/255, green: 75/255, blue: 140/255),
                .white
            )
        } else {
            // 3rd, 5th, 7th...: revert to default card style (same as 1st)
            return nil
        }
    }
    let ideas: [TravelIdea]
    let startDate: Date?
    let endDate: Date?
    let userName: String

    enum CodingKeys: String, CodingKey {
        case destination, displayName, duplicateIndex, ideas, startDate, endDate, userName
    }

    init(destination: String,
         displayName: String? = nil,
         duplicateIndex: Int = 1,
         ideas: [TravelIdea],
         startDate: Date? = nil,
         endDate: Date? = nil,
         userName: String) {
        self.destination = destination
        self.displayName = displayName ?? destination
        self.duplicateIndex = duplicateIndex
        self.ideas = ideas
        self.startDate = startDate
        self.endDate = endDate
        self.userName = userName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        destination = try container.decode(String.self, forKey: .destination)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? destination
        duplicateIndex = try container.decodeIfPresent(Int.self, forKey: .duplicateIndex) ?? 1
        ideas = try container.decode([TravelIdea].self, forKey: .ideas)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        userName = try container.decode(String.self, forKey: .userName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(destination, forKey: .destination)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(duplicateIndex, forKey: .duplicateIndex)
        try container.encode(ideas, forKey: .ideas)
        try container.encodeIfPresent(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(userName, forKey: .userName)
    }

    static func == (lhs: PackedTrip, rhs: PackedTrip) -> Bool { lhs.id == rhs.id }
}

struct MatchView: View {
    let username: String
    let userId: String
    let onTripPacked: (PackedTrip) -> Void
    let onClose: () -> Void
    @State private var users = [MatchUser]()
    @State private var showInput = false
    @State private var userInput = ""
    @State private var showTemplate = false
    @State private var templateCity = ""
    @State private var templateAction = ""
    @State private var selectedIdea: TravelIdea?
    @State private var showMatches = false
    @State private var expandedDestinations = Set<String>()
    @State private var deleteConfirmation: DeleteConfirmation?
    @State private var showDepartPopup = false
    @StateObject private var ideasStore = TravelIdeasStore()

    // 自动保存草稿
    @AppStorage("travel_draft_userInput") private var draftUserInput = ""
    @AppStorage("travel_draft_templateCity") private var draftTemplateCity = ""
    @AppStorage("travel_draft_templateAction") private var draftTemplateAction = ""
    @AppStorage("travel_draft_showTemplate") private var draftShowTemplate = false

    private var currentUserIndex: Int { 0 }

    init(username: String, userId: String, onTripPacked: @escaping (PackedTrip) -> Void, onClose: @escaping () -> Void) {
        self.username = username
        self.userId = userId
        self.onTripPacked = onTripPacked
        self.onClose = onClose
        // 从 UserDefaults 加载已保存的灵感
        let loadedIdeas = Self.loadIdeas(userId: userId)
        self._users = State(initialValue: [MatchUser(name: username, color: .tripPeach, ideas: loadedIdeas)])
    }

    private static func ideasKey(userId: String) -> String {
        "travel_saved_ideas_\(userId)"
    }

    private static func loadIdeas(userId: String) -> [TravelIdea] {
        guard let data = UserDefaults.standard.data(forKey: ideasKey(userId: userId)) else { return [] }
        return (try? JSONDecoder().decode([TravelIdea].self, from: data)) ?? []
    }

    private func persistIdeas() {
        let ideas = users[currentUserIndex].ideas
        if let data = try? JSONEncoder().encode(ideas) {
            UserDefaults.standard.set(data, forKey: Self.ideasKey(userId: userId))
        }
        // 同步到服务器，让其他用户能看到我的灵感
        syncIdeasToNetwork()
    }

    // MARK: - Network Sync

    private func syncIdeasToNetwork() {
        let ideas = users[currentUserIndex].ideas
        Task { await ideasStore.sync(userId: userId, userName: username, ideas: ideas) }
    }

    private func startIdeaPolling() {
        ideasStore.startPolling(userId: userId, userName: username) {
            self.users[self.currentUserIndex].ideas
        }
    }

    private func stopIdeaPolling() {
        ideasStore.stopPolling()
    }
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private var matchedLandmarks: [MatchInfo] {
        guard !ideasStore.networkUsers.isEmpty else { return [] }
        var matches: [MatchInfo] = []
        let currentUserIdeas = users[currentUserIndex].ideas

        for otherUser in ideasStore.networkUsers {
            let otherUserName = otherUser.name
            let otherUserIdeas = otherUser.ideas

            for currentIdea in currentUserIdeas {
                if currentIdea.destination == "未知目的地" { continue }
                for otherIdea in otherUserIdeas {
                    if currentIdea.destination == otherIdea.destination {
                        if isDateRangeMatched(
                            start1: currentIdea.startDate, end1: currentIdea.endDate,
                            start2: otherIdea.startDate, end2: otherIdea.endDate
                        ) {
                            let displayName = currentIdea.landmark
                            if !matches.contains(where: { $0.landmark == displayName && $0.matchedUserName == otherUserName }) {
                                matches.append(MatchInfo(landmark: displayName, matchedUserName: otherUserName))
                            }
                        }
                    }
                }
            }
        }
        return matches.sorted { $0.landmark < $1.landmark }
    }
    
    private func isDateRangeMatched(start1: Date?, end1: Date?, start2: Date?, end2: Date?) -> Bool {
        if start1 == nil || start2 == nil {
            return true
        }
        guard let s1 = start1, let s2 = start2 else { return false }
        let e1 = end1 ?? Calendar.current.date(byAdding: .day, value: 1, to: s1) ?? s1
        let e2 = end2 ?? Calendar.current.date(byAdding: .day, value: 1, to: s2) ?? s2
        return s1 <= e2 && s2 <= e1
    }
    
    var body: some View {
        ZStack {
            WhippedCreamMintBackground()
            
            VStack(spacing: 16) {
                userSwitcher
                
                if showMatches { matchesView }
                
                mainContentView
            }
            .padding()
            
            if let idea = selectedIdea {
                ideaDetailView(idea: idea)
            }
            
            if let confirm = deleteConfirmation {
                deleteConfirmView(confirm: confirm)
            }
            
            if showDepartPopup {
                departPopupView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentUserIndex)
        .animation(.easeInOut(duration: 0.3), value: showInput)
        .animation(.easeInOut(duration: 0.3), value: showMatches)
        .animation(.easeInOut(duration: 0.3), value: showTemplate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if showInput {
                        showInput = false
                    } else {
                        onClose()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
        }
        .networkErrorBanner(show: $ideasStore.showNetworkError)
        .onAppear {
            // 加载草稿
            userInput = draftUserInput
            templateCity = draftTemplateCity
            templateAction = draftTemplateAction
            showTemplate = draftShowTemplate
            // 启动网络轮询，拉取其他用户的旅行灵感
            startIdeaPolling()
        }
        .onDisappear {
            stopIdeaPolling()
        }
        .onChange(of: userInput) { newValue in
            draftUserInput = newValue
        }
        .onChange(of: templateCity) { newValue in
            draftTemplateCity = newValue
        }
        .onChange(of: templateAction) { newValue in
            draftTemplateAction = newValue
        }
        .onChange(of: showTemplate) { newValue in
            draftShowTemplate = newValue
        }
    }
    
    private var userSwitcher: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(users[0].color)
                    .frame(width: 12, height: 12)
                Text(username)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.tripTextBrown)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.8))
            .cornerRadius(20)

            Spacer()

            if matchedLandmarks.count > 0 {
                Button(action: { showMatches.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.tripMatchPink)
                        Text("匹配: \(matchedLandmarks.count)")
                            .font(.subheadline)
                            .foregroundColor(.tripTextBrown)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(16)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private var matchesView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🎉 共同想去的地方")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.tripTextBrown)
                Spacer()
                Button(action: { showMatches = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.tripTextBrown.opacity(0.6))
                }
            }

            VStack(spacing: 8) {
                ForEach(matchedLandmarks) { match in
                    HStack(spacing: 8) {
                        Text(match.landmark)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.tripMatchPink)
                            .cornerRadius(20)
                        Text("与 \(match.matchedUserName)")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 固定区域：按钮始终可见
            VStack(spacing: 12) {
                Button(action: {
                    showInput.toggle()
                }) {
                    Text("新的旅行灵感")
                        .font(.pingFang(size: 18, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 255/255, green: 240/255, blue: 242/255),
                                            Color(red: 255/255, green: 248/255, blue: 228/255),
                                            Color(red: 244/255, green: 252/255, blue: 238/255),
                                            Color(red: 226/255, green: 244/255, blue: 230/255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if showInput {
                    inputView
                }

                if users[currentUserIndex].ideas.filter({ $0.destination != "未知目的地" }).count > 0 {
                    Button(action: { showDepartPopup = true }) {
                        Text("准备出发")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0.95, green: 0.94, blue: 0.96))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 36)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.05, green: 0.12, blue: 0.35).opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 12)

            // 滚动区域：仅目的地列表滚动
            ScrollView(.vertical, showsIndicators: false) {
                if users[currentUserIndex].ideas.count > 0 {
                    destinationsView
                        .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var departPopupView: some View {
        let dests = sortedDestinations().filter { $0.destination != "未知目的地" }
        
        return ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { showDepartPopup = false }
            
            VStack(spacing: 16) {
                Text("选择目的地")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.tripTextBrown)
                    .padding(.top, 16)
                
                Text("已准备好去...")
                    .font(.system(size: 14))
                    .foregroundColor(.tripTextBrown.opacity(0.7))
                
                VStack(spacing: 10) {
                    ForEach(dests, id: \.destination) { destInfo in
                        Button(action: {
                            packTrip(destination: destInfo.destination, ideas: destInfo.ideas)
                            showDepartPopup = false
                        }) {
                            HStack {
                                Text(destInfo.destination)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.tripTextBrown)
                                
                                Spacer()
                                
                                Text("\(destInfo.ideas.count) 个灵感")
                                    .font(.system(size: 12))
                                    .foregroundColor(.tripTextBrown.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.tripPostItYellow.opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Button(action: { showDepartPopup = false }) {
                    Text("取消")
                        .font(.system(size: 14))
                        .foregroundColor(.tripTextBrown.opacity(0.6))
                }
                .padding(.bottom, 16)
            }
            .frame(width: 320)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 4)
        }
        .transition(.opacity)
    }
    
    private func packTrip(destination: String, ideas: [TravelIdea]) {
        let startDate = ideas.compactMap { $0.startDate }.min()
        let endDate = ideas.compactMap { $0.endDate }.max()
        let user = users[currentUserIndex]
        
        let trip = PackedTrip(
            destination: destination,
            ideas: ideas,
            startDate: startDate,
            endDate: endDate,
            userName: user.name
        )
        
        users[currentUserIndex].ideas.removeAll { $0.destination == destination }
        expandedDestinations.remove(destination)
        persistIdeas()

        onTripPacked(trip)
    }
    
    private var destinationsView: some View {
        let dests = sortedDestinations().filter { $0.destination != "未知目的地" }

        return VStack(spacing: 16) {
            ForEach(dests, id: \.destination) { destInfo in
                destinationGroupView(destination: destInfo.destination, ideas: destInfo.ideas)
            }
        }
        .padding(.horizontal, 4)
    }
    
    private struct DestinationInfo {
        let destination: String
        let ideas: [TravelIdea]
    }
    
    private func sortedDestinations() -> [DestinationInfo] {
        let allIdeas = users[currentUserIndex].ideas
        let grouped = Dictionary(grouping: allIdeas, by: { $0.destination })
        return grouped.map { (dest, ideas) in
            DestinationInfo(destination: dest, ideas: ideas.sorted { $0.title < $1.title })
        }.sorted { d1, d2 in
            // 按添加顺序排序：以该目的地首条灵感在数组中的位置为准
            let idx1 = allIdeas.firstIndex(where: { $0.destination == d1.destination }) ?? 0
            let idx2 = allIdeas.firstIndex(where: { $0.destination == d2.destination }) ?? 0
            return idx1 < idx2
        }
    }
    
    private func destinationGroupView(destination: String, ideas: [TravelIdea]) -> some View {
        let isExpanded = expandedDestinations.contains(destination)
        let matchedLandmarkNames = Set(matchedLandmarks.map { $0.landmark })
        let destHasMatch = destination != "未知目的地" && ideas.contains(where: { matchedLandmarkNames.contains($0.landmark) })
        let isUnknown = destination == "未知目的地"

        return VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if isUnknown {
                    TextField("输入目的地", text: Binding(
                        get: { "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                renameDestination(from: destination, to: trimmed)
                            }
                        }
                    ))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.tripTextBrown)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.tripPostItWhite)
                    .cornerRadius(4)
                } else {
                    Text(destination)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.tripTextBrown)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.tripPostItWhite)
                        .cornerRadius(4)
                }

                if destHasMatch {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.tripMatchPink)
                        .font(.caption)
                        .offset(x: 6, y: -6)
                }
            }

            MatchDatePickerRowView(
                isExpanded: isExpanded,
                startDate: Binding(
                    get: { ideas.compactMap { $0.startDate }.first ?? today },
                    set: { newValue in
                        updateDate(for: destination, startDate: newValue, endDate: nil)
                    }
                ),
                endDate: Binding(
                    get: { ideas.compactMap { $0.endDate }.first ?? Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today },
                    set: { newValue in
                        updateDate(for: destination, startDate: nil, endDate: newValue)
                    }
                ),
                today: today,
                onToggle: {
                    if isExpanded {
                        clearDates(for: destination)
                        expandedDestinations.remove(destination)
                    } else {
                        setDefaultDates(for: destination)
                        expandedDestinations.insert(destination)
                    }
                }
            )

            VStack(spacing: 10) {
                ForEach(ideas) { idea in
                    ZStack(alignment: .topTrailing) {
                        Button(action: { selectedIdea = idea }) {
                            HStack(spacing: 8) {
                                Text(ideaShortTitle(idea))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.tripTextBrown)
                                    .lineLimit(1)

                                Text(truncatedContent(idea.content))
                                    .font(.system(size: 16))
                                    .foregroundColor(.tripTextBrown.opacity(0.7))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.tripPostItWhite)
                            .cornerRadius(4)
                        }

                        Button(action: {
                            deleteConfirmation = DeleteConfirmation(ideaId: idea.id, destination: destination)
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.tripTextBrown.opacity(0.4))
                                .font(.caption)
                                .offset(x: -4, y: -4)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.tripPostItWhite.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.tripTextBrown.opacity(0.3), lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    /// Extract "旅行灵感N" from title like "旅行灵感1 - 镰仓"
    private func ideaShortTitle(_ idea: TravelIdea) -> String {
        if let dashRange = idea.title.range(of: " - ") {
            return String(idea.title[..<dashRange.lowerBound])
        }
        return idea.title
    }

    /// Truncate content to max 20 characters
    private func truncatedContent(_ content: String) -> String {
        if content.count > 20 {
            return String(content.prefix(20)) + "…"
        }
        return content
    }
    
    private var inputView: some View {
        VStack(spacing: 16) {
            Group {
                if showTemplate {
                    HStack(spacing: 4) {
                        Text("我想去")
                            .font(.system(size: 18))
                            .foregroundColor(.tripTextBrown)

                        TextField("城市名", text: $templateCity)
                            .font(.system(size: 18))
                            .foregroundColor(.tripTextBrown)
                            .frame(width: 70)

                        TextField("干什么", text: $templateAction)
                            .font(.system(size: 18))
                            .foregroundColor(.tripTextBrown)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .frame(height: 200, alignment: .top)
                } else {
                    TextEditor(text: $userInput)
                        .scrollContentBackground(.hidden)
                        .frame(height: 200)
                        .font(.system(size: 18))
                        .foregroundColor(.tripTextBrown)
                        .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            Button(action: {
                if showTemplate {
                    saveTemplateIdea()
                    showInput = false
                    showTemplate = false
                } else {
                    let (destination, _) = detectDestinationAndLandmark(from: userInput)
                    if destination == "未知目的地" {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showTemplate = true
                        }
                    } else {
                        saveTravelIdea()
                        showInput = false
                    }
                }
            }) {
                Text("确定")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.tripTextBrown)
                    .cornerRadius(4)
            }
            .disabled(currentInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(currentInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
        .onAppear {
            // 进入输入页时加载草稿
            userInput = draftUserInput
            templateCity = draftTemplateCity
            templateAction = draftTemplateAction
            showTemplate = draftShowTemplate
        }
        .onDisappear {
            // 离开输入页时强制保存草稿
            draftUserInput = userInput
            draftTemplateCity = templateCity
            draftTemplateAction = templateAction
            draftShowTemplate = showTemplate
        }
    }

    private var currentInputText: String {
        showTemplate ? templateCity + templateAction : userInput
    }

    private func saveTemplateIdea() {
        let city = templateCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let action = templateAction.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !city.isEmpty else { return }

        let content = "我想去\(city)\(action)"
        let destination = city
        let landmark = city

        let existing = users[currentUserIndex].ideas.filter { $0.destination == destination }

        let newIdea = TravelIdea(
            id: UUID(),
            title: "旅行灵感\(existing.count + 1) - \(destination)",
            content: content,
            destination: destination,
            landmark: landmark,
            date: currentDate
        )

        users[currentUserIndex].ideas.append(newIdea)
        expandedDestinations.remove(destination)
        persistIdeas()

        templateCity = ""
        templateAction = ""
        draftTemplateCity = ""
        draftTemplateAction = ""
        draftShowTemplate = false
    }
    
    private func ideaDetailView(idea: TravelIdea) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { selectedIdea = nil }
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { selectedIdea = nil }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.tripTextBrown.opacity(0.6))
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Text(idea.date)
                    .font(.system(size: 12))
                    .foregroundColor(.tripTextBrown.opacity(0.5))
                    .padding(.bottom, 8)
                
                Text(idea.content)
                    .font(.system(size: 22))
                    .foregroundColor(.tripTextBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
            .frame(width: 320)
            .background(Color.tripPostItWhite)
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 4)
        }
    }
    
    private func deleteConfirmView(confirm: DeleteConfirmation) -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { deleteConfirmation = nil }
            
            VStack(spacing: 16) {
                Text("确定要删除吗？")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.tripTextBrown)
                
                HStack(spacing: 24) {
                    Button(action: { deleteConfirmation = nil }) {
                        Text("否")
                            .font(.system(size: 14))
                            .foregroundColor(.tripTextBrown.opacity(0.7))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.tripPostItWhite)
                            .cornerRadius(4)
                    }
                    
                    Button(action: {
                        deleteIdea(ideaId: confirm.ideaId)
                        deleteConfirmation = nil
                    }) {
                        Text("是")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.tripTextBrown)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 4, y: 4)
        }
    }
    
    private func saveTravelIdea() {
        let (destination, landmark) = detectDestinationAndLandmark(from: userInput)
        let existing = users[currentUserIndex].ideas.filter { $0.destination == destination }

        let newIdea = TravelIdea(
            id: UUID(),
            title: "旅行灵感\(existing.count + 1) - \(destination)",
            content: userInput,
            destination: destination,
            landmark: landmark,
            date: currentDate
        )

        users[currentUserIndex].ideas.append(newIdea)
        expandedDestinations.remove(destination)
        persistIdeas()

        userInput = ""
        draftUserInput = ""
    }
    
    private func deleteIdea(ideaId: UUID) {
        let removedIdea = users[currentUserIndex].ideas.first(where: { $0.id == ideaId })
        let removedDestination = removedIdea?.destination

        users[currentUserIndex].ideas.removeAll { $0.id == ideaId }

        if let dest = removedDestination {
            renumberIdeas(for: dest)
        }

        let grouped = Dictionary(grouping: users[currentUserIndex].ideas, by: { $0.destination })
        for dest in expandedDestinations {
            if grouped[dest]?.isEmpty ?? true {
                expandedDestinations.remove(dest)
            }
        }
        persistIdeas()
    }
    
    private func renumberIdeas(for destination: String) {
        let destIdeas = users[currentUserIndex].ideas.filter { $0.destination == destination }
            .sorted { $0.title < $1.title }
        
        var updates: [(index: Int, newTitle: String)] = []
        for (number, idea) in destIdeas.enumerated() {
            let newTitle = "旅行灵感\(number + 1) - \(destination)"
            if idea.title != newTitle {
                if let idx = users[currentUserIndex].ideas.firstIndex(where: { $0.id == idea.id }) {
                    updates.append((idx, newTitle))
                }
            }
        }
        
        for (idx, newTitle) in updates {
            let original = users[currentUserIndex].ideas[idx]
            users[currentUserIndex].ideas[idx] = TravelIdea(
                id: original.id,
                title: newTitle,
                content: original.content,
                destination: original.destination,
                landmark: original.landmark,
                date: original.date,
                startDate: original.startDate,
                endDate: original.endDate
            )
        }
    }
    
    private func updateDate(for destination: String, startDate: Date?, endDate: Date?) {
        for i in 0..<users[currentUserIndex].ideas.count {
            if users[currentUserIndex].ideas[i].destination == destination {
                if let start = startDate {
                    users[currentUserIndex].ideas[i].startDate = start
                }
                if let end = endDate {
                    users[currentUserIndex].ideas[i].endDate = end
                }
            }
        }
        persistIdeas()
    }

    private func setDefaultDates(for destination: String) {
        let start = today
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        for i in 0..<users[currentUserIndex].ideas.count {
            if users[currentUserIndex].ideas[i].destination == destination {
                if users[currentUserIndex].ideas[i].startDate == nil {
                    users[currentUserIndex].ideas[i].startDate = start
                }
                if users[currentUserIndex].ideas[i].endDate == nil {
                    users[currentUserIndex].ideas[i].endDate = end
                }
            }
        }
        persistIdeas()
    }

    private func clearDates(for destination: String) {
        for i in 0..<users[currentUserIndex].ideas.count {
            if users[currentUserIndex].ideas[i].destination == destination {
                users[currentUserIndex].ideas[i].startDate = nil
                users[currentUserIndex].ideas[i].endDate = nil
            }
        }
        persistIdeas()
    }
    
    private func renameDestination(from oldName: String, to newName: String) {
        let existingCount = users[currentUserIndex].ideas.filter { $0.destination == newName }.count
        var counter = existingCount
        
        for i in 0..<users[currentUserIndex].ideas.count {
            if users[currentUserIndex].ideas[i].destination == oldName {
                counter += 1
                let newTitle = "旅行灵感\(counter) - \(newName)"
                let original = users[currentUserIndex].ideas[i]
                users[currentUserIndex].ideas[i] = TravelIdea(
                    id: original.id,
                    title: newTitle,
                    content: original.content,
                    destination: newName,
                    landmark: original.landmark == "未知目的地" ? newName : original.landmark,
                    date: original.date,
                    startDate: original.startDate,
                    endDate: original.endDate
                )
            }
        }
        
        if expandedDestinations.contains(oldName) {
            expandedDestinations.remove(oldName)
            expandedDestinations.insert(newName)
        } else {
            expandedDestinations.remove(newName)
        }
        persistIdeas()
    }
    
    private func detectDestinationAndLandmark(from text: String) -> (destination: String, landmark: String) {
        let cityNames: [String: String] = [
            "北京": "北京", "西安": "西安", "杭州": "杭州",
            "上海": "上海", "香港": "香港", "东京": "东京",
            "大阪": "大阪", "京都": "京都", "北海道": "北海道",
            "新加坡": "新加坡", "曼谷": "曼谷", "首尔": "首尔",
            "巴黎": "巴黎", "伦敦": "伦敦", "罗马": "罗马",
            "威尼斯": "威尼斯", "巴塞罗那": "巴塞罗那",
            "阿姆斯特丹": "阿姆斯特丹", "柏林": "柏林",
            "维也纳": "维也纳", "青岛": "青岛",
            "厦门": "厦门", "丽江": "丽江", "三亚": "三亚",
            "桂林": "桂林", "南京": "南京", "成都": "成都",
            "重庆": "重庆", "武汉": "武汉", "广州": "广州",
            "深圳": "深圳", "天津": "天津", "苏州": "苏州",
            "无锡": "无锡", "宁波": "宁波", "长沙": "长沙",
            "郑州": "郑州", "合肥": "合肥", "福州": "福州",
            "昆明": "昆明", "贵阳": "贵阳", "南宁": "南宁",
            "哈尔滨": "哈尔滨", "长春": "长春", "沈阳": "沈阳",
            "大连": "大连", "烟台": "烟台", "瑞士": "瑞士"
        ]
        
        for (city, dest) in cityNames {
            if text.contains(city) {
                return (dest, city)
            }
        }
        
        let landmarks: [String: (destination: String, displayName: String)] = [
            "长城": ("北京", "长城"),
            "故宫": ("北京", "故宫"),
            "紫禁城": ("北京", "故宫"),
            "天安门": ("北京", "天安门"),
            "香山": ("北京", "香山"),
            "天坛": ("北京", "天坛"),
            "环球影城": ("北京", "北京环球影城"),
            "兵马俑": ("西安", "兵马俑"),
            "大雁塔": ("西安", "大雁塔"),
            "城墙": ("西安", "西安城墙"),
            "西湖": ("杭州", "西湖"),
            "灵隐寺": ("杭州", "灵隐寺"),
            "雷峰塔": ("杭州", "雷峰塔"),
            "外滩": ("上海", "外滩"),
            "东方明珠": ("上海", "东方明珠"),
            "陆家嘴": ("上海", "陆家嘴"),
            "维多利亚港": ("香港", "维多利亚港"),
            "迪士尼": ("香港", "香港迪士尼"),
            "海洋公园": ("香港", "海洋公园"),
            "太平山": ("香港", "太平山"),
            "旺角": ("香港", "旺角"),
            "铜锣湾": ("香港", "铜锣湾"),
            "富士山": ("东京", "富士山"),
            "樱花": ("东京", "东京樱花"),
            "秋叶原": ("东京", "秋叶原"),
            "巴厘岛": ("巴厘岛", "巴厘岛"),
            "普吉岛": ("普吉岛", "普吉岛"),
            "吉隆坡": ("吉隆坡", "吉隆坡"),
            "马尼拉": ("马尼拉", "马尼拉"),
            "雅加达": ("雅加达", "雅加达"),
            "爱琴海": ("爱琴海", "爱琴海"),
            "圣托里尼": ("圣托里尼", "圣托里尼"),
            "九寨沟": ("九寨沟", "九寨沟"),
            "张家界": ("张家界", "张家界"),
            "黄山": ("黄山", "黄山"),
            "鼓浪屿": ("厦门", "鼓浪屿"),
            "西双版纳": ("西双版纳", "西双版纳")
        ]
        
        for (keyword, info) in landmarks {
            if text.contains(keyword) {
                return (info.destination, info.displayName)
            }
        }
        
        return ("未知目的地", "未知目的地")
    }
}

struct MatchDatePickerRowView: View {
    let isExpanded: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    let today: Date
    let onToggle: () -> Void

    @State private var hasStartSelection: Bool = false
    @State private var hasEndSelection: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .center, spacing: 6) {
                if isExpanded {
                    Text("预计出行时间：")
                        .font(.system(size: 12))
                        .foregroundColor(.tripTextBrown.opacity(0.7))

                    HStack(spacing: 4) {
                        // 起始：[月] 月 [日] 日
                        numberMenu(
                            value: hasStartSelection ? Calendar.current.component(.month, from: startDate) : nil,
                            range: 1...12,
                            onSelect: { setStart(month: $0) }
                        )
                        Text("月")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown)
                        numberMenu(
                            value: hasStartSelection ? Calendar.current.component(.day, from: startDate) : nil,
                            range: 1...31,
                            onSelect: { setStart(day: $0) }
                        )
                        Text("日")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown)

                        Text("到")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown.opacity(0.5))

                        // 结束：[月] 月 [日] 日
                        numberMenu(
                            value: hasEndSelection ? Calendar.current.component(.month, from: endDate) : nil,
                            range: 1...12,
                            onSelect: { setEnd(month: $0) }
                        )
                        Text("月")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown)
                        numberMenu(
                            value: hasEndSelection ? Calendar.current.component(.day, from: endDate) : nil,
                            range: 1...31,
                            onSelect: { setEnd(day: $0) }
                        )
                        Text("日")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(spacing: 4) {
                        Text("预计出行时间:")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown.opacity(0.7))
                        Text("flexible")
                            .font(.system(size: 12))
                            .foregroundColor(.tripTextBrown.opacity(0.5))
                            .italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.tripPostItWhite)
            .cornerRadius(4)
            .frame(width: 240, alignment: .leading)
            .onChange(of: isExpanded) { expanded in
                // 关闭再展开时重置回 "--" 状态
                if !expanded {
                    hasStartSelection = false
                    hasEndSelection = false
                }
            }

            Button(action: onToggle) {
                Image(systemName: isExpanded ? "minus" : "plus")
                    .foregroundColor(.tripTextBrown.opacity(0.6))
                    .font(.caption)
            }
            .offset(x: -6, y: 6)
        }
    }

    // MARK: - 数字选择 Menu（点击弹出 1...N 单数字选择）
    @ViewBuilder
    private func numberMenu(value: Int?, range: ClosedRange<Int>, onSelect: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(Array(range), id: \.self) { n in
                Button("\(n)") { onSelect(n) }
            }
        } label: {
            Text(value.map { String(format: "%02d", $0) } ?? "--")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.tripTextBrown)
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.1))
                )
        }
    }

    // MARK: - 写回 startDate / endDate
    private func setStart(month: Int? = nil, day: Int? = nil) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: startDate)
        if let m = month { components.month = m }
        if let d = day { components.day = d }
        // 月份验证（避免 2 月 31 日等非法日期）
        if let m = components.month, let d = components.day, d > Self.daysIn(month: m, year: components.year ?? Calendar.current.component(.year, from: today)) {
            components.day = Self.daysIn(month: m, year: components.year ?? Calendar.current.component(.year, from: today))
        }
        if let date = Calendar.current.date(from: components) {
            startDate = date
            hasStartSelection = true
        }
    }

    private func setEnd(month: Int? = nil, day: Int? = nil) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: endDate)
        if let m = month { components.month = m }
        if let d = day { components.day = d }
        if let m = components.month, let d = components.day, d > Self.daysIn(month: m, year: components.year ?? Calendar.current.component(.year, from: today)) {
            components.day = Self.daysIn(month: m, year: components.year ?? Calendar.current.component(.year, from: today))
        }
        if let date = Calendar.current.date(from: components) {
            endDate = date
            hasEndSelection = true
        }
    }

    // MARK: - 工具：某年某月天数
    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        default: return 31
        }
    }
}
