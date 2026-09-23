import SwiftUI
import Combine

// MARK: - Sport Clock Sweep (旋转时钟扫掠 + 运动表情)

private struct SportClockSweep: View {
    // 12 项运动表情，从 12 点顺时针到 11 点
    private let sports: [String] = [
        "⛹️",   // 12 点
        "🏃‍♀️",  // 1 点
        "🚴",   // 2 点
        "🏊‍♀️",  // 3 点
        "🏸",   // 4 点
        "⚽️",   // 5 点
        "💃",   // 6 点
        "🏋️",   // 7 点
        "🏓",   // 8 点
        "🧗",   // 9 点
        "🏄",   // 10 点
        "🏌️‍♀️"   // 11 点
    ]
    private let secondsPerSport: Double = 2.0

    /// 计算两个角度之间的最短角差（0~180）
    private func angularDiff(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        if d > 180 { d = 360 - d }
        return d
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2
            // 光束长度 = 半对角线，触及四边但不超出本块（通过 clipped 限制）
            let beamLength = sqrt(w * w + h * h) * 0.5
            // 表情位置半径：放在接近边缘的位置
            let iconRadius = min(w, h) * 0.42
            let sector = 360.0 / Double(sports.count)
            clockContent(cx: cx, cy: cy, beamLength: beamLength, iconRadius: iconRadius, sector: sector)
        }
        .clipped()
    }

    private func clockContent(cx: CGFloat, cy: CGFloat, beamLength: CGFloat, iconRadius: CGFloat, sector: Double) -> some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let progress = t / secondsPerSport
            let currentAngle = (progress * sector).truncatingRemainder(dividingBy: 360.0)
            clockStack(cx: cx, cy: cy, beamLength: beamLength, iconRadius: iconRadius, sector: sector, currentAngle: currentAngle)
        }
    }

    private func clockStack(cx: CGFloat, cy: CGFloat, beamLength: CGFloat, iconRadius: CGFloat, sector: Double, currentAngle: Double) -> some View {
        ZStack {
            beamView(cx: cx, cy: cy, beamLength: beamLength, angle: currentAngle)
            ForEach(0..<sports.count, id: \.self) { i in
                sportEmojiView(index: i, cx: cx, cy: cy, iconRadius: iconRadius, sector: sector, currentAngle: currentAngle)
            }
        }
    }

    // 旋转的细长三角光束（到达四边）
    private func beamView(cx: CGFloat, cy: CGFloat, beamLength: CGFloat, angle: Double) -> some View {
        let frame = beamLength * 2
        let beam = SportBeamShape().fill(Color.white.opacity(0.25))
        let sized = beam.frame(width: frame, height: frame)
        let positioned = sized.position(x: cx, y: cy)
        return positioned.rotationEffect(.degrees(angle))
    }

    // 各运动表情在固定表盘位置，随光束扫过时淡入淡出
    private func sportEmojiView(index: Int, cx: CGFloat, cy: CGFloat, iconRadius: CGFloat, sector: Double, currentAngle: Double) -> some View {
        let sportAngle = Double(index) * sector
        let srad = sportAngle * .pi / 180.0
        let px = cx + sin(srad) * iconRadius
        let py = cy - cos(srad) * iconRadius
        let diff = angularDiff(currentAngle, sportAngle)
        let opacity = max(0, 1 - diff / (sector * 0.45))
        let emoji = sports[index]
        let text = Text(emoji).font(.system(size: 22))
        let positioned = text.position(x: px, y: py)
        return positioned.opacity(opacity)
    }
}

// 从中心向上指的窄三角（光束长度覆盖对角线）
private struct SportBeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let halfWidth = r * 0.12

        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy))                    // 中心顶点
        path.addLine(to: CGPoint(x: cx - halfWidth, y: cy - r)) // 左上底边
        path.addLine(to: CGPoint(x: cx + halfWidth, y: cy - r)) // 右上底边
        path.closeSubpath()
        return path
    }
}

// MARK: - SportsView (入口页面)
struct SportsView: View {
    let userId: String
    let existingEntries: [EventsMatchEntry]
    let onEventSaved: (EventsMatchEntry) -> Void
    let onSaveAndJumpToMyPage: ((EventsMatchEntry) -> Void)?
    var onCreateMilestone: ((MilestoneRecord) -> Void)? = nil
    var onRemoveEventByMatchName: ((String) -> Void)? = nil

