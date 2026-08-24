//
//  HomeModuleView.swift
//  DaysOff
//
//  Created by Yi Yang on 2026/8/10.
//

import SwiftUI

private extension Color {
    static let cloudDancer = Color(red: 240/255, green: 238/255, blue: 233/255)
}

// MARK: - Parameterized silver square

struct SilverSquare: View {
    var size: CGFloat = 32
    var gradientStart: UnitPoint = .topLeading
    var gradientEnd: UnitPoint = .bottomTrailing
    var highlightAlignment: Alignment = .top
    var sweepAngle: Double = -30
    var sweepOffsetX: CGFloat = 0.05
    var shadowDx: CGFloat = 0
    var shadowDy: CGFloat = 1.5
    var borderStart: UnitPoint = .topLeading
    var borderEnd: UnitPoint = .bottomTrailing

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 255/255, green: 255/255, blue: 255/255),
                        Color(red: 252/255, green: 253/255, blue: 255/255),
                        Color(red: 248/255, green: 250/255, blue: 253/255),
                        Color(red: 244/255, green: 247/255, blue: 252/255)
                    ],
                    startPoint: gradientStart,
                    endPoint: gradientEnd
                )
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: highlightAlignment == .top || highlightAlignment == .topLeading || highlightAlignment == .topTrailing ? .top :
                               highlightAlignment == .bottom || highlightAlignment == .bottomLeading || highlightAlignment == .bottomTrailing ? .bottom :
                               highlightAlignment == .leading ? .leading : .trailing,
                    endPoint: highlightAlignment == .top || highlightAlignment == .topLeading || highlightAlignment == .topTrailing ? .bottom :
                               highlightAlignment == .bottom || highlightAlignment == .bottomLeading || highlightAlignment == .bottomTrailing ? .top :
                               highlightAlignment == .leading ? .trailing : .leading
                )
                .frame(
                    maxWidth: highlightAlignment == .leading || highlightAlignment == .trailing ? 8 : .infinity,
                    maxHeight: highlightAlignment == .top || highlightAlignment == .bottom ? 8 : .infinity
                )
                .blur(radius: 0.3)
                .padding(
                    highlightAlignment == .top ? EdgeInsets(top: 1, leading: 0, bottom: 0, trailing: 0) :
                    highlightAlignment == .bottom ? EdgeInsets(top: 0, leading: 0, bottom: 1, trailing: 0) :
                    highlightAlignment == .leading ? EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 0) :
                    EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 1)
                )
                .mask(RoundedRectangle(cornerRadius: 4)),
                alignment: highlightAlignment
            )
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color(red: 252/255, green: 254/255, blue: 255/255).opacity(0.7),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5, height: geo.size.height * 2)
                    .rotationEffect(.degrees(sweepAngle))
                    .offset(x: geo.size.width * sweepOffsetX)
                    .blur(radius: 0.4)
                }
                .mask(RoundedRectangle(cornerRadius: 4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(red: 215/255, green: 222/255, blue: 235/255).opacity(0.9)
                            ],
                            startPoint: borderStart,
                            endPoint: borderEnd
                        ),
                        lineWidth: 0.5
                    )
            )
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: shadowDx, y: shadowDy)
    }
}

// MARK: - Colored Gem Square (same size & finish as SilverSquare, custom gradient)

