//
//  DaysOffApp.swift
//  DaysOff
//

import SwiftUI

// 统一中文字体为 PingFang SC
extension Font {
    static func pingFang(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "PingFangSC-Medium"
        case .semibold: name = "PingFangSC-Semibold"
        case .bold: name = "PingFangSC-Bold"
        case .light: name = "PingFangSC-Light"
        case .heavy: name = "PingFangSC-Heavy"
        default: name = "PingFangSC-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Mock Users

struct MockUser: Identifiable {
    let id: String
    let name: String
    let color: Color
}

let mockUsers: [MockUser] = [
    MockUser(id: "user1", name: "User 1", color: .blue),
]

@main
struct DaysOffApp: App {
    init() {
        // NSException 崩溃兜底：记录异常信息，下次启动随 abnormal_exit 上报
        NSSetUncaughtExceptionHandler { e in
            AppStats.recordCrashDetail("\(e.name.rawValue): \(e.reason ?? "")")
        }
        // 将耗时的初始化工作放到后台队列，避免阻塞主线程导致启动卡顿
        DispatchQueue.global(qos: .background).async {
            Self.clearExistingExhibitionsIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            MultiUserTabView()
        }
    }

    // 一次性清除所有已存在的展览数据
    private static func clearExistingExhibitionsIfNeeded() {
        let flagKey = "exhibitions_cleared_v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        // 1. 清除本地展览记录（我的页面卡片）
        UserDefaults.standard.removeObject(forKey: "gallery_exhibition_history")

        // 2. 清除每个用户的活跃展览
        for user in mockUsers {
            UserDefaults.standard.removeObject(forKey: "gallery_active_exhibition_\(user.id)")
            UserDefaults.standard.removeObject(forKey: "gallery_active_exhibition_pictures_\(user.id)")
        }

        UserDefaults.standard.set(true, forKey: flagKey)
    }
}

// MARK: - Shared Constants
private let burgundy = Color(red: 128/255, green: 0/255, blue: 32/255)
private let brownText = Color(red: 0.40, green: 0.36, blue: 0.33)
private let brownLabel = Color(red: 0.50, green: 0.45, blue: 0.40)
private let cloudDancerWhite = Color(red: 240/255, green: 238/255, blue: 233/255)

// MARK: - App Entry Flow
enum AppStage {
    case splash       // 启动闪屏：AppIcon 配色
    case terms        // 首次启动协议同意页
    case landing      // 第一页：Days OFF + 登陆 + 注册
    case login        // 登陆输入页（点击登陆后展示）
    case register     // 新用户注册页
    case home         // 主页（TabView）
}

struct MultiUserTabView: View {
    @AppStorage("is_logged_in") private var isLoggedIn: Bool = false
    @AppStorage("has_agreed_to_terms") private var hasAgreedToTerms: Bool = false
    @State private var stage: AppStage = .splash
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("registered_user_id_v3") private var savedUserId: String = ""
    @AppStorage("registered_username_v3") private var savedUsername: String = ""

    var body: some View {
        ZStack {
            // Home 只在 stage == .home 时才渲染——避免注册/登录时
            // ContentView 内的烟花、Canvas 动画继续跑 60fps 拖累输入响应
            if stage == .home {
                // 直接从 UserDefaults 读取最新值，绕过 @AppStorage 缓存延迟：
                // 登录/注册成功后 LoginView 写入 UserDefaults，但 MultiUserTabView 的
                // @AppStorage 缓存在同一 runloop 内尚未刷新，会导致 ContentView 拿到旧值（空字符串）
                let uid = UserDefaults.standard.string(forKey: "registered_user_id_v3") ?? ""
                let uname = UserDefaults.standard.string(forKey: "registered_username_v3") ?? ""
                ContentView(userId: uid.isEmpty ? "local-user" : uid,
                            userName: uname.isEmpty ? "本地用户" : uname)
                    .transition(.opacity)
            }

            if stage == .splash {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        // 0.8 秒后自动进入下一阶段（系统 LaunchScreen 已展示 ~1s，合计 ~1.8s）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if !hasAgreedToTerms {
                                    stage = .terms
                                } else if isLoggedIn {
                                    stage = .home
                                } else {
                                    stage = .landing
                                }
                            }
                        }
                    }
            } else if stage == .terms {
                TermsAgreementView(onAgree: {
                    hasAgreedToTerms = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stage = isLoggedIn ? .home : .landing
                    }
                })
                .transition(.opacity)
            } else if stage != .home {
                cloudDancerWhite
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .overlay {
                        switch stage {
                        case .landing:
                            LandingView(
                                onTapLogin:  { withAnimation { stage = .login } },
                                onTapRegister: { withAnimation { stage = .register } }
                            )
                            .transition(.opacity)
                        case .login:
                            LoginView(
                                onBack: { withAnimation { stage = .landing } },
                                onSuccess: enterHome
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        case .register:
                            RegisterView(
                                onBack: { withAnimation { stage = .landing } },
                                onSuccess: enterHome
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        case .home, .splash, .terms:
                            EmptyView()
                        }
                    }
            }
        }
        // 前台/后台标志法：检测上次会话是否异常结束（崩溃/卡死被系统终止）
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppStats.sessionDidBecomeActive()
            } else if phase == .background {
                AppStats.sessionDidEnterBackground()
            }
        }
        // 任一接口返回 401（令牌失效）→ 强制回登录页重新登录
        .onReceive(NotificationCenter.default.publisher(for: .daysOffSessionExpired)) { _ in
            isLoggedIn = false
            withAnimation(.easeInOut(duration: 0.35)) { stage = .landing }
        }
    }

    private func enterHome() {
        isLoggedIn = true
        withAnimation(.easeInOut(duration: 0.35)) {
            stage = .home
        }
    }
}