    init(
        userId: String = "",
        existingEntries: [EventsMatchEntry] = [],
        onEventSaved: @escaping (EventsMatchEntry) -> Void,
        onSaveAndJumpToMyPage: ((EventsMatchEntry) -> Void)? = nil,
        onCreateMilestone: ((MilestoneRecord) -> Void)? = nil,
        onRemoveEventByMatchName: ((String) -> Void)? = nil
    ) {
        self.userId = userId
        self.existingEntries = existingEntries
        self.onEventSaved = onEventSaved
        self.onSaveAndJumpToMyPage = onSaveAndJumpToMyPage
        self.onCreateMilestone = onCreateMilestone
        self.onRemoveEventByMatchName = onRemoveEventByMatchName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationLink(destination: EventsView(
                    existingEntries: existingEntries,
                    onEventSaved: onEventSaved,
                    onSaveAndJumpToMyPage: onSaveAndJumpToMyPage,
                    onRemoveEventByMatchName: onRemoveEventByMatchName
                )) {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.95, green: 0.55, blue: 0.75),
                                Color(red: 0.40, green: 0.85, blue: 0.55),
                                Color(red: 0.30, green: 0.60, blue: 0.95),
                                Color(red: 0.55, green: 0.35, blue: 0.85)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(L("关注体育赛事", "Favorite Events"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.25), radius: 4, x: 1, y: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: SportPlansView(userId: userId, onCreateMilestone: onCreateMilestone)) {
                    ZStack {
                        Color(red: 0.10, green: 0.18, blue: 0.45)
                        SportClockSweep()
                        Text(L("我的运动计划", "My Sports Plans"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 6, x: 1, y: 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Events Color Extensions
fileprivate extension Color {
    static let eventsSportOrange = Color(red: 0.95, green: 0.45, blue: 0.25)
    static let eventsSportBlue = Color(red: 0.30, green: 0.60, blue: 0.90)
    static let eventsSportGreen = Color(red: 0.35, green: 0.75, blue: 0.45)
    static let eventsSportPurple = Color(red: 0.65, green: 0.35, blue: 0.85)
    static let eventsSportYellow = Color(red: 0.95, green: 0.85, blue: 0.25)
    static let eventsTextDark = Color(red: 0.25, green: 0.30, blue: 0.40)
    static let eventsSketchRed = Color(red: 0.92, green: 0.30, blue: 0.35)
    static let eventsSportRed = Color(red: 0.85, green: 0.20, blue: 0.20)
}

// MARK: - Events Models
struct EventsMatchEntry: Identifiable, Codable {
    let id = UUID()
    let sport: String
    let matchName: String
    let matchTime: String
    let team1: String
    let team2: String
    let freeText: String
    let heartOnTeam: Int?
    let isScoreMatch: Bool

    // id 不持久化：每次解码重新生成（仅作内存标识）
    enum CodingKeys: String, CodingKey {
        case sport, matchName, matchTime, team1, team2, freeText, heartOnTeam, isScoreMatch
    }
}

// MARK: - EventsView (赛事关注)
struct EventsView: View {
    let existingEntries: [EventsMatchEntry]
    let onEventSaved: (EventsMatchEntry) -> Void
    let onSaveAndJumpToMyPage: ((EventsMatchEntry) -> Void)?
    var onRemoveEventByMatchName: ((String) -> Void)? = nil

    @State private var selectedSport: String? = nil
    @State private var sportInput: String = ""
    @State private var showResultPage = false

    @State private var matchName: String = ""
    @State private var matchTime: String = ""
    @State private var team1: String = ""
    @State private var team2: String = ""
    @State private var freeText: String = ""
    @State private var heartOnTeam: Int? = nil
    @State private var supportedPlayer: String = ""

    @State private var savedEntries: [EventsMatchEntry] = []
    @State private var savedToMyPageIds: Set<UUID> = []
    @State private var isHeartClicked: Bool = false   // 右上角心形点击后的红色状态
    @State private var showDuplicateAlert: Bool = false
    @State private var pendingEntry: EventsMatchEntry?

    private let scoreMatchSports: Set<String> = [
        // 中文
        "游泳", "跳水", "田径", "体操", "花样游泳", "射击",
        "射箭", "举重", "高尔夫", "自行车", "花样滑冰", "滑雪",
        "短道速滑", "攀岩", "滑板", "马拉松", "钓鱼",
        // English (case-insensitive — 见 isScoreMatch)
        "swimming", "diving", "athletics", "gymnastics", "synchronized swimming",
        "shooting", "archery", "weightlifting", "golf", "cycling",
        "figure skating", "skiing", "short track speed skating",
        "climbing", "skateboarding", "marathon", "fishing"
    ]

    private var isScoreMatch: Bool {
        guard let sport = selectedSport else { return false }
        return scoreMatchSports.contains(sport.lowercased())
    }

    var body: some View {
        ZStack {
            eventsBackgroundGradient

            if showResultPage {
                EventsResultPage(
                    entries: savedEntries,
                    savedToMyPageIds: savedToMyPageIds,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showResultPage = false
                        }
                    },
                    onDelete: { entry in
                        savedEntries.removeAll { $0.id == entry.id }
                        savedToMyPageIds.remove(entry.id)
                    },
                    onSaveToMyPage: { entry in
                        if !savedToMyPageIds.contains(entry.id) {
                            savedToMyPageIds.insert(entry.id)
                            onEventSaved(entry)
                        }
                    },
                    onSaveAndJumpToMyPage: onSaveAndJumpToMyPage
                )
                .transition(.opacity)
                .zIndex(2)
            } else {
                VStack(spacing: 20) {
                    Spacer()

                    if selectedSport == nil {
                        HStack(spacing: 8) {
                            Text(L("关注最近", "Upcoming"))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.eventsTextDark)

                            TextField(L("运动名称", "Sport Name"), text: $sportInput)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.eventsSportOrange)
                                .multilineTextAlignment(.center)
                                .frame(width: 140, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.9))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.eventsSportOrange.opacity(0.4), lineWidth: 1)
                                        )
                                )
                                .onSubmit {
                                    let trimmed = sportInput.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        selectedSport = trimmed
                                    }
                                }

                            Text(L("赛事", "Match"))
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.eventsTextDark)
                        }
                    }

                    if selectedSport != nil {
                        eventsInputCard
                    }