struct GemSquare: View {
    var size: CGFloat = 32
    var colors: [Color]
    var gradientStart: UnitPoint = .topLeading
    var gradientEnd: UnitPoint = .bottomTrailing
    var highlightColor: Color = Color.white
    var borderLight: Color = Color.white
    var borderDark: Color = Color.black.opacity(0.5)
    var sweepAngle: Double = -25
    var shadowDx: CGFloat = 0
    var shadowDy: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(colors: colors, startPoint: gradientStart, endPoint: gradientEnd)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        highlightColor.opacity(0.9),
                        highlightColor.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
                .blur(radius: 0.3)
                .padding(.top, 1)
                .mask(RoundedRectangle(cornerRadius: 4)),
                alignment: .top
            )
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            highlightColor.opacity(0.0),
                            highlightColor.opacity(0.55),
                            highlightColor.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.45, height: geo.size.height * 1.8)
                    .rotationEffect(.degrees(sweepAngle))
                    .offset(x: geo.size.width * 0.05)
                    .blur(radius: 0.4)
                }
                .mask(RoundedRectangle(cornerRadius: 4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [borderLight.opacity(0.95), borderDark.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .frame(width: size, height: size)
            .shadow(color: Color.black.opacity(0.14), radius: 2, x: shadowDx, y: shadowDy)
    }
}

// MARK: - Thin white paper with centered text (very translucent so the silver square shows through)

struct PaperView: View {
    var text: String
    var size: CGFloat = 44
    var fontSize: CGFloat = 16
    var opacity: Double = 0.45
    var textOpacity: Double = 0.9

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .overlay(
                Text(text)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(Color(red: 80/255, green: 70/255, blue: 60/255).opacity(textOpacity))
            )
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Four colored tilted tapes at frame corners

struct TapeFrameView: View {
    var size: CGFloat = 72
    var tapeWidth: CGFloat = 22
    var tapeHeight: CGFloat = 9

    private let lavenderColor = Color(red: 196/255, green: 178/255, blue: 232/255)
    private let burgundyColor = Color(red: 146/255, green: 28/255, blue: 56/255)
    private let oceanBlueColor = Color(red: 86/255, green: 142/255, blue: 198/255)
    // 温暖梦幻冰淇淋色调胶带：与 icecream 宝石方块色调呼应，中等明度清晰可见
    private let dreamyPeach = Color(red: 235/255, green: 200/255, blue: 210/255)   // 中桃粉
    private let dreamyButter = Color(red: 240/255, green: 220/255, blue: 175/255)  // 中奶油黄
    private let dreamyMint = Color(red: 180/255, green: 220/255, blue: 195/255)    // 中薄荷

    var body: some View {
        ZStack {
            // Top-left: lavender, tilted -10°
            RoundedRectangle(cornerRadius: 1.5)
                .fill(lavenderColor.opacity(0.85))
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(-10))
                .offset(x: -size/2 + tapeWidth/2 - 2, y: -size/2 + tapeHeight/2)

            // Top-right: 桃粉 → 奶油 → 薄荷 ombre（呼应 icecream 宝石方块，温暖梦幻且清晰可见）, tilted +8°
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [dreamyPeach, dreamyButter, dreamyMint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ).opacity(0.88)
                )
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(8))
                .offset(x: size/2 - tapeWidth/2 + 2, y: -size/2 + tapeHeight/2)

            // Bottom-left: burgundy, tilted +10°
            RoundedRectangle(cornerRadius: 1.5)
                .fill(burgundyColor.opacity(0.85))
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(10))
                .offset(x: -size/2 + tapeWidth/2 - 2, y: size/2 - tapeHeight/2)

            // Bottom-right: ocean blue, tilted -8°
            RoundedRectangle(cornerRadius: 1.5)
                .fill(oceanBlueColor.opacity(0.85))
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(-8))
                .offset(x: size/2 - tapeWidth/2 + 2, y: size/2 - tapeHeight/2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Paper-on-square model

struct PaperOnSquare: Identifiable {
    let id = UUID()
    let squareIndex: Int
    let text: String
}

// MARK: - Draggable paper view (handles tap + drag in one gesture)

struct DraggablePaperView: View {
    let text: String
    let onTap: () -> Void
    let onDragToTop: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        PaperView(text: text, size: 44, fontSize: 16)
            .offset(dragTranslation)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("grid"))
                    .updating($dragTranslation) { value, state, _ in
                        if hypot(value.translation.width, value.translation.height) > 3 {
                            state = value.translation
                        }
                    }
                    .onEnded { value in
                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist < 3 {
                            onTap()
                        } else if value.translation.height < -40 {
                            // Any upward drag > 40pt pins the paper
                            // (no horizontal limit — tape frame is centered,
                            //  left/right squares need diagonal travel to reach it)
                            onDragToTop()
                        }
                    }
            )
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9), value: dragTranslation)
    }
}