// MARK: - Splash View (启动闪屏)
struct SplashView: View {
    var body: some View {
        ZStack {
            // 薰衣草紫色背景
            Color(red: 196/255, green: 178/255, blue: 232/255)
                .ignoresSafeArea()

            // 放大版 Four colored tilted tapes at frame corners
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                // 矩形四角位置：屏幕上方黄金分割点 (0.382)
                let frameSize: CGFloat = w * 0.50
                let centerX = w / 2
                let centerY = h * 0.382

                // 细长形胶带：长宽比 6:1
                let tapeLength: CGFloat = frameSize * 0.35
                let tapeWidth: CGFloat = tapeLength / 6

                // Top-left: Cloud dancer white → Blush pink 渐变, tilted -10°
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 240/255, green: 238/255, blue: 233/255),  // Cloud dancer white
                                Color(red: 232/255, green: 120/255, blue: 160/255)   // Blush pink
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: tapeLength, height: tapeWidth)
                    .rotationEffect(.degrees(-10))
                    .position(
                        x: centerX - frameSize/2 + tapeLength/2,
                        y: centerY - frameSize/2 + tapeWidth/2
                    )

                // Top-right: 桃粉 → 奶油 → 薄荷 ombre, tilted +8°
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 235/255, green: 200/255, blue: 210/255),
                                Color(red: 240/255, green: 220/255, blue: 175/255),
                                Color(red: 180/255, green: 220/255, blue: 195/255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: tapeLength, height: tapeWidth)
                    .rotationEffect(.degrees(8))
                    .position(
                        x: centerX + frameSize/2 - tapeLength/2,
                        y: centerY - frameSize/2 + tapeWidth/2
                    )

                // Bottom-left: burgundy, tilted +10°
                Rectangle()
                    .fill(Color(red: 146/255, green: 28/255, blue: 56/255))
                    .frame(width: tapeLength, height: tapeWidth)
                    .rotationEffect(.degrees(10))
                    .position(
                        x: centerX - frameSize/2 + tapeLength/2,
                        y: centerY + frameSize/2 - tapeWidth/2
                    )

                // Bottom-right: ocean blue, tilted -8°
                Rectangle()
                    .fill(Color(red: 86/255, green: 142/255, blue: 198/255))
                    .frame(width: tapeLength, height: tapeWidth)
                    .rotationEffect(.degrees(-8))
                    .position(
                        x: centerX + frameSize/2 - tapeLength/2,
                        y: centerY + frameSize/2 - tapeWidth/2
                    )
            }
        }
    }
}