                    Spacer()
                }
                .padding()
                .zIndex(1)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("已存在该赛事卡片", "This match card already exists"),
               isPresented: $showDuplicateAlert) {
            Button(role: .destructive) {
                confirmReplaceDuplicate()
            } label: {
                Text(L("是", "Yes"))
            }
            Button(role: .cancel) {
                declineDuplicateAndAppendSuffix()
            } label: {
                Text(L("否", "No"))
            }
        } message: {
            Text(L("是否替换成新卡片？", "Replace with the new card?"))
        }
    }

    private var eventsInputCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    selectedSport = nil
                    matchName = ""
                    matchTime = ""
                    team1 = ""
                    team2 = ""
                    freeText = ""
                    heartOnTeam = nil
                    supportedPlayer = ""
                    isHeartClicked = false
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.eventsSportBlue)
                }
                Spacer()
                Text(L("添加我关注的\(selectedSport ?? "")赛事", "Add \(selectedSport ?? "") Events I Follow"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.eventsTextDark)
                Spacer()
                // 右上角心形按钮：必填项填完后才可点击，点击变红并跳转我的页
                Button(action: submitEvent) {
                    Image(systemName: isHeartClicked ? "heart.fill" : "heart")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(
                            isHeartClicked
                                ? Color.eventsSportRed
                                : (eventsCanSubmit ? Color.eventsSportRed.opacity(0.7) : Color.gray.opacity(0.4))
                        )
                }
                .disabled(!eventsCanSubmit || isHeartClicked)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 2) {
                            Text(L("比赛名称", "Match Name"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.eventsTextDark)
                            Text("*")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.eventsSportRed)
                        }
                        .frame(width: 80, alignment: .leading)
                        TextField(L("例：2024奥运会决赛", "e.g. 2024 Olympic Final"), text: $matchName)
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(matchName.isEmpty ? Color.eventsSportRed.opacity(0.4) : Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    HStack {
                        HStack(spacing: 2) {
                            Text(L("比赛时间", "Match Time"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.eventsTextDark)
                            Text("*")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.eventsSportRed)
                        }
                        .frame(width: 80, alignment: .leading)
                        TextField(L("例：7月25日 19:30", "e.g. Jul 25 19:30"), text: $matchTime)
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(matchTime.isEmpty ? Color.eventsSportRed.opacity(0.4) : Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    if isScoreMatch {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text(L("我支持的选手", "Supported Player"))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.eventsTextDark)
                                Text("*")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.eventsSportRed)
                            }

                            TextField(L("选手姓名", "Player Name"), text: $supportedPlayer)
                                .font(.system(size: 15))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(supportedPlayer.isEmpty ? Color.eventsSportRed.opacity(0.4) : Color.eventsSketchRed.opacity(0.6), lineWidth: 1)
                                )
                                .overlay(alignment: .topLeading) {
                                    if !supportedPlayer.isEmpty {
                                        EventsSketchHeart()
                                            .frame(width: 22, height: 22)
                                            .offset(x: -8, y: -8)
                                    }
                                }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 2) {
                                Text(L("比赛双方", "Teams"))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.eventsTextDark)
                                Text("*")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.eventsSportRed)
                            }

                            HStack(spacing: 10) {
                                eventsTeamField(text: $team1, placeholder: L("队伍1", "Team 1"), hasHeart: heartOnTeam == 1)
                                    .frame(maxWidth: .infinity)

                                Text("VS")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.eventsSportOrange)

                                eventsTeamField(text: $team2, placeholder: L("队伍2", "Team 2"), hasHeart: heartOnTeam == 2)
                                    .frame(maxWidth: .infinity)
                            }

                            eventsHeartStickerArea
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("备注", "Notes"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.eventsTextDark)

                        ZStack(alignment: .topLeading) {
                            if freeText.isEmpty {
                                Text(L("想记录的内容...", "Add a note..."))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.top, 10)
                                    .padding(.leading, 12)
                            }
                            TextEditor(text: $freeText)
                                .font(.system(size: 14))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .frame(height: 100)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - 点击右上角心形：创建 entry 并跳转"我的"页
    private func submitEvent() {
        guard eventsCanSubmit, !isHeartClicked else { return }

        // 心形变红（视觉反馈）
        withAnimation(.easeIn(duration: 0.2)) {
            isHeartClicked = true
        }

        let entry = EventsMatchEntry(
            sport: selectedSport ?? "",
            matchName: matchName,
            matchTime: matchTime,
            team1: isScoreMatch ? supportedPlayer : team1,
            team2: team2,
            freeText: freeText,
            heartOnTeam: isScoreMatch ? 1 : heartOnTeam,
            isScoreMatch: isScoreMatch
        )

        // 检查重名：合并本次会话与父 view 已保存的卡片
        let allEntries = savedEntries + existingEntries
        if allEntries.contains(where: { $0.matchName == matchName }) {
            pendingEntry = entry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showDuplicateAlert = true
            }
            return
        }

        savedEntries.append(entry)
        savedToMyPageIds.insert(entry.id)

        // 调用外部 closure 让父 view 创建"我的"页卡片并跳转
        // 延迟 0.4s 让心形变红可见
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onSaveAndJumpToMyPage?(entry)
        }
    }

    /// 用户选择"是"：用新卡片替换同名原卡片
    private func confirmReplaceDuplicate() {
        guard let entry = pendingEntry else { return }
        // 从本地 savedEntries 移除同名卡片
        savedEntries.removeAll { $0.matchName == entry.matchName }
        // 通知父 view 移除同名旧卡片
        onRemoveEventByMatchName?(entry.matchName)
        savedEntries.append(entry)
        savedToMyPageIds.insert(entry.id)
        let entryToSave = entry
        pendingEntry = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSaveAndJumpToMyPage?(entryToSave)
        }
    }

    /// 用户选择"否"：保留原卡片，新卡片名称后追加 "2"
    private func declineDuplicateAndAppendSuffix() {
        guard let entry = pendingEntry else { return }
        let appendedEntry = EventsMatchEntry(
            sport: entry.sport,
            matchName: entry.matchName + "2",
            matchTime: entry.matchTime,
            team1: entry.team1,
            team2: entry.team2,
            freeText: entry.freeText,
            heartOnTeam: entry.heartOnTeam,
            isScoreMatch: entry.isScoreMatch
        )
        savedEntries.append(appendedEntry)
        savedToMyPageIds.insert(appendedEntry.id)
        let entryToSave = appendedEntry
        pendingEntry = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSaveAndJumpToMyPage?(entryToSave)
        }
    }

    private var eventsCanSubmit: Bool {
        !matchName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !matchTime.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isScoreMatch
         ? !supportedPlayer.trimmingCharacters(in: .whitespaces).isEmpty
         : (!team1.trimmingCharacters(in: .whitespaces).isEmpty &&
            !team2.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    private func eventsTeamField(text: Binding<String>, placeholder: String, hasHeart: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            TextField(placeholder, text: text)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hasHeart ? Color.eventsSketchRed.opacity(0.08) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasHeart ? Color.eventsSketchRed : Color.gray.opacity(0.3), lineWidth: hasHeart ? 2 : 1)
                )

            if hasHeart {
                EventsSketchHeart()
                    .frame(width: 26, height: 26)
                    .offset(x: -10, y: -10)
            }
        }
    }

    private var canApplyHeart: Bool {
        !team1.trimmingCharacters(in: .whitespaces).isEmpty &&
        !team2.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var eventsHeartStickerArea: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    if canApplyHeart { heartOnTeam = 1 }
                }) {
                    HStack(spacing: 4) {
                        EventsSketchHeart()
                            .frame(width: 16, height: 16)
                        Text(L("队伍1", "Team 1"))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(heartOnTeam == 1 ? .eventsSketchRed : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(heartOnTeam == 1 ? Color.eventsSketchRed.opacity(0.15) : Color.gray.opacity(0.08))
                    )
                }
                .disabled(!canApplyHeart)

                Spacer()

                EventsSketchHeart()
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                    .onTapGesture {
                        guard canApplyHeart else { return }
                        if heartOnTeam == nil {
                            heartOnTeam = 1
                        } else if heartOnTeam == 1 {
                            heartOnTeam = 2
                        } else {
                            heartOnTeam = nil
                        }
                    }

                Spacer()

                Button(action: {
                    if canApplyHeart { heartOnTeam = 2 }
                }) {
                    HStack(spacing: 4) {
                        EventsSketchHeart()
                            .frame(width: 16, height: 16)
                        Text(L("队伍2", "Team 2"))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(heartOnTeam == 2 ? .eventsSketchRed : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(heartOnTeam == 2 ? Color.eventsSketchRed.opacity(0.15) : Color.gray.opacity(0.08))
                    )
                }
                .disabled(!canApplyHeart)
            }

            Text(heartOnTeam.map { "爱心已贴在队伍\($0)，点击爱心可切换" }
                 ?? L(canApplyHeart ? "给你喜欢的队伍贴上爱心" : "请先填完队伍1和队伍2",
                      canApplyHeart ? "Put a heart sticker on the team you support" : "Please fill in both Team 1 and Team 2 first"))
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.top, 4)
    }

    private var eventsBackgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.eventsSportYellow.opacity(0.5),
                Color.eventsSportOrange.opacity(0.3),
                Color.eventsSportBlue.opacity(0.4),
                Color.eventsSportPurple.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Events Sketch Heart
