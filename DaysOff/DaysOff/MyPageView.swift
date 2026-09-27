import SwiftUI

// MARK: - Text helper

/// 将字符串按每 7 个字符强制换行（用于画展卡片每行最多 7 字）
private func wrapEvery7(_ str: String) -> Text {
    var result = ""
    for (i, ch) in str.enumerated() {
        result.append(ch)
        if i < str.count - 1 && (i + 1) % 7 == 0 {
            result.append("\n")
        }
    }
    return Text(result)
}

private func wrapEvery6(_ str: String) -> Text {
    var result = ""
    for (i, ch) in str.enumerated() {
        result.append(ch)
        if i < str.count - 1 && (i + 1) % 6 == 0 {
            result.append("\n")
        }
    }
    return Text(result)
}

/// 智能换行：含空格（英文）按空格分割换行，无空格（中文）按每 6 字符换行
private func wrapSmart(_ str: String) -> Text {
    if str.contains(" ") {
        let words = str.split(separator: " ")
        return Text(words.joined(separator: "\n"))
    }
    return wrapEvery6(str)
}

/// 将字符串按每 5 个字符强制换行（用于旅行卡片标题每行最多 5 字，最多 2 行）
private func wrapEvery5(_ str: String) -> String {
    var result = ""
    let maxChars = 10 // 最多两行，每行 5 字
    for (i, ch) in str.prefix(maxChars).enumerated() {
        result.append(ch)
        if i < min(str.count, maxChars) - 1 && (i + 1) % 5 == 0 {
            result.append("\n")
        }
    }
    return result
}

// MARK: - Pinable Card with thumbtack (drag / rotate / pin)

private struct PinableCard<Content: View>: View {
    let thumbtackColor: Color
    let useIcecreamGradient: Bool
    let allowTransform: Bool
    let leftBound: CGFloat            // 相对中心偏移：X 下限（≈ -(W/2-8)）
    let rightBound: CGFloat           // 相对中心偏移：X 上限（≈ +(W/2-8)）
    let topBound: CGFloat             // 相对中心偏移：Y 上限（≈ 57-H/2，负值）
    let bottomBound: CGFloat          // 相对中心偏移：Y 下限（≈ +H/2-76，正值）
    var userId: String = ""
    var cardId: String? = nil
    var cardZIndex: Int = 0  // 由父视图基于 topCardStack 计算并传入；越大越靠上
    var onBringToTop: (() -> Void)? = nil
    var defaultOffset: CGSize = .zero // position 默认值：相对屏幕中心的偏移量
    var onCardTap: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var position = CGSize.zero
    @State private var rotation: Double = 0
    @State private var loaded = false
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var gestureRotation: Angle = .zero

    // ⚠️ _v3 后缀：坐标系版本 + 与 UserSyncStore push/restore 两边同步
    //   v1（无后缀）：旧 naturalCenterY 偏移基准（HStack+列布局）——已废弃
    //   v2：短暂使用，中心偏移基准但 push/restore 不同步——已废弃
    //   v3：ZStack(alignment:.center) 中心偏移基准 + push/restore 同步读写
    private var keyPrefix: String { userId.isEmpty ? "" : "\(userId)_" }
    private var posKey: String { "card_pos_\(keyPrefix)\(cardId ?? "")_v3" }
    private var rotKey: String { "card_rot_\(keyPrefix)\(cardId ?? "")" }

    private let thumbtackSize: CGFloat = 14

    private var boundsReady: Bool {
        leftBound < rightBound && topBound < bottomBound
    }
    private func clampedOffset(raw: CGFloat, min: CGFloat?, max: CGFloat?) -> CGFloat {
        var v = raw
        if let m = min { v = Swift.max(m, v) }
        if let m = max { v = Swift.min(m, v) }
        return v
    }

    var body: some View {
        let clampedX = clampedOffset(
            raw: position.width + dragOffset.width,
            min: boundsReady ? leftBound : nil,
            max: boundsReady ? rightBound : nil
        )
        let clampedY = clampedOffset(
            raw: position.height + dragOffset.height,
            min: boundsReady ? topBound : nil,
            max: boundsReady ? bottomBound : nil
        )

        ZStack(alignment: .top) {
            content()
                .contentShape(Rectangle())
                .onTapGesture { onBringToTop?(); onCardTap?() }
                .gesture(
                    dragGesture
                        .simultaneously(with: allowTransform ? rotationGesture : nil)
                )
            ZStack(alignment: .top) {
                Color.clear.frame(width: 36, height: 36)
                thumbtackCircle
            }
            .frame(width: 36, height: 36)
            .allowsHitTesting(false)
            .offset(y: -thumbtackSize)
            .zIndex(999)
        }
        .offset(x: clampedX, y: clampedY)
        .rotationEffect(.degrees(rotation) + gestureRotation)
        .onAppear {
            if cardId != nil, !loaded {
                loaded = true
                // 只读取 v2 版本数据（旧 v1 数据自动失效 → 用 defaultOffset）
                if let posData = UserDefaults.standard.data(forKey: posKey),
                   let pos = try? JSONDecoder().decode([CGFloat].self, from: posData), pos.count == 2 {
                    position = CGSize(width: pos[0], height: pos[1])
                } else {
                    position = defaultOffset
                }
                rotation = UserDefaults.standard.double(forKey: rotKey)
            }
        }
        .zIndex(Double(cardZIndex))
    }

    private var thumbtackCircle: some View {
        Group {
            if useIcecreamGradient {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.85, blue: 0.88),
                                Color(red: 0.95, green: 0.93, blue: 0.85),
                                Color(red: 0.85, green: 0.95, blue: 0.88),
                                Color(red: 0.75, green: 0.92, blue: 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                Circle()
                    .fill(thumbtackColor)
            }
        }
        .frame(width: thumbtackSize, height: thumbtackSize)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("myPage"))
            .updating($dragOffset) { value, state, _ in
                if state == .zero, value.translation != .zero {
                    let cb = onBringToTop
                    DispatchQueue.main.async { cb?() }
                }
                state = value.translation
            }
            .onEnded { value in
                var newX = position.width + value.translation.width
                var newY = position.height + value.translation.height
                if boundsReady {
                    newX = max(leftBound, min(rightBound, newX))
                    newY = max(topBound, min(bottomBound, newY))
                }
                position.width = newX
                position.height = newY
                if cardId != nil, let data = try? JSONEncoder().encode([position.width, position.height]) {
                    UserDefaults.standard.set(data, forKey: posKey)
                    if !userId.isEmpty {
                        UserSyncStore.shared.pushCardPositions(userId: userId)
                    }
                }
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($gestureRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                rotation += value.degrees
                if cardId != nil {
                    UserDefaults.standard.set(rotation, forKey: rotKey)
                    if !userId.isEmpty {
                        UserSyncStore.shared.pushCardPositions(userId: userId)
                    }
                }
            }
    }
}

// MARK: - MyPageView

/// 账号注销流程内部步骤
private enum DeleteAccountStep { case reason, confirm }