// MARK: - Landing Page (第 1 页)
struct LandingView: View {
    let onTapLogin: () -> Void
    let onTapRegister: () -> Void

    // 烟花配色
    private let lavender = Color(red: 196/255, green: 178/255, blue: 232/255)
    private let milkWhite = Color(red: 246/255, green: 240/255, blue: 255/255)
    private let oceanBlue    = Color(red: 86/255, green: 142/255, blue: 198/255)
    private let rosePink     = Color(red: 232/255, green: 120/255, blue: 160/255)

    var body: some View {
        GeometryReader { geo in
            let btnWidth: CGFloat = 180
            let btnCenterX = geo.size.width / 2
            let btnY = geo.size.height * 0.382 - 32 + 48 + 10 + geo.size.height * 0.25 + 25  // 登陆按钮中心 Y
            let btnLeftX = btnCenterX - btnWidth / 2
            let btnRightX = btnCenterX + btnWidth / 2

            ZStack {
                // 云舞白 背景
                cloudDancerWhite
                    .ignoresSafeArea()

                // 两只烟花：从登陆按钮外侧射出，斜向中心上方爆裂
                // 左侧烟花：从按钮左外侧射向中心偏左
                RisingFirework(
                    startX: btnLeftX - 30,
                    startY: btnY,
                    endX: btnCenterX - geo.size.width * 0.12,
                    endY: geo.size.height * 0.20,
                    endYVariance: geo.size.height * 0.08,
                    primary: lavender,
                    secondary: milkWhite,
                    seed: 1
                )
                // 右侧烟花：从按钮右外侧射向中心偏右
                RisingFirework(
                    startX: btnRightX + 30,
                    startY: btnY,
                    endX: btnCenterX + geo.size.width * 0.12,
                    endY: geo.size.height * 0.20,
                    endYVariance: geo.size.height * 0.08,
                    primary: oceanBlue,
                    secondary: rosePink,
                    seed: 13
                )

                // 内容层（保持在烟花之上）
                VStack(spacing: 0) {
                    // 上方黄金分割位置放 Days OFF
                    Spacer()
                        .frame(height: geo.size.height * 0.382 - 32)

                    VStack(spacing: 4) {
                        Text("Days OFF")
                            .font(.custom("IowanOldStyle-Bold", size: 48))
                            .foregroundColor(brownText)
                            .tracking(2)
                            .fixedSize()

                        // Days OFF 下方装饰线：宽度与文字一致（从 D 到 F）
                        Rectangle()
                            .fill(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.55))
                            .frame(height: 0.6)
                            .frame(maxWidth: .infinity)
                    }
                    .fixedSize(horizontal: true, vertical: false)

                    Spacer()
                        .frame(height: geo.size.height * 0.25)

                    // 登录按钮（勃艮第酒红）— 首次进入页面双语显示，| 居中
                    Button(action: onTapLogin) {
                        HStack(spacing: 0) {
                            Text("登 录")
                                .font(.pingFang(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(" | ")
                                .font(.pingFang(size: 18, weight: .semibold))
                            Text("Log In")
                                .font(.pingFang(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                            .foregroundColor(.white)
                            .frame(width: btnWidth, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(burgundy)
                            )
                    }
                    .padding(.bottom, 16)

                    // 注册按钮 — 首次进入页面双语显示，| 居中
                    Button(action: onTapRegister) {
                        HStack(spacing: 0) {
                            Text("注 册")
                                .font(.pingFang(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(" | ")
                                .font(.pingFang(size: 18, weight: .semibold))
                            Text("Sign Up")
                                .font(.pingFang(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                            .foregroundColor(burgundy)
                            .frame(width: btnWidth, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(burgundy, lineWidth: 1.2)
                            )
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Rising Firework (斜向上升 + 爆裂烟花)
/// 每 ~2s 自动循环一次：从起点斜向飞向终点 → 爆裂成 16 颗粒子 + 外环
struct RisingFirework: View {
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let endYVariance: CGFloat
    let primary: Color
    let secondary: Color
    let seed: Double

    private static let brightYellow = Color(red: 255/255, green: 235/255, blue: 130/255)
    private static let lightPeach   = Color(red: 255/255, green: 218/255, blue: 185/255)
    private static let sparkleColors: [Color] = [
        brightYellow, lightPeach, brightYellow, lightPeach
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let cycle = 2.0                         // 每次循环 2 秒（更快）
            let offset = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle * 5) / cycle
            let t = (offset + seed).truncatingRemainder(dividingBy: cycle) / cycle  // 0...1
            let riseProgress = min(t / 0.40, 1.0)            // 前 40% 时间上升（更快）
            let burstProgress = t < 0.40 ? 0.0 : (t - 0.40) / 0.60   // 后 60% 爆裂

            // 每个循环用不同爆裂高度：用 cycle index 做伪随机
            let cycleIndex = Int((tl.date.timeIntervalSinceReferenceDate + seed) / cycle)
            let hash = abs(cycleIndex &* 2654435761) % 1000
            let rand = Double(hash) / 1000.0          // 0...1
            let actualEndY = endY + (rand - 0.5) * 2.0 * Double(endYVariance)

            Canvas { ctx, size in
                // === 上升轨迹：斜向尾迹 ===
                if riseProgress < 1.0 {
                    for i in stride(from: 0, through: 1, by: 0.04) {
                        let px = startX + (endX - startX) * CGFloat(i) * riseProgress
                        let py = startY + (actualEndY - startY) * CGFloat(i) * riseProgress
                        let alpha = (1 - i * 0.6) * (0.4 + 0.6 * sin(riseProgress * .pi))
                        let particleColor = i < 0.5 ? primary : secondary
                        let r: CGFloat = 3.5
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r*2, height: r*2)),
                            with: .color(particleColor.opacity(alpha))
                        )
                    }
                    // 顶部头部（亮的"火苗"）
                    let headR: CGFloat = 5.5
                    let headX = startX + (endX - startX) * riseProgress
                    let headY = startY + (actualEndY - startY) * riseProgress
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: headX - headR, y: headY - headR, width: headR*2, height: headR*2)),
                        with: .color(secondary.opacity(0.95))
                    )
                    // 头部柔光
                    let glowR: CGFloat = 10
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: headX - glowR, y: headY - glowR, width: glowR*2, height: glowR*2)),
                        with: .color(primary.opacity(0.3))
                    )
                }

                // === 爆裂：16 颗粒子 + 柔光外环 ===
                let burstCount: Int = 16
                if burstProgress > 0 {
                    let explodeCenter = CGPoint(x: endX, y: actualEndY)
                    let maxRadius: CGFloat = 60
                    let radius = maxRadius * CGFloat(sqrt(burstProgress))
                    let particleAlpha = 1.0 - burstProgress * 0.9

                    for i in 0..<burstCount {
                        let angle = (Double(i) / Double(burstCount)) * 2 * .pi + seed
                        let px = explodeCenter.x + radius * CGFloat(cos(angle))
                        let py = explodeCenter.y + radius * CGFloat(sin(angle))
                        let pr: CGFloat = 5.0 * (1.0 - 0.3 * burstProgress)
                        let usePrimary = i % 2 == 0
                        let color = usePrimary ? primary : secondary
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr*2, height: pr*2)),
                            with: .color(color.opacity(particleAlpha))
                        )
                    }

                    // 柔光外环
                    let outerR = maxRadius * 1.1 * CGFloat(burstProgress)
                    let ringRect = CGRect(
                        x: explodeCenter.x - outerR,
                        y: explodeCenter.y - outerR,
                        width: outerR * 2,
                        height: outerR * 2
                    )
                    ctx.stroke(
                        Path(ellipseIn: ringRect),
                        with: .color(primary.opacity((1.0 - burstProgress) * 0.5)),
                        lineWidth: 1.5
                    )

                    // === 周围亮黄/浅桃星星和闪烁碎片 ===
                    let sparkleColors = Self.sparkleColors

                    // 6 颗星形（四角星）散布在爆裂外围
                    let starCount = 6
                    for i in 0..<starCount {
                        let angle = (Double(i) / Double(starCount)) * 2 * .pi + seed * 0.5
                        let dist = maxRadius * (0.7 + 0.5 * CGFloat(sin(burstProgress * .pi)))
                        let sx = explodeCenter.x + dist * CGFloat(cos(angle))
                        let sy = explodeCenter.y + dist * CGFloat(sin(angle))
                        let starSize: CGFloat = 6 + 4 * CGFloat(sin(burstProgress * .pi))
                        let starAlpha = particleAlpha * 0.85
                        let starColor = sparkleColors[i % sparkleColors.count]
                        drawStar(ctx: ctx, center: CGPoint(x: sx, y: sy), size: starSize, color: starColor.opacity(starAlpha))
                    }

                    // 10 颗小闪烁碎片（随机散布）
                    let flakeCount = 10
                    for i in 0..<flakeCount {
                        let angle = (Double(i) * 2.4 + seed)  // 黄金角散布
                        let dist = maxRadius * (0.4 + 0.8 * CGFloat(sin(burstProgress * .pi))) * CGFloat(0.5 + 0.5 * Double(i % 3) / 3.0)
                        let fx = explodeCenter.x + dist * CGFloat(cos(angle))
                        let fy = explodeCenter.y + dist * CGFloat(sin(angle))
                        let flakeR: CGFloat = 2.5 * (1.0 - 0.3 * burstProgress)
                        let flakeAlpha = particleAlpha * (0.5 + 0.5 * CGFloat(sin(burstProgress * .pi * 2 + Double(i))))
                        let flakeColor = sparkleColors[i % sparkleColors.count]
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: fx - flakeR, y: fy - flakeR, width: flakeR*2, height: flakeR*2)),
                            with: .color(flakeColor.opacity(flakeAlpha))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// 绘制四角星（亮闪闪的十字星）
    private func drawStar(ctx: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        var path = Path()
        // 四角星：上下左右四个尖角 + 四个凹点
        let outer = size
        let inner = size * 0.3
        let points: [(CGFloat, CGFloat)] = [
            (0, -outer),    // 上
            (inner, -inner),
            (outer, 0),     // 右
            (inner, inner),
            (0, outer),     // 下
            (-inner, inner),
            (-outer, 0),    // 左
            (-inner, -inner)
        ]
        path.move(to: CGPoint(x: center.x + points[0].0, y: center.y + points[0].1))
        for p in points.dropFirst() {
            path.addLine(to: CGPoint(x: center.x + p.0, y: center.y + p.1))
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(color))

        // 中心亮点
        let coreR = size * 0.2
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR*2, height: coreR*2)),
            with: .color(Color.white.opacity(0.8))
        )
    }
}

// MARK: - Login Page
struct LoginView: View {
    let onBack: () -> Void
    let onSuccess: () -> Void