// MARK: - Swing modifier — 45° right, back to center, 45° right, repeating

struct SwingModifier: ViewModifier {
    var isActive: Bool
    @State private var angle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle), anchor: .center)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    // 0° → 45° (right) → 0° (center) → 45° → 0° → ... repeating
                    withAnimation(
                        .easeInOut(duration: 0.7)
                        .repeatForever(autoreverses: true)
                    ) {
                        angle = 45
                    }
                } else {
                    // Stop: return to center
                    withAnimation(.easeInOut(duration: 0.3)) {
                        angle = 0
                    }
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(
                        .easeInOut(duration: 0.7)
                        .repeatForever(autoreverses: true)
                    ) {
                        angle = 45
                    }
                }
            }
    }
}

// MARK: - Pink Heart Sticker (appears when a negative mood is pinned)

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Start at bottom point
        path.move(to: CGPoint(x: w * 0.5, y: h))
        // Left curve up to left lobe start
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.3),
            control1: CGPoint(x: w * 0.12, y: h * 0.72),
            control2: CGPoint(x: 0, y: h * 0.52)
        )
        // Left lobe arc
        path.addArc(
            center: CGPoint(x: w * 0.25, y: h * 0.3),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Right lobe arc
        path.addArc(
            center: CGPoint(x: w * 0.75, y: h * 0.3),
            radius: w * 0.25,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        // Right curve down to bottom point
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.52),
            control2: CGPoint(x: w * 0.88, y: h * 0.72)
        )
        return path
    }
}