struct MyPageView: View {
    let username: String
    let diaries: [HappyDiaryData]
    let trips: [PackedTrip]
    let events: [EventsMatchEntry]
    var exhibitions: [ExhibitionRecord] = []
    var milestones: [MilestoneRecord] = []
    /// 底部 tab bar 占用的高度，ScrollView 底部按此内缩，避免内容被 tab bar 遮挡
    var bottomInset: CGFloat = 0
    @AppStorage("registered_user_id_v3") private var userId: String = ""
    @State private var selectedDiary: HappyDiaryData? = nil
    @State private var expandedTripId: UUID?
    @State private var selectedEvent: EventsMatchEntry?
    @State private var selectedExhibition: ExhibitionRecord?
    @State private var selectedMilestone: MilestoneRecord?
    @State private var showSettings = false
    @State private var topCardStack: [String] = []  // 置顶历史栈：末尾为最新置顶卡片，越靠后 zIndex 越大

    // 由 topCardStack 计算单张卡片的 zIndex（不在栈中 = 0）
    private func cardZIndex(_ id: String) -> Int {
        (topCardStack.lastIndex(of: id) ?? -1) + 1
    }
    // 由 topCardStack 计算某列 VStack 的 zIndex（取该列卡片在栈中的最大位置）
    private func columnZIndex(prefix: String) -> Int {
        (topCardStack.lastIndex(where: { $0.hasPrefix(prefix) }) ?? -1) + 1
    }
    // 把 cardId 推到栈顶（去重后追加）
    private func bringToTop(_ id: String) {
        topCardStack.removeAll { $0 == id }
        topCardStack.append(id)
    }
    @State private var decorativeLineY: CGFloat = 0   // 装饰线 midY（"myPage" 空间）= 卡片可上移上界
    @State private var contentBottomY: CGFloat = 0    // ScrollView 内容区底缘（"myPage" 空间）= tab bar 上缘 = 卡片可下移下界
    @State private var showAbout = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showHelpCenter = false
    @State private var showLanguage = false
    @AppStorage("app_language") private var appLanguage: String = "zh"
    @State private var expandedFAQ: Int? = nil
    @State private var showCacheAlert = false
    @State private var cacheMessage = ""
    @State private var showLogoutAlert = false
    // 账号注销流程
    @State private var showDeleteAccount = false
    @State private var deleteStep: DeleteAccountStep = .reason
    @State private var deleteReason: String? = nil
    @State private var deleteSubmitting = false
    @State private var deleteError: String? = nil
    // 留言表单
    @State private var feedbackEmail: String = ""
    @State private var feedbackMessage: String = ""
    @State private var feedbackEmailError: String? = nil
    @State private var feedbackSubmitting: Bool = false
    @State private var feedbackResultAlert: String? = nil
    @FocusState private var feedbackEmailFocused: Bool
    @FocusState private var feedbackMessageFocused: Bool

    private let dreamyPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
    private let brownText = Color(red: 0.40, green: 0.36, blue: 0.33)

    var body: some View {
        GeometryReader { pageGeo in
            let colW = (pageGeo.size.width - 24 - 24) / 5
            // ⚠️ ZStack(alignment: .center)：offset(x,y) 基准 = 屏幕中心点（W/2, H/2）
            //    传参给 PinableCard 的全部是相对中心偏移（不是绝对屏顶/屏左坐标）
            let screenCenterX = pageGeo.size.width / 2
            let screenCenterY = pageGeo.size.height / 2
            let leftPad: CGFloat = 24        // 左边缘安全边距（与原始 5 列视觉边距一致）
            let colSpacing: CGFloat = 6      // 列之间 spacing
            // 每列中心的绝对 X = leftPad + colW/2 + k*(colW+colSpacing)，k=0..4
            // 转相对中心偏移：绝对 X - screenCenterX
            let relX0 = leftPad + colW/2 - screenCenterX                         // 第1列
            let relX1 = relX0 + (colW + colSpacing)                              // 第2列
            let relX2 = relX1 + (colW + colSpacing)                              // 第3列（≈ 0，正中间）
            let relX3 = relX2 + (colW + colSpacing)                              // 第4列
            let relX4 = relX3 + (colW + colSpacing)                              // 第5列
            // X 轴拖动限制（相对中心偏移）：卡片中心距离屏幕左右缘各留 8pt 安全边
            let halfScreenX = screenCenterX
            let relLeftBound  = -halfScreenX + 8                                // ≈ -(W/2-8)
            let relRightBound =  halfScreenX - 8                                // ≈ +(W/2-8)
            // Y 轴：
            let relTop    = decorativeLineY - screenCenterY                     // 上限（≈ 负数）
            let relBottom = screenCenterY - bottomInset                          // 下限（≈ +H/2-76）
            let relCenter = pageGeo.size.height / 6 - screenCenterY             // 初值（屏幕上半部）
            let _ = {
                if decorativeLineY != 57 { decorativeLineY = 57 }
                let cb = pageGeo.size.height - bottomInset
                if cb > 0, contentBottomY != cb { contentBottomY = cb }
            }()
        ZStack(alignment: .center) {
            Color(red: 240/255, green: 238/255, blue: 233/255)
                .ignoresSafeArea()
                .task(id: pageGeo.size) {
                    decorativeLineY = 57
                    let cb = pageGeo.size.height - bottomInset
                    if cb > 0 { contentBottomY = cb }
                }

            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            // 第 1 列：心情信封卡片
            ForEach(Array(diaries.enumerated()), id: \.element.id) { idx, diary in
                PinableCard(
                    thumbtackColor: Color(red: 196/255, green: 178/255, blue: 232/255),
                    useIcecreamGradient: false,
                    allowTransform: false,
                    leftBound: relLeftBound, rightBound: relRightBound,
                    topBound: relTop, bottomBound: relBottom,
                    userId: userId,
                    cardId: "diary_\(diary.id.uuidString)",
                    cardZIndex: cardZIndex("diary_\(diary.id.uuidString)"),
                    onBringToTop: { bringToTop("diary_\(diary.id.uuidString)") },
                    defaultOffset: CGSize(width: relX0, height: relCenter + CGFloat(idx) * 80),
                    onCardTap: {
                        withAnimation(.easeInOut(duration: 0.4)) { selectedDiary = diary }
                    }
                ) { moodEnvelopeContent(diary: diary) }
                .zIndex(Double(columnZIndex(prefix: "diary_")))
            }

            // 第 2 列：旅行卡片
            ForEach(Array(trips.enumerated()), id: \.element.id) { idx, trip in
                PinableCard(
                    thumbtackColor: .clear, useIcecreamGradient: true, allowTransform: false,
                    leftBound: relLeftBound, rightBound: relRightBound,
                    topBound: relTop, bottomBound: relBottom,
                    userId: userId, cardId: "trip_\(trip.id)", cardZIndex: cardZIndex("trip_\(trip.id)"),
                    onBringToTop: { bringToTop("trip_\(trip.id)") },
                    defaultOffset: CGSize(width: relX1, height: relCenter + CGFloat(idx) * 150),
                    onCardTap: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedTripId = (expandedTripId == trip.id) ? nil : trip.id
                        }
                    }
                ) { tripCardContent(trip: trip) }
                .zIndex(Double(columnZIndex(prefix: "trip_")))
            }

            // 第 3 列：画展卡片
            ForEach(Array(exhibitions.enumerated()), id: \.element.name) { idx, exhibition in
                PinableCard(
                    thumbtackColor: Color(red: 146/255, green: 28/255, blue: 56/255),
                    useIcecreamGradient: false, allowTransform: false,
                    leftBound: relLeftBound, rightBound: relRightBound,
                    topBound: relTop, bottomBound: relBottom,
                    userId: userId, cardId: "exh_\(exhibition.name)", cardZIndex: cardZIndex("exh_\(exhibition.name)"),
                    onBringToTop: { bringToTop("exh_\(exhibition.name)") },
                    defaultOffset: CGSize(width: relX2, height: relCenter + CGFloat(idx) * 200),
                    onCardTap: {
                        withAnimation(.easeInOut(duration: 0.4)) { selectedExhibition = exhibition }
                    }
                ) { exhibitionCardContent(exhibition: exhibition) }
                .zIndex(Double(columnZIndex(prefix: "exh_")))
            }

            // 第 4 列：赛事卡片
            ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                PinableCard(
                    thumbtackColor: Color(red: 86/255, green: 142/255, blue: 198/255),
                    useIcecreamGradient: false, allowTransform: false,
                    leftBound: relLeftBound, rightBound: relRightBound,
                    topBound: relTop, bottomBound: relBottom,
                    userId: userId, cardId: "event_\(event.id)", cardZIndex: cardZIndex("event_\(event.id)"),
                    onBringToTop: { bringToTop("event_\(event.id)") },
                    defaultOffset: CGSize(width: relX3, height: relCenter + CGFloat(idx) * 120),
                    onCardTap: {
                        withAnimation(.easeInOut(duration: 0.4)) { selectedEvent = event }
                    }
                ) { eventCardContent(event: event) }
                .zIndex(Double(columnZIndex(prefix: "event_")))
            }