    @AppStorage("registered_user_id_v3") private var savedUserId: String = ""
    @AppStorage("registered_username_v3") private var savedUsername: String = ""

    @State private var username: String = ""
    @State private var password: String = ""
    @StateObject private var auth = AuthStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack {
                Spacer()
                VStack(spacing: 36) {
                    Text(L("登陆", "Log In"))
                        .font(.pingFang(size: 18, weight: .semibold))
                        .foregroundColor(brownText)

                    VStack(alignment: .leading, spacing: 22) {
                        UnderlinedField(label: "用户名", text: $username, secure: false)
                        UnderlinedField(label: "密码", text: $password, secure: true)
                    }
                    .padding(.horizontal, 48)

                    if !auth.errorMessage.isEmpty {
                        Text(auth.errorMessage)
                            .font(.pingFang(size: 13))
                            .foregroundColor(.red)
                    }

                    Button(action: submit) {
                        Text(L("确认登陆", "Confirm Login"))
                            .font(.pingFang(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(burgundy)
                            )
                    }
                }
                Spacer()
            }

            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(brownText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }

    private func submit() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            auth.errorMessage = "请输入用户名"
            return
        }
        guard !password.isEmpty else {
            auth.errorMessage = "请输入密码"
            return
        }
        Task {
            guard let (uid, uname) = await auth.login(username: trimmed, password: password) else { return }
            savedUserId = uid
            savedUsername = uname
            onSuccess()
        }
    }
}