struct EventsSketchHeart: View {
    var body: some View {
        ZStack {
            EventsHeartShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.eventsSketchRed,
                            Color(red: 0.85, green: 0.20, blue: 0.25)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    EventsHeartShape()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    EventsHeartShape()
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                        .offset(x: 0.5, y: 0.5)
                )
        }
    }
}

// MARK: - Events Heart Shape
struct EventsHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
        path.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.4),
                      control1: CGPoint(x: w * 0.2, y: h * 0.72),
                      control2: CGPoint(x: w * 0.02, y: h * 0.55))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.28),
                      control1: CGPoint(x: w * 0.18, y: h * 0.12),
                      control2: CGPoint(x: w * 0.4, y: h * 0.1))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.4),
                      control1: CGPoint(x: w * 0.6, y: h * 0.1),
                      control2: CGPoint(x: w * 0.82, y: h * 0.12))
        path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.92),
                      control1: CGPoint(x: w * 0.98, y: h * 0.55),
                      control2: CGPoint(x: w * 0.8, y: h * 0.72))
        path.closeSubpath()
        return path
    }
}

// MARK: - Events Result Page
struct EventsResultPage: View {
    let entries: [EventsMatchEntry]
    let savedToMyPageIds: Set<UUID>
    let onBack: () -> Void
    let onDelete: (EventsMatchEntry) -> Void
    let onSaveToMyPage: (EventsMatchEntry) -> Void
    let onSaveAndJumpToMyPage: ((EventsMatchEntry) -> Void)?

    private var sortedEntries: [EventsMatchEntry] {
        entries.sorted { eventsParseDate($0.matchTime) < eventsParseDate($1.matchTime) }
    }

    private func eventsParseDate(_ str: String) -> Date {
        let cleaned = str.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        formatter.dateFormat = "M月d日 HH:mm"
        if let d = formatter.date(from: cleaned) { return d }

        formatter.dateFormat = "M月d日"
        if let d = formatter.date(from: cleaned) { return d }

        if let range = cleaned.range(of: "-") {
            let first = String(cleaned[cleaned.startIndex..<range.lowerBound])
            formatter.dateFormat = "M月d日"
            if let d = formatter.date(from: first) { return d }
        }

        return Date.distantFuture
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Color.clear.frame(width: 60, height: 20)
                    Spacer()
                    Text(L("我关注的赛事", "My Followed Match"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.eventsTextDark)
                    Spacer()
                    Color.clear.frame(width: 60, height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 16) {
                        ForEach(sortedEntries) { entry in
                            eventsEntryCard(entry)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func eventsEntryCard(_ entry: EventsMatchEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(entry.sport)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.eventsSportOrange)
                Spacer()
                Button(action: {
                    onSaveToMyPage(entry)
                    onSaveAndJumpToMyPage?(entry)
                }) {
                    Image(systemName: savedToMyPageIds.contains(entry.id) ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(.eventsSketchRed)
                }
                .buttonStyle(.plain)
            }

            if !entry.matchName.isEmpty || !entry.matchTime.isEmpty {
                HStack(alignment: .top, spacing: 24) {
                    if !entry.matchName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("比赛名称", "Match Name"))
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(entry.matchName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.eventsTextDark)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    if !entry.matchTime.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L("比赛时间", "Match Time"))
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(entry.matchTime)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.eventsTextDark)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            if entry.isScoreMatch {
                if !entry.team1.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("我支持的选手", "Supported Player"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        ZStack(alignment: .topLeading) {
                            Text(entry.team1)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.eventsTextDark)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.eventsSketchRed.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.eventsSketchRed, lineWidth: 1)
                                )
                            EventsSketchHeart()
                                .frame(width: 24, height: 24)
                                .offset(x: -8, y: -8)
                        }
                    }
                }
            } else {
                if !entry.team1.isEmpty || !entry.team2.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("比赛双方", "Teams"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)

                        HStack(spacing: 10) {
                            ZStack(alignment: .topLeading) {
                                Text(entry.team1.isEmpty ? "—" : entry.team1)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.eventsTextDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(entry.heartOnTeam == 1 ? Color.eventsSketchRed.opacity(0.08) : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(entry.heartOnTeam == 1 ? Color.eventsSketchRed : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                if entry.heartOnTeam == 1 {
                                    EventsSketchHeart()
                                        .frame(width: 24, height: 24)
                                        .offset(x: -8, y: -8)
                                }
                            }

                            Text("VS")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.eventsSportOrange)

                            ZStack(alignment: .topLeading) {
                                Text(entry.team2.isEmpty ? "—" : entry.team2)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.eventsTextDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(entry.heartOnTeam == 2 ? Color.eventsSketchRed.opacity(0.08) : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(entry.heartOnTeam == 2 ? Color.eventsSketchRed : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                if entry.heartOnTeam == 2 {
                                    EventsSketchHeart()
                                        .frame(width: 24, height: 24)
                                        .offset(x: -8, y: -8)
                                }
                            }
                        }
                    }
                }
            }

            if !entry.freeText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("备注", "Notes"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text(entry.freeText)
                        .font(.system(size: 15))
                        .foregroundColor(.eventsTextDark)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.eventsSportBlue.opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - Plan Models
struct PlanSportPlan: Identifiable, Codable {
    let id: UUID
    let text: String
    let sport: String
    var deleted: Bool = false
}

struct PlanDiaryEntry: Identifiable, Codable {
    let id: UUID
    let date: String
    let content: String
    let sport: String
}

struct MilestoneRecord: Identifiable, Codable {
    let id: UUID
    let sportName: String
    let date: String
    let content: String
}

enum PlanPageState {
    case sports
    case diary
}

// MARK: - Sport Level Progress Bar
struct SportLevelBar: View {
    let diaryCount: Int

    private var sectionTitles: [String] {
        [L("基础", "Basic"), L("初级", "Beginner"), L("中级", "Intermediate"), L("高级", "Advanced")]
    }

    private enum LevelColors {
        static let lightBlue = Color(red: 173/255, green: 216/255, blue: 230/255)
        static let midBlue = Color(red: 120/255, green: 170/255, blue: 220/255)
        static let oceanBlue = Color(red: 50/255, green: 110/255, blue: 170/255)
        static let deepNavy = Color(red: 25/255, green: 51/255, blue: 128/255)
    }

    private func fillColor(for section: Int) -> Color? {
        if diaryCount == 0 { return nil }
        switch section {
        case 0:
            return diaryCount >= 1 ? LevelColors.lightBlue : nil
        case 1:
            return diaryCount >= 11 ? LevelColors.midBlue : nil
        case 2:
            return diaryCount >= 26 ? LevelColors.oceanBlue : nil
        case 3:
            return diaryCount > 45 ? LevelColors.deepNavy : nil
        default:
            return nil
        }
    }

    private func textColor(for section: Int) -> Color {
        let fill = fillColor(for: section)
        if fill == LevelColors.oceanBlue || fill == LevelColors.deepNavy {
            return .white.opacity(0.9)
        }
        return Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.75)
    }

    var body: some View {
        GeometryReader { geo in
            let sectionWidth = geo.size.width / 4
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { idx in
                    ZStack {
                        Rectangle()
                            .fill(fillColor(for: idx) ?? Color.clear)
                        Text(sectionTitles[idx])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textColor(for: idx))
                    }
                    .frame(width: sectionWidth)
                    .overlay(
                        Rectangle()
                            .stroke(Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
            .frame(height: 14)
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.2), lineWidth: 0.5)
            )
        }
        .frame(height: 14)
    }
}