            // 第 5 列：里程碑卡片
            ForEach(Array(milestones.enumerated()), id: \.element.id) { idx, ms in
                let sandDollar = Color(red: 222/255, green: 205/255, blue: 190/255)
                PinableCard(
                    thumbtackColor: sandDollar, useIcecreamGradient: false, allowTransform: false,
                    leftBound: relLeftBound, rightBound: relRightBound,
                    topBound: relTop, bottomBound: relBottom,
                    userId: userId, cardId: "milestone_\(ms.id)", cardZIndex: cardZIndex("milestone_\(ms.id)"),
                    onBringToTop: { bringToTop("milestone_\(ms.id)") },
                    defaultOffset: CGSize(width: relX4, height: relCenter + CGFloat(idx) * 100),
                    onCardTap: {
                        withAnimation(.easeInOut(duration: 0.4)) { selectedMilestone = ms }
                    }
                ) { milestoneCardContent(milestone: ms) }
                .zIndex(Double(columnZIndex(prefix: "milestone_")))
            }

            // 标题：.position 强制屏中心(x=pageGeo.w/2)，绕开 VStack 对齐偏移
            // 总宽 280pt(与装饰线同宽)，左半区用户名+"'s " 右对齐，右半区"Days OFF" 左对齐
            // 中心 y = 35(header 中心)
            HStack(spacing: 0) {
                Text("\(username)'s ")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(brownText)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .trailing)