// MARK: - Shared Underlined Input Field
struct UnderlinedField: View {
    let label: String
    @Binding var text: String
    let secure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.pingFang(size: 13, weight: .regular))
                .foregroundColor(brownLabel)
            if secure {
                SecureField("", text: $text)
                    .font(.pingFang(size: 16))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .keyboardType(.default)
                    // 密码字段：不标识为密码类型，阻止 iOS 弹出密码自动填充弹窗
                    .textContentType(.none)
            } else {
                TextField("", text: $text)
                    .font(.pingFang(size: 16))
                    .keyboardType(.default)
                    // 关闭"首字母自动大写"与"英文拼写检查/自动纠错"
                    // （autocorrection 必须 true 级别的 disable，否则 iOS 会把中文拼音组合串当成英文乱词干扰输入）
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    // 用户名字段：明确标识为 .username，防止 iOS 把手机号推送为建议
                    .textContentType(.username)
            }
            Rectangle()
                .fill(brownText.opacity(0.4))
                .frame(height: 1)
        }
    }
}

struct RegisterView: View {
    let onBack: () -> Void
    let onSuccess: () -> Void

    @AppStorage("registered_user_id_v3") private var savedUserId: String = ""
    @AppStorage("registered_username_v3") private var savedUsername: String = ""

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @StateObject private var auth = AuthStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack {
                Spacer()
                VStack(spacing: 36) {
                    Text(L("新用户注册", "New User Sign Up"))
                        .font(.pingFang(size: 18, weight: .semibold))
                        .foregroundColor(brownText)

                    VStack(alignment: .leading, spacing: 22) {
                        UnderlinedField(label: "用户名", text: $username, secure: false)
                        UnderlinedField(label: "密码", text: $password, secure: true)
                        UnderlinedField(label: "确认密码", text: $confirmPassword, secure: true)
                    }
                    .padding(.horizontal, 48)

                    if !auth.errorMessage.isEmpty {
                        Text(auth.errorMessage)
                            .font(.pingFang(size: 13, weight: .regular))
                            .foregroundColor(.red)
                    }

                    Button(action: submit) {
                        Text(L("注册", "Sign Up"))
                            .font(.pingFang(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(burgundy)
                            )
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }

            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(brownText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }

    private func submit() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            auth.errorMessage = "请输入用户名"
            return
        }
        guard isValidUsername(trimmed) else {
            auth.errorMessage = "用户名 2–10 字符，首字必须是中文或英文字母"
            return
        }
        guard isValidPassword(password) else {
            auth.errorMessage = "密码 8–16 字符，至少包含 1 个数字和 1 个字母"
            return
        }
        guard password == confirmPassword else {
            auth.errorMessage = "两次密码不一致"
            return
        }
        Task {
            guard let (uid, uname) = await auth.register(username: trimmed, password: password) else { return }
            // 首次注册默认后续界面为中文
            UserDefaults.standard.set("zh", forKey: "app_language")
            savedUserId = uid
            savedUsername = uname
            onSuccess()
        }
    }

    /// 用户名规则：2–10 字符，首字只能是中文字符或英文字母
    private func isValidUsername(_ s: String) -> Bool {
        guard (2...10).contains(s.count) else { return false }
        guard let first = s.unicodeScalars.first else { return false }
        let isCJK = (0x4E00...0x9FFF).contains(first.value) ||
                    (0x3400...0x4DBF).contains(first.value)
        let isLetter = CharacterSet.letters.contains(first) &&
                       !CharacterSet.decimalDigits.contains(first)
        return isCJK || isLetter
    }

    /// 密码规则：8–16 字符，至少 1 个数字 + 至少 1 个英文字母
    private func isValidPassword(_ s: String) -> Bool {
        guard (8...16).contains(s.count) else { return false }
        let hasDigit = s.rangeOfCharacter(from: .decimalDigits) != nil
        let hasLetter = s.rangeOfCharacter(from: .letters) != nil
        return hasDigit && hasLetter
    }
}

// MARK: - 首次启动协议同意页
struct TermsAgreementView: View {
    let onAgree: () -> Void
    @State private var showDisagreeAlert = false
    @State private var showBlockedAlert = false
    @State private var showFullTerms = false
    @State private var showFullPrivacy = false
    @State private var hasReadTerms = false
    @State private var hasReadPrivacy = false