private struct PinkHeartSticker: View {
    var size: CGFloat = 38
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 1. Base heart — pink ombre gradient fill
                HeartShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.88, blue: 0.90),
                                Color(red: 0.98, green: 0.68, blue: 0.74),
                                Color(red: 0.93, green: 0.48, blue: 0.58),
                                Color(red: 0.85, green: 0.32, blue: 0.44)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                // 2. Wrinkle lines — thin curved strokes across the heart
                Canvas { ctx, rect in
                    let w = rect.width
                    let h = rect.height

                    // Upper wrinkle (light)
                    var p1 = Path()
                    p1.move(to: CGPoint(x: w * 0.12, y: h * 0.38))
                    p1.addQuadCurve(
                        to: CGPoint(x: w * 0.88, y: h * 0.42),
                        control: CGPoint(x: w * 0.5, y: h * 0.30)
                    )
                    ctx.stroke(p1, with: .color(.white.opacity(0.40)), lineWidth: 0.7)

                    // Middle wrinkle (dark)
                    var p2 = Path()
                    p2.move(to: CGPoint(x: w * 0.18, y: h * 0.55))
                    p2.addQuadCurve(
                        to: CGPoint(x: w * 0.82, y: h * 0.60),
                        control: CGPoint(x: w * 0.5, y: h * 0.48)
                    )
                    ctx.stroke(p2, with: .color(Color(red: 0.55, green: 0.08, blue: 0.18).opacity(0.28)), lineWidth: 0.6)

                    // Lower wrinkle (light)
                    var p3 = Path()
                    p3.move(to: CGPoint(x: w * 0.22, y: h * 0.72))
                    p3.addQuadCurve(
                        to: CGPoint(x: w * 0.78, y: h * 0.78),
                        control: CGPoint(x: w * 0.5, y: h * 0.66)
                    )
                    ctx.stroke(p3, with: .color(.white.opacity(0.25)), lineWidth: 0.5)

                    // Diagonal wrinkle (dark)
                    var p4 = Path()
                    p4.move(to: CGPoint(x: w * 0.30, y: h * 0.20))
                    p4.addQuadCurve(
                        to: CGPoint(x: w * 0.70, y: h * 0.85),
                        control: CGPoint(x: w * 0.60, y: h * 0.50)
                    )
                    ctx.stroke(p4, with: .color(Color(red: 0.50, green: 0.06, blue: 0.16).opacity(0.18)), lineWidth: 0.4)
                }
                .frame(width: size, height: size)

                // 3. Highlight — glossy spot top-left of left lobe
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.16
                        )
                    )
                    .frame(width: size * 0.28, height: size * 0.18)
                    .offset(x: -size * 0.14, y: -size * 0.16)

                // 4. Shadow — darker pink overlay on bottom-right half
                HeartShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.clear,
                                Color(red: 0.45, green: 0.08, blue: 0.18).opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)

                // 5. Outer stroke — subtle dark pink edge
                HeartShape()
                    .stroke(Color(red: 0.50, green: 0.08, blue: 0.18).opacity(0.4), lineWidth: 0.6)
                    .frame(width: size, height: size)
            }
            .shadow(color: Color(red: 0.45, green: 0.08, blue: 0.18).opacity(0.35), radius: 3, x: 1.5, y: 2.5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4x4 Silver Squares Grid + divider + 4 colored gem squares

struct SilverGrid: View {
    var squareSize: CGFloat = 32
    var spacing: CGFloat = 24
    var lineColor: Color = Color(red: 120/255, green: 110/255, blue: 96/255)

    // Callbacks when the user taps each colored gem square
    var onLavenderTap: (String) -> Void = { _ in }
    var onIcecreamTap: () -> Void = {}
    var onBurgundyTap: () -> Void = {}
    var onOceanBlueTap: () -> Void = {}

    // Callback when the user taps the pink heart sticker (negative mood flow)
    var onHeartTap: (String) -> Void = { _ in }

    // Two-way binding to the pinned paper — parent observes this to know when the frame is locked
    @Binding var pinnedPaper: PaperOnSquare?

    // Up to 2 papers currently shown on their squares
    @State private var visiblePapers: [PaperOnSquare] = []

    // Pink heart appears 1s after a negative mood is pinned
    @State private var showPinkHeart = false
    // The 16 mood words assigned to squares. Shuffled once per app launch.
    private let allMoods: [String] = [
        "压抑", "忧虑", "烦躁", "无聊", "不安", "接纳", "轻松", "平静",
        "乐观", "喜悦", "期待", "激动", "惊喜", "满足", "甜蜜", "幸福"
    ]

    // Negative moods — when pinned, show pink heart sticker
    private let negativeMoods: Set<String> = ["压抑", "忧虑", "烦躁", "无聊", "不安"]

    // 由父视图传入：app 启动时打乱一次，切 tab / 进出手记页时保持稳定
    var moodTexts: [Int: String]

    init(squareSize: CGFloat = 32,
         spacing: CGFloat = 24,
         onLavenderTap: @escaping (String) -> Void = { _ in },
         onIcecreamTap: @escaping () -> Void = {},
         onBurgundyTap: @escaping () -> Void = {},
         onOceanBlueTap: @escaping () -> Void = {},
         onHeartTap: @escaping (String) -> Void = { _ in },
         pinnedPaper: Binding<PaperOnSquare?>,
         moodTexts: [Int: String] = [:]) {
        self.squareSize = squareSize
        self.spacing = spacing
        self.onLavenderTap = onLavenderTap
        self.onIcecreamTap = onIcecreamTap
        self.onBurgundyTap = onBurgundyTap
        self.onOceanBlueTap = onOceanBlueTap
        self.onHeartTap = onHeartTap
        self._pinnedPaper = pinnedPaper
        self.moodTexts = moodTexts
    }

    private var isLocked: Bool { pinnedPaper != nil }

    /// True when the pinned paper is a negative mood — triggers the pink heart sticker
    private var isNegativePinned: Bool {
        guard let text = pinnedPaper?.text else { return false }
        return negativeMoods.contains(text)
    }

    // 16 unique light/shadow direction configurations
    private let variants: [SilverSquare] = [
        // Row 1 — top-left light family
        SilverSquare(gradientStart: .topLeading, gradientEnd: .bottomTrailing, highlightAlignment: .top, sweepAngle: -30, sweepOffsetX: 0.05, shadowDx: 0.5, shadowDy: 1.5, borderStart: .topLeading, borderEnd: .bottomTrailing),
        SilverSquare(gradientStart: .top, gradientEnd: .bottom, highlightAlignment: .topLeading, sweepAngle: -20, sweepOffsetX: 0.0, shadowDx: 0.3, shadowDy: 1.8, borderStart: .top, borderEnd: .bottom),
        SilverSquare(gradientStart: UnitPoint(x: 0.1, y: 0.1), gradientEnd: UnitPoint(x: 0.9, y: 0.9), highlightAlignment: .top, sweepAngle: -10, sweepOffsetX: 0.1, shadowDx: 0.8, shadowDy: 1.2, borderStart: .topLeading, borderEnd: .bottomTrailing),
        SilverSquare(gradientStart: .topLeading, gradientEnd: .bottom, highlightAlignment: .topTrailing, sweepAngle: 0, sweepOffsetX: -0.05, shadowDx: 0.2, shadowDy: 1.6, borderStart: .topLeading, borderEnd: .bottom),

        // Row 2 — right / top-right light family
        SilverSquare(gradientStart: .trailing, gradientEnd: .leading, highlightAlignment: .trailing, sweepAngle: 10, sweepOffsetX: 0.0, shadowDx: -0.8, shadowDy: 1.3, borderStart: .trailing, borderEnd: .leading),
        SilverSquare(gradientStart: .topTrailing, gradientEnd: .bottomLeading, highlightAlignment: .top, sweepAngle: 20, sweepOffsetX: -0.08, shadowDx: -0.4, shadowDy: 1.5, borderStart: .topTrailing, borderEnd: .bottomLeading),
        SilverSquare(gradientStart: UnitPoint(x: 0.9, y: 0.1), gradientEnd: UnitPoint(x: 0.1, y: 0.9), highlightAlignment: .topTrailing, sweepAngle: 30, sweepOffsetX: -0.1, shadowDx: -0.6, shadowDy: 1.7, borderStart: .topTrailing, borderEnd: .bottomLeading),
        SilverSquare(gradientStart: .top, gradientEnd: .bottomLeading, highlightAlignment: .trailing, sweepAngle: 15, sweepOffsetX: 0.05, shadowDx: -0.3, shadowDy: 1.4, borderStart: .top, borderEnd: .bottomLeading),

        // Row 3 — bottom light family (reverse)
        SilverSquare(gradientStart: .bottomTrailing, gradientEnd: .topLeading, highlightAlignment: .bottom, sweepAngle: -30, sweepOffsetX: -0.05, shadowDx: 0.4, shadowDy: -1.2, borderStart: .bottomTrailing, borderEnd: .topLeading),
        SilverSquare(gradientStart: .bottom, gradientEnd: .top, highlightAlignment: .bottomTrailing, sweepAngle: -20, sweepOffsetX: 0.0, shadowDx: 0.6, shadowDy: -1.5, borderStart: .bottom, borderEnd: .top),
        SilverSquare(gradientStart: UnitPoint(x: 0.9, y: 0.9), gradientEnd: UnitPoint(x: 0.1, y: 0.1), highlightAlignment: .bottom, sweepAngle: -15, sweepOffsetX: -0.08, shadowDx: 0.3, shadowDy: -1.3, borderStart: .bottomTrailing, borderEnd: .topLeading),
        SilverSquare(gradientStart: .bottomLeading, gradientEnd: .top, highlightAlignment: .bottomLeading, sweepAngle: -5, sweepOffsetX: 0.05, shadowDx: 0.7, shadowDy: -1.4, borderStart: .bottomLeading, borderEnd: .top),

        // Row 4 — left / bottom-left light family
        SilverSquare(gradientStart: .leading, gradientEnd: .trailing, highlightAlignment: .leading, sweepAngle: 10, sweepOffsetX: 0.08, shadowDx: 0.9, shadowDy: 1.1, borderStart: .leading, borderEnd: .trailing),
        SilverSquare(gradientStart: .bottomLeading, gradientEnd: .topTrailing, highlightAlignment: .bottom, sweepAngle: 25, sweepOffsetX: 0.0, shadowDx: 0.5, shadowDy: 1.6, borderStart: .bottomLeading, borderEnd: .topTrailing),
        SilverSquare(gradientStart: UnitPoint(x: 0.1, y: 0.9), gradientEnd: UnitPoint(x: 0.9, y: 0.1), highlightAlignment: .bottomLeading, sweepAngle: 35, sweepOffsetX: 0.1, shadowDx: 0.2, shadowDy: 1.3, borderStart: .bottomLeading, borderEnd: .topTrailing),
        SilverSquare(gradientStart: .bottom, gradientEnd: .topTrailing, highlightAlignment: .leading, sweepAngle: 18, sweepOffsetX: -0.05, shadowDx: 0.6, shadowDy: 1.2, borderStart: .bottom, borderEnd: .topTrailing)
    ]

    // Four gem color palettes
    private let lavenderColors = [
        Color(red: 246/255, green: 240/255, blue: 255/255),
        Color(red: 232/255, green: 222/255, blue: 250/255),
        Color(red: 214/255, green: 200/255, blue: 242/255),
        Color(red: 196/255, green: 178/255, blue: 232/255)
    ]

    private let icecreamColors = [
        Color(red: 255/255, green: 240/255, blue: 242/255),
        Color(red: 255/255, green: 248/255, blue: 228/255),
        Color(red: 244/255, green: 252/255, blue: 238/255),
        Color(red: 226/255, green: 244/255, blue: 230/255)
    ]

    private let burgundyColors = [
        Color(red: 210/255, green: 86/255, blue: 106/255),
        Color(red: 178/255, green: 52/255, blue: 76/255),
        Color(red: 146/255, green: 28/255, blue: 56/255),
        Color(red: 118/255, green: 12/255, blue: 40/255)
    ]

    private let oceanBlueColors = [
        Color(red: 220/255, green: 242/255, blue: 254/255),
        Color(red: 172/255, green: 210/255, blue: 240/255),
        Color(red: 124/255, green: 174/255, blue: 220/255),
        Color(red: 86/255, green: 142/255, blue: 198/255)
    ]

    private func gemRowWidth() -> CGFloat {
        CGFloat(4) * squareSize + CGFloat(3) * spacing
    }

    // MARK: - Square interaction logic

    /// Tap on a square:
    ///   - If tape frame has a pinned paper → do nothing.
    ///   - If square already has a paper → dismiss ONLY that paper.
    ///   - Otherwise → add a new paper; keep only the 2 most recent.
    private func handleSquareTap(_ index: Int) {
        guard !isLocked else { return }

        if visiblePapers.contains(where: { $0.squareIndex == index }) {
            // Square has a paper → dismiss only this paper
            withAnimation(.easeInOut(duration: 0.3)) {
                visiblePapers.removeAll(where: { $0.squareIndex == index })
            }
        } else {
            // Add new paper; evict oldest if already 2
            let newPaper = PaperOnSquare(
                squareIndex: index,
                text: moodTexts[index] ?? "心情"
            )
            withAnimation(.easeInOut(duration: 0.35)) {
                visiblePapers.append(newPaper)
                if visiblePapers.count > 2 {
                    visiblePapers.removeFirst()
                }
            }
        }
    }

    /// Paper tapped (via tap gesture on the paper itself) → dismiss ONLY this paper.
    private func dismissPaper(_ paper: PaperOnSquare) {
        guard !isLocked else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            visiblePapers.removeAll(where: { $0.squareIndex == paper.squareIndex })
        }
    }

    /// Paper dragged up to the tape frame → pin it, clear all below.
    private func pinPaper(_ paper: PaperOnSquare) {
        showPinkHeart = false
        withAnimation(.easeInOut(duration: 0.45)) {
            visiblePapers.removeAll()
            pinnedPaper = paper
        }
        // If negative mood, show pink heart after 1 second
        if negativeMoods.contains(paper.text) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if pinnedPaper?.text == paper.text {
                    withAnimation(.interpolatingSpring(stiffness: 60, damping: 14, initialVelocity: 0.2)) {
                        showPinkHeart = true
                    }
                }
            }
        }
    }

    // Gap below gem square so that when swung 45°, the lowest point to text = row spacing
    private var gemLabelSpacing: CGFloat {
        let extensionBelow = squareSize / 2 * (sqrt(2) - 1)
        return spacing + extensionBelow
    }

    // MARK: - Vertical label (shown below gem squares when swinging)

    @ViewBuilder
    private func verticalLabel(_ text: String, isLocked: Bool) -> some View {
        VStack(spacing: 1) {
            ForEach(Array(text), id: \.self) { ch in
                Text(String(ch))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 90/255, green: 80/255, blue: 70/255))
            }
        }
        .opacity(isLocked ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.3), value: isLocked)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: spacing) {
            // ── Tape frame above row 1 + pink heart sticker (negative mood) ──
            ZStack {
                TapeFrameView(size: 72)
                    .offset(y: -10)

                if let p = pinnedPaper {
                    PaperView(text: p.text, size: 72, fontSize: 24, opacity: 0.45, textOpacity: 0.9)
                        .offset(y: -10)  // 随胶带上移
                        .transition(.opacity.combined(with: .scale))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                showPinkHeart = false
                                pinnedPaper = nil
                            }
                        }
                }

                // Pink heart sticker — appears 1s after a negative mood is pinned
                if showPinkHeart, let p = pinnedPaper {
                    PinkHeartSticker(size: 38, onTap: { onHeartTap(p.text) })
                        .offset(x: 72, y: -8)  // 随胶带上移 10pt
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.35, anchor: .leading)
                                .combined(with: .opacity)
                                .combined(with: .offset(x: -12, y: 0)),
                            removal: .scale.animation(.easeInOut(duration: 0.25))
                                .combined(with: .opacity)
                        ))
                        .animation(.easeOut(duration: 0.15), value: showPinkHeart)
                }
            }
            .frame(height: 72)

            // ── 4x4 silver grid — all squares interactive ──
            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { col in
                            let idx = row * 4 + col + 1  // 1-based index
                            let paper = visiblePapers.first(where: { $0.squareIndex == idx })

                            variants[row * 4 + col]
                                .frame(width: squareSize, height: squareSize)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleSquareTap(idx)
                                }
                                .overlay {
                                    if let paper = paper {
                                        DraggablePaperView(
                                            text: paper.text,
                                            onTap: { dismissPaper(paper) },
                                            onDragToTop: { pinPaper(paper) }
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                        }
                    }
                }
            }

            // ── Thin separator line below the bottom row ──
            Rectangle()
                .fill(lineColor.opacity(0.55))
                .frame(width: gemRowWidth(), height: 0.6)
                .padding(.vertical, 2)

            // ── Four colored gem squares — each swings around its own center
            // Only clickable when a paper is pinned (tape frame occupied = isLocked)
            // Vertical text labels appear below each square when swinging starts
            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: gemLabelSpacing) {
                    Button(action: { onLavenderTap(pinnedPaper?.text ?? "喜悦") }) {
                        GemSquare(
                            size: squareSize,
                            colors: lavenderColors,
                            gradientStart: .topLeading,
                            gradientEnd: .bottomTrailing,
                            highlightColor: Color.white,
                            borderLight: Color(red: 250/255, green: 245/255, blue: 255/255),
                            borderDark: Color(red: 130/255, green: 110/255, blue: 170/255),
                            sweepAngle: -28,
                            shadowDx: 0.3,
                            shadowDy: 1.6
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SwingModifier(isActive: isLocked))
                    .allowsHitTesting(isLocked)
                    .opacity(isLocked ? 1.0 : 0.92)

                    verticalLabel("手记", isLocked: isLocked)
                }

                VStack(spacing: gemLabelSpacing) {
                    Button(action: onIcecreamTap) {
                        GemSquare(
                            size: squareSize,
                            colors: icecreamColors,
                            gradientStart: .top,
                            gradientEnd: .bottomTrailing,
                            highlightColor: Color.white,
                            borderLight: Color(red: 255/255, green: 252/255, blue: 245/255),
                        borderDark: Color(red: 80/255, green: 120/255, blue: 90/255),
                            sweepAngle: -15,
                            shadowDx: 0.5,
                            shadowDy: 1.4
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SwingModifier(isActive: isLocked))
                    .allowsHitTesting(isLocked)
                    .opacity(isLocked ? 1.0 : 0.92)

                    verticalLabel("旅行", isLocked: isLocked)
                }

                VStack(spacing: gemLabelSpacing) {
                    Button(action: onBurgundyTap) {
                        GemSquare(
                            size: squareSize,
                            colors: burgundyColors,
                            gradientStart: .topLeading,
                            gradientEnd: .bottomTrailing,
                            highlightColor: Color(red: 255/255, green: 220/255, blue: 228/255),
                            borderLight: Color(red: 232/255, green: 160/255, blue: 178/255),
                            borderDark: Color(red: 60/255, green: 6/255, blue: 22/255),
                            sweepAngle: -22,
                            shadowDx: 0.4,
                            shadowDy: 1.7
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SwingModifier(isActive: isLocked))
                    .allowsHitTesting(isLocked)
                    .opacity(isLocked ? 1.0 : 0.92)

                    verticalLabel("创作", isLocked: isLocked)
                }

                VStack(spacing: gemLabelSpacing) {
                    Button(action: onOceanBlueTap) {
                        GemSquare(
                            size: squareSize,
                            colors: oceanBlueColors,
                            gradientStart: .topTrailing,
                            gradientEnd: .bottomLeading,
                            highlightColor: Color(red: 240/255, green: 250/255, blue: 255/255),
                            borderLight: Color(red: 210/255, green: 232/255, blue: 250/255),
                            borderDark: Color(red: 50/255, green: 96/255, blue: 150/255),
                            sweepAngle: 20,
                            shadowDx: -0.3,
                            shadowDy: 1.5
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SwingModifier(isActive: isLocked))
                    .allowsHitTesting(isLocked)
                    .opacity(isLocked ? 1.0 : 0.92)

                    verticalLabel("运动", isLocked: isLocked)
                }
            }
        }
        .coordinateSpace(.named("grid"))
    }
}