// MARK: - SportPlansView (运动计划)
struct QuickPlanRow: Identifiable {
    let id = UUID()
    var showInput: Bool = false
    var inputText: String = ""
    var confirmed: Bool = false
    var deleted: Bool = false
    var sport: String = ""
}

struct SportPlansView: View {
    let userId: String
    var onCreateMilestone: ((MilestoneRecord) -> Void)? = nil

    @State private var pageState: PlanPageState = .sports
    @State private var detectedSport: String? = nil

    // 检查某运动是否已完成里程碑
    private func sportHasMilestone(_ sport: String) -> Bool {
        guard !sport.isEmpty,
              let data = UserDefaults.standard.data(forKey: "\(userId)_sports_trophies_\(sport)"),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return false }
        return !ids.isEmpty
    }

    @State private var quickRows: [QuickPlanRow] = [QuickPlanRow(showInput: false)]

    let sportsKeywords = [
        "足球", "篮球", "网球", "乒乓球", "羽毛球", "跑步", "快走", "壁球", "排球", "匹克球",
        "瑜伽", "普拉提", "游泳", "滑板", "攀岩",
        "滑冰", "滑雪", "骑行", "力量训练", "重训",
        "马拉松",
        "棒球", "蛙泳", "蝶泳", "仰泳", "自由泳", "抱石", "单板", "冲浪", "徒步", "爬山", "芭蕾", "跳操"
    ]

    /// 英文运动关键词 → 中文存储名（大小写不敏感匹配，按长度降序优先匹配长词）
    private let englishSportKeywords: [(en: String, zh: String)] = [
        ("table tennis", "乒乓球"), ("ping pong", "乒乓球"),
        ("brisk walking", "快走"), ("strength training", "力量训练"),
        ("weight training", "重训"), ("mountain climbing", "爬山"),
        ("butterfly stroke", "蝶泳"), ("rock climbing", "攀岩"),
        ("ice skating", "滑冰"), ("skateboarding", "滑板"),
        ("snowboarding", "单板"), ("breaststroke", "蛙泳"),
        ("pickleball", "匹克球"), ("badminton", "羽毛球"),
        ("basketball", "篮球"), ("volleyball", "排球"),
        ("baseball", "棒球"), ("football", "足球"),
        ("swimming", "游泳"), ("running", "跑步"),
        ("tennis", "网球"), ("squash", "壁球"),
        ("cycling", "骑行"), ("skiing", "滑雪"),
        ("bouldering", "抱石"), ("surfing", "冲浪"),
        ("hiking", "徒步"), ("marathon", "马拉松"),
        ("backstroke", "仰泳"), ("freestyle", "自由泳"),
        ("pilates", "普拉提"), ("aerobics", "跳操"),
        ("ballet", "芭蕾"), ("yoga", "瑜伽")
    ]

    /// 从用户输入文本中检测运动项目
    /// - 英文输入（如 "swimming"）→ 返回首字母大写英文（如 "Swimming"）
    /// - 中文输入（如 "蛙泳"）→ 返回中文（如 "蛙泳"）
    /// - 未命中 → "自定义运动"
    /// 秉持不对用户输入做翻译的原则：运动名按用户输入的语言存储，显示时只翻译后缀
    private func detectSport(in text: String) -> String {
        let lower = text.lowercased()
        for (en, _) in englishSportKeywords {
            if lower.contains(en) {
                return en.capitalized
            }
        }
        for kw in sportsKeywords {
            if text.contains(kw) { return kw }
        }
        return "自定义运动"
    }

    private var savedPlansKey: String {
        let prefix = userId.isEmpty ? "" : "\(userId)_"
        return "\(prefix)sports_savedPlansJSON"
    }

    private var diaryKey: String {
        let prefix = userId.isEmpty ? "" : "\(userId)_"
        return "\(prefix)sports_diaryJSON"
    }

    @State private var savedPlansJSON: String = "[]"
    @State private var diaryJSON: String = "[]"

    private var savedPlans: [PlanSportPlan] {
        guard let data = savedPlansJSON.data(using: .utf8),
              let plans = try? JSONDecoder().decode([PlanSportPlan].self, from: data) else {
            return []
        }
        return plans
    }

    private var diaryEntries: [PlanDiaryEntry] {
        guard let data = diaryJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([PlanDiaryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func diaryEntries(for sport: String) -> [PlanDiaryEntry] {
        diaryEntries.filter { $0.sport == sport }
    }

    var body: some View {
        ZStack {
            planPolkaDotBackground
                .allowsHitTesting(false)

            if pageState == .sports {
                planSportsHomePage
                    .transition(.opacity)
            } else if pageState == .diary, let sport = detectedSport {
                PlanDiaryPage(sport: sport, userId: userId, entries: diaryEntries(for: sport), onSave: { addDiaryEntry(sport: sport, content: $0) }, onBack: goToSports, onCreateMilestone: onCreateMilestone)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let stored = UserDefaults.standard.string(forKey: savedPlansKey) {
                savedPlansJSON = stored
            }
            if let stored = UserDefaults.standard.string(forKey: diaryKey) {
                diaryJSON = stored
            }
            syncQuickRowsWithSavedPlans()
        }
    }

    private var planSportsHomePage: some View {
        VStack(spacing: 0) {
            // 可滚动区域：链式 + 快速添加行
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(Array(quickRows.enumerated()), id: \.element.id) { idx, row in
                        quickRowView(idx: idx, row: row)
                    }
                }
                .padding(.top, 115)
                .padding(.leading, 28)
                .padding(.trailing, 28)
                .padding(.bottom, 20)
            }
            // 点击空白处取消编辑
            .onTapGesture {
                cancelEditing()
            }

            // 固定底部纯文本
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.4))
                    .frame(height: 1)
                    .frame(maxWidth: 60)

                Text(quickRows.allSatisfy { !$0.confirmed } ? L("添加运动计划", "Add a Sport Plan") : L("添加新计划", "Add a New Plan"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.5))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.4))
                    .frame(height: 1)
                    .frame(maxWidth: 60)
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 30)
            .padding(.top, 6)
            .background(Color(red: 246/255, green: 241/255, blue: 235/255))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Quick row view
    @ViewBuilder
    private func quickRowView(idx: Int, row: QuickPlanRow) -> some View {
        let hasMilestone = sportHasMilestone(row.sport)
        HStack(alignment: .top, spacing: 10) {
            // + 按钮
            plusButton(disabled: row.confirmed || row.showInput) {
                expandQuickRow(id: row.id)
            }

            if row.confirmed {
                // 已确认：等级进度条 + 只读文本展示 + 删除 x + 划线效果
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        SportLevelBar(diaryCount: row.deleted ? 0 : diaryEntries(for: row.sport).count)
                        Text(row.inputText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(row.deleted
                                             ? Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.4)
                                             : Color(red: 0.1, green: 0.2, blue: 0.5))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(hasMilestone ? Color(red: 222/255, green: 205/255, blue: 190/255) : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 146/255, green: 168/255, blue: 209/255).opacity(0.4), lineWidth: 1)
                            )
                            .overlay {
                                // 删除划线：横穿文字中间（里程碑完成后不允许划线）
                                if row.deleted && !hasMilestone {
                                    Rectangle()
                                        .fill(Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.5))
                                        .frame(height: 1.5)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .onTapGesture {
                                if !row.deleted && !row.sport.isEmpty {
                                    detectedSport = row.sport
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        pageState = .diary
                                    }
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)

                    // 删除 x 按钮（里程碑完成后隐藏）
                    if !hasMilestone {
                        Button(action: { deleteQuickRow(id: row.id) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(row.deleted ? Color.gray.opacity(0.4) : .red.opacity(0.7))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .disabled(row.deleted)
                    }
                }
            } else if row.showInput {
                // 编辑中：输入框 + 确定按钮
                HStack(alignment: .top, spacing: 8) {
                    TextField(L("输入运动计划...", "Enter sports plan..."), text: Binding(
                        get: { quickRows[idx].inputText },
                        set: { quickRows[idx].inputText = $0 }
                    ), axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.5))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1...10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 146/255, green: 168/255, blue: 209/255).opacity(0.4), lineWidth: 1)
                    )

                    Button(action: { confirmQuickRow(id: row.id) }) {
                        Text(L("确定", "Confirm"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 246/255, green: 241/255, blue: 235/255))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 146/255, green: 168/255, blue: 209/255))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(quickRows[idx].inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(quickRows[idx].inputText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
            }
            // idle 状态：仅显示 + 按钮
        }
    }

    // MARK: - Plus button
    @ViewBuilder
    private func plusButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                    .shadow(color: Color.white.opacity(0.6), radius: 2, x: 0, y: -1)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(disabled ? Color.gray.opacity(0.4) : Color(red: 0.1, green: 0.2, blue: 0.5))
            }
            .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var planPolkaDotBackground: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let dotSize: CGFloat = 2.2
            let spacing: CGFloat = 36

            ZStack {
                Color(red: 246/255, green: 241/255, blue: 235/255)

                ForEach(0..<Int(w / spacing) + 2, id: \.self) { col in
                    ForEach(0..<Int(h / spacing) + 2, id: \.self) { row in
                        Circle()
                            .fill(Color(red: 146/255, green: 168/255, blue: 209/255))
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: CGFloat(col) * spacing + (row % 2 == 0 ? spacing / 2 : 0),
                                y: CGFloat(row) * spacing
                            )
                    }
                }
            }
        }
    }

    private func goToSports() {
        withAnimation(.easeInOut(duration: 0.5)) {
            pageState = .sports
            detectedSport = nil
        }
    }

    private func savePlan(text: String, sport: String) {
        var plans = savedPlans
        plans.append(PlanSportPlan(id: UUID(), text: text, sport: sport))
        if let data = try? JSONEncoder().encode(plans),
           let json = String(data: data, encoding: .utf8) {
            savedPlansJSON = json
            UserDefaults.standard.set(json, forKey: savedPlansKey)
            UserSyncStore.shared.pushSportsPlans(userId: userId, json: json)
        }
    }

    private func addDiaryEntry(sport: String, content: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        let dateStr = formatter.string(from: Date())

        var entries = diaryEntries
        entries.append(PlanDiaryEntry(id: UUID(), date: dateStr, content: content, sport: sport))

        if let data = try? JSONEncoder().encode(entries),
           let json = String(data: data, encoding: .utf8) {
            diaryJSON = json
            UserDefaults.standard.set(json, forKey: diaryKey)
            UserSyncStore.shared.pushSportsDiary(userId: userId, json: json)
        }
    }

    private func deletePlan(_ plan: PlanSportPlan) {
        var plans = savedPlans
        plans.removeAll { $0.id == plan.id }
        if let data = try? JSONEncoder().encode(plans),
           let json = String(data: data, encoding: .utf8) {
            savedPlansJSON = json
            UserDefaults.standard.set(json, forKey: savedPlansKey)
            UserSyncStore.shared.pushSportsPlans(userId: userId, json: json)
        }

        var entries = diaryEntries
        entries.removeAll { $0.sport == plan.sport }
        if let data = try? JSONEncoder().encode(entries),
           let json = String(data: data, encoding: .utf8) {
            diaryJSON = json
            UserDefaults.standard.set(json, forKey: diaryKey)
            UserSyncStore.shared.pushSportsDiary(userId: userId, json: json)
        }
    }

    private func saveQuickPlan(text: String) {
        let sport = detectSport(in: text)
        savePlan(text: text, sport: sport)
    }

    private func expandQuickRow(id: UUID) {
        guard let index = quickRows.firstIndex(where: { $0.id == id }) else { return }
        quickRows[index].showInput = true
    }

    private func confirmQuickRow(id: UUID) {
        guard let index = quickRows.firstIndex(where: { $0.id == id }) else { return }
        let text = quickRows[index].inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        saveQuickPlan(text: text)

        // 同步 quickRows 与已保存的计划（含 planId），并在末尾追加新的 idle 行
        syncQuickRowsWithSavedPlans()
    }

    // 删除：划线 + 删除关联日记 + x 变灰不可点（持久化）
    private func deleteQuickRow(id: UUID) {
        guard let index = quickRows.firstIndex(where: { $0.id == id }) else { return }
        guard !quickRows[index].deleted else { return }
        quickRows[index].deleted = true

        let target = quickRows[index]
        // 持久化：标记 plan.deleted = true
        var plans = savedPlans
        if let planIdx = plans.firstIndex(where: { $0.text == target.inputText && $0.sport == target.sport }) {
            plans[planIdx].deleted = true
            if let data = try? JSONEncoder().encode(plans),
               let json = String(data: data, encoding: .utf8) {
                savedPlansJSON = json
                UserDefaults.standard.set(json, forKey: savedPlansKey)
            UserSyncStore.shared.pushSportsPlans(userId: userId, json: json)
            }
        }
        // 删除关联的运动笔记条目
        var entries = diaryEntries
        entries.removeAll { $0.sport == target.sport }
        if let data = try? JSONEncoder().encode(entries),
           let json = String(data: data, encoding: .utf8) {
            diaryJSON = json
            UserDefaults.standard.set(json, forKey: diaryKey)
            UserSyncStore.shared.pushSportsDiary(userId: userId, json: json)
        }
    }

    // 点击空白处取消编辑：隐藏输入框并清空文本
    private func cancelEditing() {
        for index in quickRows.indices {
            if quickRows[index].showInput && !quickRows[index].confirmed {
                quickRows[index].showInput = false
                quickRows[index].inputText = ""
            }
        }
    }

    // 从 savedPlans 重建 quickRows：已确认行 + 末尾一个 idle 行
    private func syncQuickRowsWithSavedPlans() {
        let plans = savedPlans
        var rows: [QuickPlanRow] = []
        for plan in plans {
            rows.append(QuickPlanRow(
                showInput: false,
                inputText: plan.text,
                confirmed: true,
                deleted: plan.deleted,
                sport: plan.sport
            ))
        }
        rows.append(QuickPlanRow(showInput: false))
        quickRows = rows
    }

}