    // 暖奶白底色，与设置页协议正文保持一致
    private let paperWhite = Color(red: 250/255, green: 246/255, blue: 236/255)
    private let inkColor = Color(red: 0.30, green: 0.28, blue: 0.32)
    private let accentColor = Color(red: 0.55, green: 0.45, blue: 0.75)

    /// 两份协议都已被打开阅读后，「同意并继续」按钮才可用
    private var canAgree: Bool { hasReadTerms && hasReadPrivacy }

    var body: some View {
        VStack(spacing: 0) {
            // 标题区
            VStack(spacing: 6) {
                // "欢迎来到" PingFang SC + "Days OFF" IowanOldStyle-Bold，
                // 与首页/我的页中 Days OFF 字体一致
                (Text(L("欢迎来到 ", "Welcome to "))
                    .font(.pingFang(size: 22, weight: .semibold))
                + Text("Days OFF")
                    .font(.custom("IowanOldStyle-Bold", size: 22)))
                .foregroundColor(inkColor)

                Text(L("使用前请展开阅读并同意以下协议", "Please read and agree to the following terms before use"))
                    .font(.pingFang(size: 14, weight: .regular))
                    .foregroundColor(inkColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.top, 40)

            // 协议折叠列表
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    agreementRow(
                        title: "《用户协议》",
                        hasRead: $hasReadTerms,
                        fullText: fullTermsText,
                        showFull: $showFullTerms
                    )

                    agreementRow(
                        title: "《隐私政策》",
                        hasRead: $hasReadPrivacy,
                        fullText: fullPrivacyText,
                        showFull: $showFullPrivacy
                    )
                }
                .padding(.horizontal, 60)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // 底部按钮区
            VStack(spacing: 10) {
                Button(action: { onAgree() }) {
                    Text(canAgree ? "同意并继续" : "请先展开阅读两份协议")
                        .font(.pingFang(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canAgree ? accentColor : accentColor.opacity(0.4))
                        .cornerRadius(10)
                }
                .disabled(!canAgree)

                Button(action: { showDisagreeAlert = true }) {
                    Text(L("不同意", "Disagree"))
                        .font(.pingFang(size: 15, weight: .regular))
                        .foregroundColor(inkColor.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(paperWhite.ignoresSafeArea())
        .alert(L("提示", "Notice"), isPresented: $showDisagreeAlert) {
            Button(L("仍不同意", "Still Disagree"), role: .destructive) {
                showBlockedAlert = true
            }
            Button(L("同意并继续", "Agree and Continue")) {
                onAgree()
            }
        } message: {
            Text(L("若您不同意本协议，将无法使用本应用。是否仍不同意？", "If you disagree with the terms, you cannot use this app. Do you still disagree?"))
        }
        .alert(L("无法使用", "Cannot Use"), isPresented: $showBlockedAlert) {
            Button(L("重新阅读", "Re-read"), role: .cancel) {}
        } message: {
            Text(L("您需要同意协议才能继续使用本应用。", "You need to agree to the terms to continue using this app."))
        }
    }

    /// 协议行：标题 + 下拉箭头，点击展开整段正文；关闭时标记为「已读」
    @ViewBuilder
    private func agreementRow(
        title: String,
        hasRead: Binding<Bool>,
        fullText: String,
        showFull: Binding<Bool>
    ) -> some View {
        DisclosureGroup(isExpanded: showFull) {
            Text(fullText)
                .font(.system(size: 13))
                .foregroundColor(inkColor.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.pingFang(size: 17, weight: .semibold))
                    .foregroundColor(inkColor)

                if hasRead.wrappedValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // 云舞白底 + 薰衣草紫边框，无圆角
            Rectangle()
                .fill(cloudDancerWhite)
                .overlay(
                    Rectangle()
                        .stroke(accentColor, lineWidth: 1.5)
                )
        )
        .tint(.white)  // 折叠/展开箭头改为白色
        .onChange(of: showFull.wrappedValue) { _, isExpanded in
            // 折叠（关闭展开）时标记为已读
            if !isExpanded {
                hasRead.wrappedValue = true
            }
        }
    }

    private let fullTermsText = """
    生效日期：2026年8月25日

    欢迎使用 Days OFF（以下简称"本应用"）。使用即视为同意本《用户协议》。

    一、账号与注册
    1. 密码经 SHA-256 加盐哈希存储，不以明文保存。
    2. 注册限每 IP 每小时 5 次，登录限每 5 分钟 10 次。
    3. 您应妥善保管账号密码，因泄露造成的损失自行承担。

    二、服务内容
    提供心情日记、运动记录、旅行灵感、画廊作品、里程碑与卡片管理等功能；
    登录后数据同步至云端服务器，便于跨设备恢复。

    三、用户行为规范
    不上传违法违规内容；不侵害他人知识产权、肖像权、隐私权；
    不对服务器进行恶意攻击、爬取或刷量；不未经授权访问他人数据。

    四、内容与知识产权
    用户内容知识产权归您或原权利人所有；
    授予本应用非排他、无偿、可转授权的全球性许可，仅用于服务所必需的处理。

    五、服务的变更、中断与终止
    因维护、升级等可能暂停服务；违反协议将限制或终止账号；
    可随时退出登录清数据；账号注销可在"设置"中自助操作完成。

    六、免责声明
    服务按现状提供；因不可抗力或第三方服务故障导致的损失，法律允许范围内不承担责任。

    七、协议更新
    修订后在本页面公布，继续使用视为同意。

    八、联系我们
    如有疑问请通过 support@daysoff-app.com 联系。
    """

    private let fullPrivacyText = """
    生效日期：2026年8月25日

    欢迎使用 Days OFF。本政策说明我们如何收集、使用与保护您的信息。

    一、收集的信息
    1. 账号信息：用户名、SHA-256 哈希后的密码。
    2. 您创作的内容：心情手记、运动笔记与运动计划、旅行卡片、赛事卡片、上传的作品及展览与旅行灵感。
    3. 匿名统计信息：注册数量、每日活跃、异常退出与网络错误等，均以匿名方式汇总。

    二、端到端加密
    您的心情手记、运动笔记、运动计划、旅行卡片、赛事卡片及未公开的作品，均在您的设备上使用由您的密码派生的密钥加密后才会上传云端。服务器仅存储加密后的密文。
    由于加密密钥仅由您的密码在您的设备上派生，我们也无法获知或重置该密钥。若您忘记密码，上述加密内容将无法恢复。

    三、公开内容
    您主动发布的展览、旅行灵感及公开作品属于公开内容，将以明文形式存储并向其他用户展示，以便我们依法履行内容审核义务。请您勿在公开内容中填写个人敏感信息。

    四、信息的使用
    仅用于本应用内展示、跨设备同步与改进服务，不用于其他商业用途。

    五、信息的存储
    1. 本地存储：UserDefaults、Keychain（Token）。
    2. 云端存储：阿里云轻量应用服务器（业务数据）与阿里云 OSS（图片）。
    私密内容以密文形式存储。

    六、信息的共享与披露
    不会向第三方出售您的个人信息。
    仅在获得您明确同意，或法律法规要求时，才会共享或披露。

    七、信息安全
    采取 Token 鉴权、HTTPS 传输、密码加盐哈希、私密内容端到端加密等措施保护您的信息。

    八、您的权利
    可访问、更正、删除个人信息，可注销账号。
    退出登录会清除本地用户数据；OSS 图片 URL 缓存因内容寻址特性予以保留。

    九、未成年人保护
    本应用不面向 14 周岁以下儿童，不会故意收集儿童信息。

    十、政策更新
    修订后在本页面公布，重大变更将以显著方式通知。

    十一、联系我们
    如有疑问请通过 support@daysoff-app.com 联系。
    """
}