                Text("Days OFF")
                    .font(.custom("IowanOldStyle-Bold", size: 24))
                    .foregroundColor(brownText)
                    .frame(width: 140, alignment: .leading)
            }
            .position(x: pageGeo.size.width / 2, y: 35)

            // 装饰线：.position 强制屏中心(x=pageGeo.w/2)，绕开 VStack 对齐偏移
            // y=54 对齐标题下方(header 中心 35 + 19)，装饰线 midY 直接赋 54（在 GeometryReader 开头）
            Rectangle()
                .fill(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.55))
                .frame(width: 280, height: 0.6)
                .position(x: pageGeo.size.width / 2, y: 54)

            // 设置图标：左边缘对齐装饰线右边缘(屏中心+140)，垂直对齐标题中心
            // 中心 x = 屏中心 + 140(装饰线半宽) + 22(图标半宽)；y = 35(header 中心)
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(brownText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .position(x: pageGeo.size.width / 2 + 140 + 22, y: 35)

            if let diary = selectedDiary {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            selectedDiary = nil
                        }
                    }

                moodDiaryView(diary: diary)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            selectedDiary = nil
                        }
                    }
            }

            if let event = selectedEvent {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedEvent = nil
                        }
                    }

                eventPopupView(event: event)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedEvent = nil
                        }
                    }
            }

            if let exhibition = selectedExhibition {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedExhibition = nil
                        }
                    }

                exhibitionPopupView(exhibition: exhibition)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedExhibition = nil
                        }
                    }
            }

            if let ms = selectedMilestone {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedMilestone = nil
                        }
                    }

                milestonePopupView(ms)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1000)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedMilestone = nil
                        }
                    }
            }

            // 旅行弹窗：用 ZStack 包裹遮罩+内容作为整体，zIndex(1000) 确保盖过所有卡片
            if expandedTripId != nil, let trip = trips.first(where: { $0.id == expandedTripId }) {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTripId = nil
                            }
                        }

                    tripPopupView(trip: trip)
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                expandedTripId = nil
                            }
                        }
                }
                .zIndex(1000)
            }
        }
        .coordinateSpace(name: "myPage")
        }  // close GeometryReader
        .fullScreenCover(isPresented: $showSettings) { settingsSheet }
    }

    private func moodEnvelopeContent(diary: HappyDiaryData) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(diary.envelopeColor.color)
                .frame(width: 80, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(diary.envelopeColor.coverColor.opacity(0.4), lineWidth: 1)
                )

            Text(diary.date)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(diary.envelopeColor.dateTextColor)
                .offset(y: -10)

            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundColor(diary.envelopeColor.coverColor)
                .offset(y: 18)
        }
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private func moodDiaryView(diary: HappyDiaryData) -> some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Text(diary.date)
                    .font(.subheadline)
                    .foregroundColor(dreamyPurple.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dreamyPurple.opacity(0.1))
                    .cornerRadius(6)
            }

            ScrollView(.vertical, showsIndicators: false) {
                Text(diary.content1)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
            .frame(minHeight: 260)
        }
        .padding(24)
        .frame(width: 300, height: 340)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.8))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func tripCardContent(trip: PackedTrip) -> some View {
        let cardColors = trip.duplicateCardColors
        let textColor = cardColors?.text ?? Color(red: 0.45, green: 0.35, blue: 0.30)
        let gradientColors: [Color]
        if let c = cardColors {
            gradientColors = [c.top, c.mid, c.bottom]
        } else {
            gradientColors = [
                Color(red: 0.98, green: 0.94, blue: 0.78),
                Color(red: 0.70, green: 0.85, blue: 0.92)
            ]
        }
        return VStack(spacing: 2) {
            Text(wrapEvery5(trip.displayName))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let start = trip.startDate, let end = trip.endDate {
                Text(formatDateRange(start: start, end: end))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(textColor.opacity(cardColors != nil ? 0.85 : 0.7))
                    .lineLimit(1)
            }
        }
        .frame(width: 90, height: 68)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private func tripPopupView(trip: PackedTrip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：下一站 居左 + destination name 居中
            ZStack {
                HStack {
                    Text(L("下一站", "Next Stop"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33))
                    Spacer()
                }
                Text(trip.displayName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33))
            }

            // 第二行：时间（如有）
            if let start = trip.startDate, let end = trip.endDate {
                Text(formatDateRange(start: start, end: end))
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33).opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // 第三行起：每条灵感前用图钉 icon（替换原"旅行灵感N"文字）
            ForEach(trip.ideas, id: \.id) { idea in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // 图钉：银色长针 + very peri 色球
                    ZStack(alignment: .top) {
                        // 针：银色长垂直矩形（带金属渐变）
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.85, blue: 0.88),
                                        Color(red: 0.65, green: 0.65, blue: 0.70),
                                        Color(red: 0.50, green: 0.50, blue: 0.55)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 1.5, height: 14)
                            .offset(y: 8)
                        // 球：very peri (Pantone 17-3936, #6667AB)
                        Circle()
                            .fill(Color(red: 102/255, green: 103/255, blue: 171/255))
                            .frame(width: 11, height: 11)
                    }
                    .frame(width: 14, height: 22)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }

                    Text(idea.content)
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 250/255, green: 246/255, blue: 236/255))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.2), lineWidth: 0.5)
        )
        .zIndex(1)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func exhibitionCardContent(exhibition: ExhibitionRecord) -> some View {
        VStack(spacing: 4) {
            Text(L("画展", "Exhibition"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.gray)
            wrapEvery7(exhibition.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 107/255, green: 122/255, blue: 60/255))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 242/255, green: 216/255, blue: 205/255))
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private func eventCardContent(event: EventsMatchEntry) -> some View {
        VStack(spacing: 4) {
            Text(L("\(event.sport)比赛", "\(event.sport) Match"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 102/255, green: 103/255, blue: 171/255))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            wrapSmart(event.matchName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 102/255, green: 103/255, blue: 171/255))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 120)
        .background(
            Rectangle()
                .fill(Color(red: 240/255, green: 192/255, blue: 90/255))
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private func eventPopupView(event: EventsMatchEntry) -> some View {
        VStack(spacing: 10) {
            Text(event.sport)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))

            if !event.matchName.isEmpty {
                VStack(spacing: 4) {
                    Text(L("比赛名称", "Match Name"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.matchName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            if !event.matchTime.isEmpty {
                VStack(spacing: 4) {
                    Text(L("比赛时间", "Match Time"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.matchTime)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            if event.isScoreMatch && !event.team1.isEmpty {
                VStack(spacing: 4) {
                    Text(L("我支持的选手", "Supported Player"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.team1)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.92, green: 0.30, blue: 0.35))
                }
            } else if !event.team1.isEmpty || !event.team2.isEmpty {
                VStack(spacing: 4) {
                    Text(L("比赛双方", "Teams"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
                        // 左半：[爱心? 队伍1] 整体右对齐，爱心紧贴队伍1左侧
                        HStack(spacing: 2) {
                            if event.heartOnTeam == 1 {
                                Image(systemName: "heart")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 196/255, green: 178/255, blue: 232/255))
                            }
                            Text(event.team1.isEmpty ? "—" : event.team1)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        // VS 严格居中卡片中线
                        Text("VS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))
                            .fixedSize(horizontal: true, vertical: false)

                        // 右半：[队伍2 爱心?] 整体左对齐，爱心紧贴队伍2右侧
                        HStack(spacing: 2) {
                            Text(event.team2.isEmpty ? "—" : event.team2)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: true, vertical: false)
                            if event.heartOnTeam == 2 {
                                Image(systemName: "heart")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(red: 196/255, green: 178/255, blue: 232/255))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !event.freeText.isEmpty {
                VStack(spacing: 4) {
                    Text(L("备注", "Notes"))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.freeText)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 250/255, green: 246/255, blue: 236/255))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.2), lineWidth: 0.5)
        )
    }

    private func exhibitionPopupView(exhibition: ExhibitionRecord) -> some View {
        VStack(spacing: 12) {
            // 展览名称
            VStack(spacing: 4) {
                Text(L("展览名称", "Exhibition Name"))
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text(exhibition.name)
                    .font(.pingFang(size: 16, weight: .semibold))
                    .foregroundColor(dreamyPurple)
            }

            // 展览日期
            VStack(spacing: 4) {
                Text(L("展览日期", "Exhibition Date"))
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text("\(exhibition.startDate) - \(exhibition.endDate)")
                    .font(.pingFang(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }

            // 展览介绍
            VStack(spacing: 4) {
                Text(L("展览介绍", "Exhibition Intro"))
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text(exhibition.introduction)
                    .font(.pingFang(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 第一幅作品
            if let data = exhibition.firstPictureData,
               let uiImage = UIImage(data: data) {
                VStack(spacing: 4) {
                    Text(L("展览作品", "Artworks"))
                        .font(.pingFang(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 140)
                        .clipped()
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
    }

    private func milestoneCardContent(milestone ms: MilestoneRecord) -> some View {
        VStack(spacing: 4) {
            Text(ms.sportName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(L("我的里程碑", "Milestone"))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 110, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 123/255, green: 196/255, blue: 196/255))
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }

    private func milestonePopupView(_ ms: MilestoneRecord) -> some View {
        return VStack(spacing: 10) {
            // 第一行：计划完成
            Text(L("计划完成", "Plan Completed"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // 第二行：该计划的名字
            Text(ms.sportName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)

            // 第三行：日期
            Text(D(ms.date))
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.35, green: 0.32, blue: 0.30))

            // 第四行：加了🏆的笔记具体内容
            Text("🏆 " + ms.content)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(20)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 250/255, green: 246/255, blue: 236/255))
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.2), lineWidth: 0.5)
        )
    }

    private func myLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33))
            .frame(maxWidth: .infinity)
    }

    // MARK: - 设置
    private var settingsSheet: some View {
        GeometryReader { geo in
            NavigationStack {
                VStack(spacing: 0) {
                    // 顶部留白，将列表推至阅读舒适区（约屏幕上 1/3 处）
                    Spacer().frame(height: geo.size.height * 0.18)

                VStack(spacing: 0) {
                    Button(action: { showHelpCenter = true }) {
                        Text(L("帮助中心", "Help Center"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showLanguage = true }) {
                        Text("语言/Language")
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: {
                        cacheMessage = clearCaches()
                        showCacheAlert = true
                    }) {
                        Text(L("清除缓存", "Clear Cache"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showLogoutAlert = true }) {
                        Text(L("退出登录", "Log Out"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: {
                        deleteStep = .reason
                        deleteReason = nil
                        deleteError = nil
                        showDeleteAccount = true
                    }) {
                        Text(L("账号注销", "Delete Account"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.71, green: 0.27, blue: 0.24))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showAbout = true }) {
                        Text(L("关于我们", "About Us"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showPrivacy = true }) {
                        Text(L("隐私政策", "Privacy Policy"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showTerms = true }) {
                        Text(L("用户协议", "Terms of Use"))
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                )
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle(L("设置", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(isPresented: $showHelpCenter) { helpCenterPage }
            .sheet(isPresented: $showLanguage) { languagePage }
            .sheet(isPresented: $showAbout) { aboutPage }
            .sheet(isPresented: $showPrivacy) { privacyPage }
            .sheet(isPresented: $showTerms) { termsPage }
            .sheet(isPresented: $showDeleteAccount) { deleteAccountPage }
            .alert(L("清除缓存", "Clear Cache"), isPresented: $showCacheAlert) {
                Button(L("好的", "OK"), role: .cancel) {}
            } message: {
                Text(cacheMessage)
            }
            .alert(L("退出登录", "Log Out"), isPresented: $showLogoutAlert) {
                Button(L("取消", "Cancel"), role: .cancel) {}
                Button(L("确定", "Confirm"), role: .destructive) {
                    logout()
                }
            } message: {
                Text(L("确定要退出登录吗？本设备上的数据将被清除，重新登录后可从服务器恢复。", "Are you sure you want to log out? Data on this device will be cleared and can be restored from the server after re-login."))
            }
        }
        }
    }

    // MARK: - 语言设置
    private var languagePage: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                VStack(spacing: 0) {
                    Button(action: { appLanguage = "zh" }) {
                        HStack {
                            Text("中文")
                                .font(.pingFang(size: 17, weight: .medium))
                                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            Spacer()
                            if appLanguage == "zh" {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { appLanguage = "en" }) {
                        HStack {
                            Text("English")
                                .font(.pingFang(size: 17, weight: .medium))
                                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            Spacer()
                            if appLanguage == "en" {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                )
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("语言/Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLanguage = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }

    // MARK: - 退出登录
    private func logout() {
        let uid = userId
        let defaults = UserDefaults.standard

        // 清除已恢复标记，使下次登录能重新从服务器拉取数据
        if !uid.isEmpty {
            UserSyncStore.shared.clearRestoredState(userId: uid)
        }

        // 清除 ExhibitionStore 内存状态
        ExhibitionStore.shared.reset()

        // 清除该用户的内容数据（日记/旅行/比赛/里程碑），但保留卡片位置 card_pos_{uid}_*/card_rot_{uid}_*
        // 卡片位置按 userId 隔离，不会跨用户泄露；保留以便重新登录后恢复用户排列
        if !uid.isEmpty {
            for key in defaults.dictionaryRepresentation().keys {
                if key.contains(uid) && !key.hasPrefix("card_pos_") && !key.hasPrefix("card_rot_") {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        // 清除展览数据
        defaults.removeObject(forKey: "gallery_exhibition_history")

        // 清除登录信息
        defaults.set(false, forKey: "is_logged_in")
        defaults.removeObject(forKey: "registered_user_id_v3")
        defaults.removeObject(forKey: "registered_username_v3")

        // 关闭设置页并触发返回烟花登录页
        showSettings = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
        }
    }

    // MARK: - 账号注销

    private var deleteReasons: [String] {
        [
            L("无法修改用户名", "Cannot modify user name"),
            L("多余的账号", "Extra account"),
            L("安全与隐私顾虑", "Safety and privacy concerns"),
            L("其他原因", "Others")
        ]
    }

    private var deleteAccountPage: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                switch deleteStep {
                case .reason: deleteReasonView
                case .confirm: deleteConfirmView
                }
            }
            .navigationTitle(L("账号注销", "Delete Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if deleteStep == .confirm {
                        Button(L("返回", "Back")) {
                            deleteStep = .reason
                        }
                        .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.45))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("关闭", "Close")) {
                        showDeleteAccount = false
                    }
                    .foregroundColor(.gray)
                }
            }
            .alert(L("注销失败", "Deletion Failed"), isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button(L("好的", "OK"), role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    /// 第一步：选择注销原因
    private var deleteReasonView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)

            Text(L("请选择注销账号的原因", "Please select a reason for account deletion"))
                .font(.pingFang(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(deleteReasons.indices, id: \.self) { idx in
                    let reason = deleteReasons[idx]
                    Button {
                        deleteReason = reason
                    } label: {
                        HStack {
                            Text(reason)
                                .font(.pingFang(size: 16, weight: .regular))
                                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            Spacer()
                            Image(systemName: deleteReason == reason ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(deleteReason == reason ? Color(red: 0.71, green: 0.27, blue: 0.24) : Color(red: 0.75, green: 0.73, blue: 0.72))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    if idx < deleteReasons.count - 1 {
                        Divider().padding(.leading, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
            )
            .padding(.horizontal, 20)

            Spacer()

            Button(action: {
                deleteStep = .confirm
            }) {
                Text(L("下一步", "Next"))
                    .font(.pingFang(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(deleteReason == nil ? Color(red: 0.75, green: 0.73, blue: 0.72) : Color(red: 128/255, green: 0/255, blue: 32/255))
                    )
            }
            .disabled(deleteReason == nil)
            .padding(.bottom, 40)
        }
    }

    /// 第二步：确认注销
    private var deleteConfirmView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(Color(red: 0.71, green: 0.27, blue: 0.24))
                .padding(.bottom, 8)

            Text(L("账号注销后，所有数据将无法恢复。", "All data cannot be recovered after account deletion."))
                .font(.pingFang(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: performAccountDeletion) {
                HStack(spacing: 6) {
                    if deleteSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(deleteSubmitting ? "注销中…" : "确定")
                        .font(.pingFang(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 200, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(red: 128/255, green: 0/255, blue: 32/255))
                )
            }
            .disabled(deleteSubmitting)
            .padding(.bottom, 40)
        }
    }

    /// 调用后端 DELETE /users/me，成功后清本地数据并回登录页
    private func performAccountDeletion() {
        guard !deleteSubmitting else { return }
        deleteSubmitting = true
        let uid = userId

        Task {
            do {
                try await NetworkService.shared.deleteAccount(reason: deleteReason)
                await MainActor.run {
                    deleteSubmitting = false
                    // 服务器已删除该账号所有数据，清理本地状态
                    purgeAllLocalUserData(userId: uid)
                    showSettings = false
                    showDeleteAccount = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .daysOffSessionExpired, object: nil)
                    }
                }
            } catch let NetworkError.server(message) {
                await MainActor.run {
                    deleteSubmitting = false
                    deleteError = message
                }
            } catch {
                await MainActor.run {
                    deleteSubmitting = false
                    deleteError = "网络异常，请稍后再试"
                }
            }
        }
    }

    /// 账号注销成功后清理本机该用户的所有残留数据（UserDefaults + Keychain）
    private func purgeAllLocalUserData(userId uid: String) {
        let defaults = UserDefaults.standard

        // 清除云端已恢复标记
        if !uid.isEmpty {
            UserSyncStore.shared.clearRestoredState(userId: uid)
        }

        // 清除 ExhibitionStore 内存状态
        ExhibitionStore.shared.reset()

        // 清除所有包含用户 ID 的 UserDefaults 键
        if !uid.isEmpty {
            for key in defaults.dictionaryRepresentation().keys {
                if key.contains(uid) {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        // 清除卡片位置/旋转
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("card_pos_") || key.hasPrefix("card_rot_") {
                defaults.removeObject(forKey: key)
            }
        }

        // 清除展览本地缓存
        defaults.removeObject(forKey: "gallery_exhibition_history")

        // 清除登录信息
        defaults.set(false, forKey: "is_logged_in")
        defaults.removeObject(forKey: "registered_user_id_v3")
        defaults.removeObject(forKey: "registered_username_v3")

        // 清除 Keychain 中的登录令牌与 E2EE 密钥
        if !uid.isEmpty {
            TokenStore.clear(userId: uid)
            CryptoBox.clear(userId: uid)
        }

        // 清除网络服务内存令牌
        NetworkService.shared.authToken = nil
    }

    // MARK: - 帮助中心
    private var helpCenterPage: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { index in
                            FAQRow(
                                question: faqQuestion(for: index),
                                answer: faqAnswer(for: index),
                                isExpanded: expandedFAQ == index,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedFAQ = expandedFAQ == index ? nil : index
                                    }
                                }
                            )
                            if index < 5 {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // 社群守则
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("社群守则", "Community Guidelines"))
                            .font(.pingFang(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))

                        Text(L("请与我们共同努力打造一个真实、安全的社群，始终遵守相关法律，尊重社群中的其他成员。", "Let's work together to build a genuine and safe community, always abide by relevant laws, and respect other members."))
                            .font(.pingFang(size: 14, weight: .regular))
                            .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.45))
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(L("帮助中心", "Help Center"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("关闭", "Close")) { showHelpCenter = false }
                }
            }
        }
    }

    private func faqQuestion(for index: Int) -> String {
        switch index {
        case 0: return L("使用首页白色心情宝石", "White Mood Gems on the Home Screen")
        case 1: return L("使用手记功能", "Using the Journal Feature")
        case 2: return L("使用旅行功能", "Using the Travel Feature")
        case 3: return L("使用创作功能", "Using the Create Feature")
        case 4: return L("使用运动功能", "Using the Sports Feature")
        case 5: return L("我的DaysOFF", "My DaysOFF")
        default: return ""
        }
    }

    private func faqAnswer(for index: Int) -> String {
        switch index {
        case 0:
            return L(
                "点击首页中央十六颗白色心情宝石，选择你当下的心情，将它拖到上方的彩色相框中吧。如果现在心情不好，彩色相框旁会出现粉色爱心，点击它，给自己换个心情。选择心情之后，就可以点击下方四颗彩色功能宝石。",
                "Tap the 16 white mood gems in the center of the home screen, choose how you feel right now, and drag it up into the colored frame above. If you're not in a good mood, a pink heart will appear next to the frame — tap it to switch your mood. Once a mood is selected, you can tap the four colored function gems below."
            )
        case 1:
            return L(
                "在屏幕中央的信纸上写下此刻的心情，也可以点击日期旁边的麦克风语音输入，写完后点击下方信封图标，将心中的话语保存给未来的自己看。",
                "On the paper in the center of the screen, write down how you feel right now. You can also tap the microphone next to the date for voice input. When you're done, tap the envelope icon below to save your words for your future self to read."
            )
        case 2:
            return L(
                "点击新的旅行灵感按钮，是想去看音乐节，还是想去海岛晒太阳，还没有具体的旅行规划也没关系，把此刻的旅行灵感记录下来，看着目的地的清单越来越长，是时候订下机酒，按下准备出发键，开启快乐旅行啦！",
                "Tap the \"New Travel Inspiration\" button. Whether you want to go to a music festival or soak up the sun on an island, it doesn't matter if you don't have a concrete plan yet — just capture the inspiration of the moment. Watch your list of destinations grow longer and longer; when it's time to book flights and hotels, hit the \"Ready to Go\" button and start your happy journey!"
            )
        case 3:
            return L(
                "绘画、书法、手工、陶艺、厨艺，上传任何你精心创作的作品吧。作品逐渐积累之后，还可以亲自策划一个主题展览，添加介绍文字，分享给社群小伙伴限时参观。",
                "Painting, calligraphy, handicraft, pottery, culinary — upload anything you've thoughtfully created. As your works accumulate, you can also personally curate a themed exhibition, add an introduction, and share it with the community for a limited time."
            )
        case 4:
            return L(
                "在这里记录下你特别关注的体育赛事，或是添加运动计划，写下自己的运动笔记。坚持运动的你，可以看到自己的变化！",
                "Here you can record the sports matches you especially care about, add your own workout plans, and write your exercise notes. Keep moving — you'll see your own progress!"
            )
        case 5:
            return L(
                "在我的页面查看所有累积的快乐回忆：心情记录，旅行计划，创作展览，赛事关注，运动计划。将色彩缤纷的卡片拖动到想要的位置，创造属于你的独一无二界面。将休息日的时光认真收藏。",
                "On the \"My\" page, look back at all the happy memories you've gathered: mood records, travel plans, artwork exhibitions, followed matches, and workout plans. Drag the colorful cards to wherever you like, and create a layout that's uniquely yours. Treasure your Days OFF moments."
            )
        default: return ""
        }
    }

    private var aboutPage: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        // 上半屏：三行信息卡片（比例缩小，让下方留言表单整体上移更多）
                        VStack(spacing: 0) {
                            Color.clear.frame(height: geo.size.height * 0.10)
                            VStack(spacing: 0) {
                                aboutRow(label: L("本应用名称", "Name of the App"), value: "Days OFF")
                                Divider().padding(.leading, 20)
                                aboutRow(label: L("版本号", "Version"), value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.1")
                                Divider().padding(.leading, 20)
                                aboutRow(label: L("发布时间", "Release Date"), value: "2026.9.27")
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                            )
                            .padding(.horizontal, 20)
                            Spacer(minLength: 0)
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height * 0.40, 0), alignment: .top)

                        // 中间空行
                        Color.clear.frame(height: 8)

                        // 下半屏：留言表单贴顶（比例放大，使整体位置上移）
                        VStack(spacing: 0) {
                            feedbackFormCard
                            Spacer(minLength: 0)

                            // 底部备案与版权信息
                            VStack(spacing: 6) {
                                Text(L("ICP备案信息：苏ICP备2026061232号-2A", "ICP Registration: 苏ICP备2026061232号-2A"))
                                    .font(.pingFang(size: 11))
                                    .foregroundColor(Color(red: 0.55, green: 0.52, blue: 0.48))
                                Text("Copyright © 2026 Days OFF. All Rights Reserved.")
                                    .font(.pingFang(size: 11))
                                    .foregroundColor(Color(red: 0.55, green: 0.52, blue: 0.48))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height * 0.60, 0), alignment: .top)
                    }
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(L("关于我们", "About Us"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("关闭", "Close")) { showAbout = false }
                }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(get: { feedbackResultAlert != nil }, set: { if !$0 { feedbackResultAlert = nil } })) {
                Button(L("好的", "OK")) {
                    let msg = feedbackResultAlert
                    feedbackResultAlert = nil
                    if msg == "提交成功，感谢您的留言！" {
                        feedbackEmail = ""
                        feedbackMessage = ""
                        feedbackEmailError = nil
                    }
                }
            } message: {
                Text(feedbackResultAlert ?? "")
            }
        }
    }

    /// 留言表单卡片
    private var feedbackFormCard: some View {
        VStack(spacing: 0) {
            // 标题
            Text(L("给我们留言", "Leave a Message"))
                .font(.pingFang(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // 邮箱行：左侧「您的邮箱（必填）」+ 右侧输入框
            HStack(spacing: 8) {
                Text(L("您的邮箱（必填）", "Your Email (Required)"))
                    .font(.pingFang(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                    .lineLimit(1)

                TextField("example@mail.com", text: $feedbackEmail)
                    .font(.pingFang(size: 14, weight: .regular))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($feedbackEmailFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.96, green: 0.95, blue: 0.93))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(feedbackEmailError != nil ? Color(red: 0.71, green: 0.27, blue: 0.24) : Color.clear, lineWidth: 1)
                    )
                    .onChange(of: feedbackEmail) { _, _ in
                        if feedbackEmailError != nil { feedbackEmailError = nil }
                    }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            // 邮箱格式错误提示
            if let err = feedbackEmailError {
                Text(err)
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(Color(red: 0.71, green: 0.27, blue: 0.24))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            // 大输入框：用户意见
            ZStack(alignment: .topLeading) {
                if feedbackMessage.isEmpty && !feedbackMessageFocused {
                    Text(L("请写下您的意见或建议…", "Please write your comments or suggestions…"))
                        .font(.pingFang(size: 14, weight: .regular))
                        .foregroundColor(Color(red: 0.60, green: 0.56, blue: 0.55))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $feedbackMessage)
                    .font(.pingFang(size: 14, weight: .regular))
                    .focused($feedbackMessageFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .frame(minHeight: 120)
                    .background(Color.clear)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.96, green: 0.95, blue: 0.93))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // 提交按钮：与注册/登录按钮相同样式（勃艮第酒红填充胶囊）
            Button(action: submitFeedbackForm) {
                HStack(spacing: 6) {
                    if feedbackSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(feedbackSubmitting ? L("提交中…", "Submitting…") : L("提交", "Submit"))
                        .font(.pingFang(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 200, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(canSubmitFeedback ? Color(red: 128/255, green: 0/255, blue: 32/255) : Color(red: 0.75, green: 0.73, blue: 0.72))
                )
            }
            .disabled(!canSubmitFeedback || feedbackSubmitting)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
        )
        .padding(.horizontal, 20)
    }

    /// 邮箱格式校验
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email.trimmingCharacters(in: .whitespaces))
    }

    /// 提交按钮可点条件：邮箱和意见都非空、不在提交中（邮箱格式在点击时校验并弹出提示）
    private var canSubmitFeedback: Bool {
        let email = feedbackEmail.trimmingCharacters(in: .whitespaces)
        let msg = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return !email.isEmpty && !msg.isEmpty
    }

    /// 提交留言表单
    private func submitFeedbackForm() {
        let email = feedbackEmail.trimmingCharacters(in: .whitespaces)
        let msg = feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        // 邮箱格式校验
        if !isValidEmail(email) {
            feedbackEmailError = "邮箱格式不正确，请检查后重新填写"
            return
        }
        if msg.isEmpty {
            feedbackResultAlert = "请填写您的意见后再提交"
            return
        }

        feedbackEmailError = nil
        feedbackSubmitting = true
        Task {
            do {
                try await NetworkService.shared.submitFeedback(email: email, message: msg)
                await MainActor.run {
                    feedbackSubmitting = false
                    feedbackResultAlert = "提交成功，感谢您的留言！"
                }
            } catch let NetworkError.server(message) {
                await MainActor.run {
                    feedbackSubmitting = false
                    feedbackResultAlert = message
                }
            } catch {
                await MainActor.run {
                    feedbackSubmitting = false
                    feedbackResultAlert = "网络异常，请稍后再试"
                }
            }
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.pingFang(size: 16, weight: .medium))
                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))

            Spacer()

            Text(value)
                .font(.pingFang(size: 16, weight: .regular))
                .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.45))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var privacyPage: some View {
        NavigationStack {
            ScrollView {
                Text(privacyPolicyText)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle(L("隐私政策", "Privacy Policy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("关闭", "Close")) { showPrivacy = false }
                }
            }
        }
    }

    private var termsPage: some View {
        NavigationStack {
            ScrollView {
                Text(userAgreementText)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle(L("用户协议", "Terms of Use"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("关闭", "Close")) { showTerms = false }
                }
            }
        }
    }

    private func clearCaches() -> String {
        var freed = Int64(URLCache.shared.currentDiskUsage)
        URLCache.shared.removeAllCachedResponses()
        let fm = FileManager.default
        let dirs = [fm.urls(for: .cachesDirectory, in: .userDomainMask).first, URL(fileURLWithPath: NSTemporaryDirectory())].compactMap { $0 }
        for dir in dirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items {
                freed += Int64((try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                try? fm.removeItem(at: item)
            }
        }
        return "已释放 \(String(format: "%.1f", Double(freed) / 1024 / 1024)) MB 空间"
    }

    private var privacyPolicyText: String {
        L(
            """
            生效日期：2026.9.17

            欢迎使用Days OFF（以下简称"本应用"）。我们非常重视您的隐私保护，请您在使用本应用前仔细阅读本政策。

            一、我们收集的信息
            1. 您主动提供的信息：注册账号时填写的用户名；您的密码仅以不可逆哈希形式存储，我们无法获知您的明文密码。
            2. 您创作的内容：心情手记、运动笔记与运动计划、旅行卡片、赛事卡片、上传的作品，以及您发布的展览与旅行灵感。
            3. 匿名统计信息：注册数量、每日活跃、异常退出与网络错误等统计数据，均以匿名方式汇总，不包含任何可识别您个人身份的信息。

            二、端到端加密
            您的心情手记、运动笔记、运动计划、旅行卡片、赛事卡片及未公开的作品，均在您的设备上使用由您的密码派生的密钥加密后才会上传云端。服务器仅存储加密后的密文，包括我们在内的任何人都无法查看这些内容。
            请您知悉：由于加密密钥仅由您的密码在您的设备上派生，我们也无法获知或重置该密钥。若您忘记密码，上述加密内容将无法恢复，请您妥善保管密码。

            三、公开内容
            您主动发布的展览、旅行灵感及公开作品属于公开内容，将以明文形式存储并向其他用户展示，以便我们依法履行内容审核义务。请您勿在公开内容中填写个人敏感信息。

            四、信息的使用
            我们仅将收集的信息用于：提供与维护本应用服务（包括多设备云同步）、改进和优化产品、保障账号与数据安全。

            五、信息的存储
            您的信息存储于您的设备本地或我们委托的安全服务器中；私密内容以密文形式存储，保存期限为实现本政策目的所必需的最短时间。

            六、信息的共享与披露
            我们不会向任何第三方出售您的个人信息。仅在获得您的明确同意，或法律法规要求时，我们才会共享或披露您的信息。

            七、信息安全
            我们采取合理的管理和技术措施保护您的信息，包括传输加密（HTTPS）、密码哈希存储、私密内容端到端加密，防止丢失、滥用或未经授权的访问。

            八、您的权利
            您有权访问、更正、删除您的个人信息，并有权注销账号。相关操作可在应用内完成，或通过文末方式联系我们。

            九、未成年人保护
            本应用不面向十四周岁以下儿童提供服务，我们不会故意收集儿童的个人信息。

            十、政策更新
            我们可能适时修订本政策，更新后将在本页面公布，重大变更将以显著方式通知您。

            十一、联系我们
            如对本政策有任何疑问或建议，请通过 support@daysoff-app.com 与我们联系。
            """,
            """
            Effective Date: 2026.9.17

            Welcome to Days OFF (hereinafter "the App"). We take your privacy very seriously. Please read this policy carefully before using the App.

            I. Information We Collect
            1. Information you actively provide: the username you enter when registering your account; your password is stored only as an irreversible hash, and we cannot know your plaintext password.
            2. Content you create: mood journal entries, sports notes and sports plans, travel cards, match cards, uploaded artworks, as well as the exhibitions and travel inspirations you publish.
            3. Anonymous statistics: registration counts, daily active users, abnormal exits, and network errors, all aggregated anonymously without any information that could personally identify you.

            II. End-to-End Encryption
            Your mood journal entries, sports notes, sports plans, travel cards, match cards, and unpublished artworks are encrypted on your device using a key derived from your password before being uploaded to the cloud. The server stores only the encrypted ciphertext, and no one, including us, can view these contents.
            Please note: Because the encryption key is derived only from your password on your device, we cannot know or reset it either. If you forget your password, the above encrypted content cannot be recovered — please keep your password safe.

            III. Public Content
            Exhibitions, travel inspirations, and public artworks that you actively publish are considered public content. They are stored in plaintext and displayed to other users so that we can fulfill our legal content review obligations. Please do not include sensitive personal information in public content.

            IV. Use of Information
            We use the collected information only to: provide and maintain the App's services (including multi-device cloud sync), improve and optimize the product, and safeguard account and data security.

            V. Storage of Information
            Your information is stored locally on your device or on secure servers we entrust; private content is stored as ciphertext, with retention limited to the minimum period necessary to fulfill the purposes of this policy.

            VI. Sharing and Disclosure of Information
            We will not sell your personal information to any third party. We will only share or disclose your information with your explicit consent, or when required by laws and regulations.

            VII. Information Security
            We take reasonable administrative and technical measures to protect your information, including encrypted transmission (HTTPS), hashed password storage, and end-to-end encryption of private content, to prevent loss, misuse, or unauthorized access.

            VIII. Your Rights
            You have the right to access, correct, and delete your personal information, and the right to delete your account. These actions can be completed within the App, or you can contact us through the methods listed at the end.

            IX. Protection of Minors
            This App does not provide services to children under the age of fourteen, and we do not intentionally collect personal information from children.

            X. Policy Updates
            We may revise this policy from time to time. Updates will be published on this page, and significant changes will be notified to you in a prominent manner.

            XI. Contact Us
            If you have any questions or suggestions about this policy, please contact us at support@daysoff-app.com.
            """
        )
    }

    private var userAgreementText: String {
        L(
            """
            生效日期：2026.9.17

            欢迎使用 Days OFF（以下简称"本应用"）。请您在使用本应用前仔细阅读并同意本《用户协议》。您注册、登录或使用本应用即视为您已充分理解并同意本协议全部条款。

            一、账号与注册
            1. 您需自行注册账号并设置密码，密码经 SHA-256 加盐哈希后存储，本应用不会以明文形式保存您的密码。
            2. 为保障服务稳定与安全，注册接口限每 IP 每小时 5 次，登录接口限每 IP 每 5 分钟 10 次，超出将被暂时拒绝。
            3. 您应妥善保管账号与密码，因您泄露、转让或授权他人使用而导致的损失由您自行承担。

            二、服务内容
            本应用为您提供以下功能及对应的数据处理：
            1. 心情日记与运动记录（运动计划、运动笔记、三格文字、奖杯）；
            2. 旅行灵感记录与赛事信息；
            3. 画廊作品的上传与展示；
            4. 里程碑记录与"我的"页面卡片管理；
            5. 上述数据在您登录后将同步至云端服务器，便于您在更换设备或重装应用后恢复。

            三、用户行为规范
            您承诺不通过本应用从事下列行为：
            1. 上传、存储或传播违反法律法规或公序良俗的内容；
            2. 利用本应用从事侵害他人知识产权、肖像权、隐私权等合法权益的行为；
            3. 对本应用服务器进行恶意攻击、爬取、刷量或干扰正常服务；
            4. 未经授权访问他人数据或共享自身账号给他人用于商业用途。

            四、内容与知识产权
            1. 您上传的文字、图片等内容（以下简称"用户内容"）知识产权归您或原权利人所有。
            2. 您授予本应用非排他、无偿、可转授权的全球性许可，仅用于在本应用内展示、同步、备份及改进服务所必需的处理。
            3. 您应保证上传的用户内容不侵犯任何第三方合法权益，否则由您自行承担全部法律责任。

            五、服务的变更、中断与终止
            1. 本应用可能因系统维护、升级等原因暂停服务，并将尽量提前公告。
            2. 如您违反本协议，本应用有权限制、暂停或终止您的账号使用。
            3. 您可随时通过"退出登录"清除本地数据并停止使用；账号注销可在"设置"中自助操作完成。

            六、免责声明
            1. 本应用提供"按现状"服务，不就服务的连续性、安全性、准确性作出任何明示或默示的保证。
            2. 因不可抗力、第三方服务（如云存储、网络运营商）故障导致的损失，本应用在法律允许范围内不承担责任。

            七、协议更新
            本协议可能适时修订，更新后将在本页面公布；如您在修订后继续使用本应用，即视为同意修订后的协议。

            八、联系我们
            如对本协议有任何疑问或建议，请通过 support@daysoff-app.com 与我们联系。
            """,
            """
            Effective Date: 2026.9.17

            Welcome to Days OFF (hereinafter "the App"). Please read and agree to these Terms of Use carefully before using the App. By registering, logging in, or using the App, you are deemed to have fully understood and agreed to all terms of this agreement.

            I. Account and Registration
            1. You must register your own account and set a password. The password is hashed with SHA-256 and salt before storage; the App does not save your password in plaintext.
            2. To ensure service stability and security, the registration endpoint is limited to 5 requests per IP per hour, and the login endpoint is limited to 10 requests per IP every 5 minutes. Exceeding these limits will result in temporary rejection.
            3. You should keep your account and password safe. Any losses caused by your disclosure, transfer, or authorization of others to use them shall be borne by you.

            II. Service Content
            The App provides the following features and corresponding data processing:
            1. Mood journal and sports records (sports plans, sports notes, three-section text, trophies);
            2. Travel inspiration records and match information;
            3. Upload and display of gallery artworks;
            4. Milestone records and "My" page card management;
            5. The above data will be synced to the cloud server after you log in, allowing recovery when you change devices or reinstall the App.

            III. User Conduct
            You agree not to engage in any of the following behaviors through the App:
            1. Uploading, storing, or distributing content that violates laws, regulations, or public order and good morals;
            2. Using the App to infringe on the intellectual property, portrait rights, privacy rights, or other legitimate rights and interests of others;
            3. Launching malicious attacks, scraping, artificially inflating traffic, or otherwise interfering with the normal operation of the App's servers;
            4. Accessing others' data without authorization, or sharing your account with others for commercial purposes.

            IV. Content and Intellectual Property
            1. The intellectual property rights of text, images, and other content you upload (hereinafter "User Content") belong to you or the original rights holder.
            2. You grant the App a non-exclusive, royalty-free, globally sublicensable license, solely for the processing necessary to display, sync, back up, and improve the services within the App.
            3. You warrant that the User Content you upload does not infringe on any legitimate rights of any third party; otherwise, you shall bear all legal responsibilities.

            V. Changes, Interruptions, and Termination of Services
            1. The App may suspend services due to system maintenance, upgrades, or other reasons, and will try to announce in advance.
            2. If you violate this agreement, the App reserves the right to limit, suspend, or terminate your account access.
            3. You can clear local data and stop using the App at any time through "Log Out"; account deletion can be completed within "Settings".

            VI. Disclaimer
            1. The App provides services on an "as is" basis, without any express or implied warranties regarding the continuity, security, or accuracy of the services.
            2. The App shall not be liable, to the extent permitted by law, for losses caused by force majeure or failures of third-party services (such as cloud storage, network operators).

            VII. Agreement Updates
            This agreement may be revised from time to time, and updates will be published on this page. If you continue to use the App after the revision, you are deemed to agree to the revised agreement.

            VIII. Contact Us
            If you have any questions or suggestions about this agreement, please contact us at support@daysoff-app.com.
            """
        )
    }
}

// MARK: - FAQ Row (常见问题行)

private struct FAQRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Text(question)
                        .font(.pingFang(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.55))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(answer)
                    .font(.pingFang(size: 14, weight: .regular))
                    .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.45))
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .padding(.top, 4)
            }
        }
    }
}