// MARK: - Plan Diary Page
// MARK: - 键盘观察者（跟随键盘高度/时长/曲线，用于微信风格同步上抬）
private class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var duration: Double = 0.25
    @Published var curveRaw: UInt = 7

    private var bag = Set<AnyCancellable>()

    init() {
        let nc = NotificationCenter.default
        nc.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] n in self?.apply(n, show: true) }
            .store(in: &bag)
        nc.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] n in self?.apply(n, show: false) }
            .store(in: &bag)
    }

    private func apply(_ n: Notification, show: Bool) {
        let info = n.userInfo ?? [:]
        let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let dur = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let raw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        DispatchQueue.main.async {
            self.height = show ? frame.height : 0
            self.duration = dur
            self.curveRaw = raw
        }
    }

    var animation: Animation {
        // curve 7 = UIViewAnimationCurve keyboard 专用，.timingCurve 与之完美匹配
        Animation.timingCurve(0.22, 0.61, 0.36, 1.0, duration: max(duration, 0.01))
    }
}

struct PlanDiaryPage: View {
    let sport: String
    let userId: String
    let entries: [PlanDiaryEntry]
    let onSave: (String) -> Void
    let onBack: () -> Void
    var onCreateMilestone: ((MilestoneRecord) -> Void)? = nil

