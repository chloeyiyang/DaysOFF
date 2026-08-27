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
                    Text("下一站")
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
            Text("画展")
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
            Text("\(event.sport)比赛")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(red: 102/255, green: 103/255, blue: 171/255))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            wrapEvery6(event.matchName)
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
                    Text("比赛名称")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.matchName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            if !event.matchTime.isEmpty {
                VStack(spacing: 4) {
                    Text("比赛时间")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.matchTime)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            if event.isScoreMatch && !event.team1.isEmpty {
                VStack(spacing: 4) {
                    Text("我支持的选手")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.team1)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.92, green: 0.30, blue: 0.35))
                }
            } else if !event.team1.isEmpty || !event.team2.isEmpty {
                VStack(spacing: 4) {
                    Text("比赛双方")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
                        Text(event.team1.isEmpty ? "—" : event.team1)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Text("VS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))
                        Text(event.team2.isEmpty ? "—" : event.team2)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }

            if !event.freeText.isEmpty {
                VStack(spacing: 4) {
                    Text("备注")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(event.freeText)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
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
                Text("展览名称")
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text(exhibition.name)
                    .font(.pingFang(size: 16, weight: .semibold))
                    .foregroundColor(dreamyPurple)
            }

            // 展览日期
            VStack(spacing: 4) {
                Text("展览日期")
                    .font(.pingFang(size: 12, weight: .regular))
                    .foregroundColor(.gray)
                Text("\(exhibition.startDate) - \(exhibition.endDate)")
                    .font(.pingFang(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }

            // 展览介绍
            VStack(spacing: 4) {
                Text("展览介绍")
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
                    Text("展览作品")
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
            Text("我的里程碑")
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
            Text("计划完成")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // 第二行：该计划的名字
            Text(ms.sportName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)

            // 第三行：日期
            Text(ms.date)
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
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部留白，将列表推至阅读舒适区（约屏幕上 1/3 处）
                Spacer().frame(height: UIScreen.main.bounds.height * 0.18)

                VStack(spacing: 0) {
                    Button(action: { showHelpCenter = true }) {
                        Text("帮助中心")
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
                        Text("清除缓存")
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showLogoutAlert = true }) {
                        Text("退出登录")
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
                        Text("账号注销")
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.71, green: 0.27, blue: 0.24))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showAbout = true }) {
                        Text("关于我们")
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showPrivacy = true }) {
                        Text("隐私政策")
                            .font(.pingFang(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }

                    Divider().padding(.leading, 20)

                    Button(action: { showTerms = true }) {
                        Text("用户协议")
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
            .navigationTitle("设置")
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
            .sheet(isPresented: $showAbout) { aboutPage }
            .sheet(isPresented: $showPrivacy) { privacyPage }
            .sheet(isPresented: $showTerms) { termsPage }
            .sheet(isPresented: $showDeleteAccount) { deleteAccountPage }
            .alert("清除缓存", isPresented: $showCacheAlert) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(cacheMessage)
            }
            .alert("退出登录", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) {}
                Button("确定", role: .destructive) {
                    logout()
                }
            } message: {
                Text("确定要退出登录吗？本设备上的数据将被清除，重新登录后可从服务器恢复。")
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

    private let deleteReasons: [String] = [
        "无法修改用户名",
        "多余的账号",
        "安全与隐私顾虑",
        "其他原因"
    ]

    private var deleteAccountPage: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                switch deleteStep {
                case .reason: deleteReasonView
                case .confirm: deleteConfirmView
                }
            }
            .navigationTitle("账号注销")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if deleteStep == .confirm {
                        Button("返回") {
                            deleteStep = .reason
                        }
                        .foregroundColor(Color(red: 0.45, green: 0.42, blue: 0.45))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showDeleteAccount = false
                    }
                    .foregroundColor(.gray)
                }
            }
            .alert("注销失败", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("好的", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    /// 第一步：选择注销原因
    private var deleteReasonView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)

            Text("请选择注销账号的原因")
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
                Text("下一步")
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

            Text("账号注销后，所有数据将无法恢复。")
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
                        Text("社群守则")
                            .font(.pingFang(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))

                        Text("请与我们共同努力打造一个真实、安全的社群，始终遵守相关法律，尊重社群中的其他成员。")
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
            .navigationTitle("帮助中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showHelpCenter = false }
                }
            }
        }
    }

    private func faqQuestion(for index: Int) -> String {
        switch index {
        case 0: return "使用首页白色心情宝石"
        case 1: return "使用手记功能"
        case 2: return "使用旅行功能"
        case 3: return "使用创作功能"
        case 4: return "使用运动功能"
        case 5: return "我的DaysOFF"
        default: return ""
        }
    }

    private func faqAnswer(for index: Int) -> String {
        switch index {
        case 0:
            return "点击首页中央十六颗白色心情宝石，选择你当下的心情，将它拖到上方的彩色相框中吧。如果现在心情不好，彩色相框旁会出现粉色爱心，点击它，给自己换个心情。选择心情之后，就可以点击下方四颗彩色功能宝石。"
        case 1:
            return "在屏幕中央的信纸上写下此刻的心情，也可以点击日期旁边的麦克风语音输入，写完后点击下方信封图标，将心中的话语保存给未来的自己看。"
        case 2:
            return "点击新的旅行灵感按钮，是想去看音乐节，还是想去海岛晒太阳，还没有具体的旅行规划也没关系，把此刻的旅行灵感记录下来，看着目的地的清单越来越长，是时候订下机酒，按下准备出发键，开启快乐旅行啦！"
        case 3:
            return "绘画、书法、手工、陶艺、厨艺，上传任何你精心创作的作品吧。作品逐渐积累之后，还可以亲自策划一个主题展览，添加介绍文字，分享给社群小伙伴限时参观。"
        case 4:
            return "在这里记录下你特别关注的体育赛事，或是添加运动计划，写下自己的运动笔记。坚持运动的你，可以看到自己的变化！"
        case 5:
            return "在我的页面查看所有累积的快乐回忆：心情记录，旅行计划，创作展览，赛事关注，运动计划。将色彩缤纷的卡片拖动到想要的位置，创造属于你的独一无二界面。将休息日的时光认真收藏。"
        default: return ""
        }
    }

    private var aboutPage: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        // 上半屏：信息卡片贴底，使 24pt 空行落在屏幕垂直中心
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(spacing: 0) {
                                aboutRow(label: "本应用名称", value: "Days OFF")
                                Divider().padding(.leading, 20)
                                aboutRow(label: "版本号", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3")
                                Divider().padding(.leading, 20)
                                aboutRow(label: "发布时间", value: "2026年8月")
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                            )
                            .padding(.horizontal, 20)
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height / 2 - 12, 0), alignment: .bottom)

                        // 中间空行（位于屏幕中间）
                        Color.clear.frame(height: 24)

                        // 下半屏：留言表单贴顶
                        VStack(spacing: 0) {
                            feedbackFormCard
                            Spacer(minLength: 0)
                        }
                        .frame(width: geo.size.width, height: max(geo.size.height / 2 - 12, 0), alignment: .top)
                    }
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("关于我们")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showAbout = false }
                }
            }
            .alert("提示", isPresented: Binding(get: { feedbackResultAlert != nil }, set: { if !$0 { feedbackResultAlert = nil } })) {
                Button("好的") {
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
            Text("给我们留言")
                .font(.pingFang(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.30, green: 0.28, blue: 0.32))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            // 邮箱行：左侧「您的邮箱（必填）」+ 右侧输入框
            HStack(spacing: 8) {
                Text("您的邮箱（必填）")
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
                    Text("请写下您的意见或建议…")
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
                    Text(feedbackSubmitting ? "提交中…" : "提交")
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
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showPrivacy = false }
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
            .navigationTitle("用户协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showTerms = false }
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

    private let privacyPolicyText = """
    生效日期：2026年8月25日

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
    """

    private let userAgreementText = """
    生效日期：2026年8月25日

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
    """
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