struct HomeModuleView: View {
    var onClose: () -> Void
    var onLavender: (String) -> Void
    var onIcecream: () -> Void
    var onBurgundy: () -> Void
    var onOceanBlue: () -> Void
    var onNegativeMood: (String) -> Void

    // 由父视图传入：app 启动时打乱一次，切 tab / 进出手记页时保持稳定
    var moodTexts: [Int: String] = [:]

    @State private var pinnedPaper: PaperOnSquare? = nil

    var body: some View {
        ZStack {
            Color.cloudDancer
                .ignoresSafeArea()

            // "Days OFF" title at the very top — elegant serif
            VStack {
                Text("Days OFF")
                    .font(.system(size: 52, weight: .light, design: .serif))
                    .foregroundColor(Color(red: 90/255, green: 80/255, blue: 70/255))
                    .padding(.top, 40)

                Spacer()
            }

            SilverGrid(
                squareSize: 32,
                spacing: 24,
                onLavenderTap: onLavender,
                onIcecreamTap: onIcecream,
                onBurgundyTap: onBurgundy,
                onOceanBlueTap: onOceanBlue,
                onHeartTap: onNegativeMood,
                pinnedPaper: $pinnedPaper,
                moodTexts: moodTexts
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: 30)
        }
    }
}

struct HomeModuleView_Previews: PreviewProvider {
    static var previews: some View {
        HomeModuleView(
            onClose: {},
            onLavender: { _ in },
            onIcecream: {},
            onBurgundy: {},
            onOceanBlue: {},
            onNegativeMood: { _ in }
        )
    }
}