    private var cellKey: String { "\(userId)_sports_cellTexts_\(sport)" }
    private var trophyKey: String { "\(userId)_sports_trophies_\(sport)" }

    @State private var diaryInput: String = ""
    @State private var cellTexts: [String] = ["", "", ""]
    @State private var activeCell: Int? = nil
    @State private var trophyEntryIds: Set<UUID> = []
    @StateObject private var keyboard = KeyboardObserver()
    @FocusState private var inputFocused: Bool
    @FocusState private var cellFocused: Bool

    private var todayStr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }

    private var todayDiaryCount: Int {
        entries.filter { $0.date == todayStr }.count
    }

    private var overDailyLimit: Bool {
        todayDiaryCount >= 2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
            // ============ 主内容：标题 + 三个格子 + 已有笔记 ============
            // 点击空白处收起键盘 / 提交格子编辑（子视图的 onTapGesture 优先级更高，不影响格子与奖杯）
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Text(sport.isEmpty || sport == "自定义运动"
                        ? L("自定义运动笔记", "Custom Sport Notes")
                        : L("\(sport)运动笔记", "\(sport) Notes"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.2, blue: 0.5))
                    Spacer()
                }
                .padding(.top, 80)

                // ====== 标题下方至屏幕 1/4 处：三个横排长方形格子（可编辑）======
                let titleBottom: CGFloat = 80 + 28 + 16
                let gridH = max(0, geo.size.height / 4 - titleBottom)
                let gridSpacing: CGFloat = 8
                let placeholders = [L("添加我的\n热身流程", "Add My\nWarm-up"), L("添加我的\n练习日常", "Add My\nTraining Routine"), L("添加我的\n整理放松", "Add My\nCool-down")]

                HStack(spacing: gridSpacing) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.5), lineWidth: 1)

                            if activeCell == i {
                                TextField("", text: $cellTexts[i], axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .focused($cellFocused)
                                    .padding(6)
                                    .onSubmit { commitCell(i) }
                            } else {
                                Text(cellTexts[i].isEmpty ? placeholders[i] : cellTexts[i])
                                    .font(.system(size: 15))
                                    .foregroundColor(cellTexts[i].isEmpty ? .gray : .black)
                                    .multilineTextAlignment(.center)
                                    .padding(6)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: gridH)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let prev = activeCell, prev != i { commitCell(prev) }
                            activeCell = i
                            cellFocused = true
                        }
                    }
                }
                .padding(.horizontal, 30)

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(entries) { entry in
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 2) {
                                    Text(D(entry.date))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.1))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(red: 242/255, green: 216/255, blue: 205/255))
                                        .shadow(color: .black.opacity(0.08), radius: 3, x: 1, y: 2)
                                )

                                Text(entry.content)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                    )

                                // 奖杯：仅最新一条笔记显示，空心→金色实心
                                if entry.id == entries.last?.id {
                                    Image(systemName: trophyEntryIds.contains(entry.id) ? "trophy.fill" : "trophy")
                                        .font(.system(size: 20))
                                        .foregroundColor(trophyEntryIds.contains(entry.id) ? Color(red: 255/255, green: 193/255, blue: 37/255) : Color.gray.opacity(0.5))
                                        .contentShape(Rectangle())
                                        .onTapGesture { toggleTrophy(for: entry) }
                                        .padding(.top, 6)
                                } else if trophyEntryIds.contains(entry.id) {
                                    // 已获金奖杯的历史条目保留金色标记（不可再点击切换）
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 255/255, green: 193/255, blue: 37/255))
                                        .padding(.top, 6)
                                }
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                    .padding(.top, 8)
                    // 给 ScrollView 底部留空，避免被 cream bar 盖住最新一条
                    .padding(.bottom, 120)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                if activeCell != nil { commitCell(activeCell!) }
                if inputFocused { inputFocused = false }
            }

            // ============ 底部奶油色通栏 + 白色输入框居中 ============
            creamInputBar
                .padding(.bottom, keyboard.height)
                .animation(keyboard.animation, value: keyboard.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        } // GeometryReader
        .onAppear { loadCellTexts(); loadTrophies() }
        .onChange(of: cellTexts) { _, _ in saveCellTexts() }
        .onDisappear {
            // 用户可能还在编辑中就返回了，确保最后一次修改被保存
            if let active = activeCell { commitCell(active) }
        }
    }

    private func loadCellTexts() {
        if let saved = UserDefaults.standard.array(forKey: cellKey) as? [String], saved.count == 3 {
            cellTexts = saved
        }
    }

    private func saveCellTexts() {
        UserDefaults.standard.set(cellTexts, forKey: cellKey)
        UserSyncStore.shared.pushSportsCellTexts(userId: userId)
    }

    private func loadTrophies() {
        guard let data = UserDefaults.standard.data(forKey: trophyKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return }
        trophyEntryIds = Set(ids)
    }

    private func saveTrophies() {
        let ids = Array(trophyEntryIds)
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: trophyKey)
        }
        UserSyncStore.shared.pushSportsTrophies(userId: userId)
    }

    // 格子输入完成：收起键盘、退出编辑态、持久化
    private func commitCell(_ idx: Int) {
        cellFocused = false
        activeCell = nil
        saveCellTexts()
    }

    // 奖杯点击：切换金色，创建里程碑卡片
    private func toggleTrophy(for entry: PlanDiaryEntry) {
        if trophyEntryIds.contains(entry.id) {
            trophyEntryIds.remove(entry.id)
            saveTrophies()
        } else {
            trophyEntryIds.insert(entry.id)
            saveTrophies()
            let milestone = MilestoneRecord(
                id: UUID(), sportName: sport, date: entry.date, content: entry.content
            )
            onCreateMilestone?(milestone)
        }
    }

    // 里程碑是否已达成（至少一条笔记获得奖杯）
    private var milestoneReached: Bool { !trophyEntryIds.isEmpty }

    // 奶油色通栏（暖乳白 247,243,233）
    private var creamInputBar: some View {
        VStack(spacing: 0) {
            // 顶部极细分隔线，视觉上与内容区区分
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(height: 0.5)

            HStack(spacing: 10) {
                // 白色输入框（通栏中间位置；左右预留 提交按钮 / 平衡对称）
                TextField(milestoneReached ? L("该计划已完成里程碑", "Milestone reached for this plan") : (overDailyLimit ? L("今日已达最多2条记录", "Daily limit of 2 entries reached") : L("记录今天的运动", "Today's training notes")),
                          text: $diaryInput, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .focused($inputFocused)
                    .disabled(overDailyLimit || milestoneReached)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((overDailyLimit || milestoneReached) ? Color.gray.opacity(0.12) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke((overDailyLimit || milestoneReached)
                                    ? Color.gray.opacity(0.25)
                                    : Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.2),
                                    lineWidth: 1)
                    )

                Button(action: submitDiary) {
                    Text(L("提交", "Submit"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 60)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.1, green: 0.2, blue: 0.5))
                        )
                }
                .disabled(overDailyLimit || milestoneReached || diaryInput.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity((overDailyLimit || milestoneReached || diaryInput.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // 键盘显示时移除安全区 padding，让输入框紧贴键盘顶部；隐藏时保留 padding 让内容避开 home indicator
        .padding(.bottom, keyboard.height > 0 ? 0 : UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
        // background 在 padding 之外，覆盖 VStack + padding，奶油色延伸到屏幕底部
        .background(Color(red: 247/255, green: 243/255, blue: 233/255))
    }

    private func submitDiary() {
        guard !overDailyLimit else { return }
        let trimmed = diaryInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        onSave(trimmed)
        diaryInput = ""
    }
}
