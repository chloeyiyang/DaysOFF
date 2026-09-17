//
//  GalleryView.swift
//  DaysOff
//

import SwiftUI
import PhotosUI
import CoreImage
import UIKit

// MARK: - Gallery Module Color Extensions
fileprivate extension Color {
    static let galleryMellowGold = Color(red: 0.85, green: 0.72, blue: 0.35)
    static let galleryMellowGoldLight = Color(red: 0.95, green: 0.87, blue: 0.55)
    static let galleryMellowGoldDark = Color(red: 0.70, green: 0.55, blue: 0.20)
    static let galleryIceCreamPink = Color(red: 1.0, green: 0.88, blue: 0.92)
    static let galleryIceCreamBlue = Color(red: 0.85, green: 0.92, blue: 1.0)
    static let galleryIceCreamCream = Color(red: 1.0, green: 0.96, blue: 0.88)
    static let galleryIceCreamLavender = Color(red: 0.92, green: 0.88, blue: 0.98)
    static let galleryVelvetDark = Color(red: 0.05, green: 0.03, blue: 0.08)
    static let galleryVelvetMid = Color(red: 0.08, green: 0.05, blue: 0.12)
}

private func galleryLerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

// MARK: - Gallery Module Types
struct GalleryGoldParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var targetPosition: CGPoint
    var size: CGFloat
    var opacity: Double
}

struct GalleryDancingModifier: ViewModifier {
    let delay: Double
    @State private var dancing = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: dancing ? -4 : 4)
            .rotationEffect(.degrees(dancing ? 3 : -3))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    dancing = true
                }
            }
    }
}

struct GallerySparkle: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let twinkleDelay: Double
    let twinkleDuration: Double
    let color: Color
}

// MARK: - GalleryTwinklingStar
struct GalleryTwinklingStar: View {
    let sparkle: GallerySparkle
    @State private var twinkle = false
    
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0.5, y: 0))
                path.addLine(to: CGPoint(x: 1, y: 0.35))
                path.addLine(to: CGPoint(x: 0.7, y: 1))
                path.addLine(to: CGPoint(x: 0.3, y: 1))
                path.addLine(to: CGPoint(x: 0, y: 0.35))
                path.closeSubpath()
            }
            .fill(sparkle.color)
            .frame(width: sparkle.size, height: sparkle.size)
            .opacity(twinkle ? 1.0 : 0.1)
            .scaleEffect(twinkle ? 1.0 : 0.5)
            
            if twinkle {
                Rectangle()
                    .fill(sparkle.color.opacity(0.6))
                    .frame(width: sparkle.size * 3, height: 0.5)
                Rectangle()
                    .fill(sparkle.color.opacity(0.6))
                    .frame(width: 0.5, height: sparkle.size * 3)
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [sparkle.color.opacity(twinkle ? 0.3 : 0.05), sparkle.color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: sparkle.size * 1.5
                    )
                )
                .frame(width: sparkle.size * 3, height: sparkle.size * 3)
                .opacity(twinkle ? 0.7 : 0.15)
        }
        .position(sparkle.position)
        .onAppear {
            withAnimation(
                .easeInOut(duration: sparkle.twinkleDuration)
                .repeatForever(autoreverses: true)
                .delay(sparkle.twinkleDelay)
            ) {
                twinkle = true
            }
        }
    }
}

// MARK: - GalleryTitleScene
struct GalleryTitleScene: View {
    let onComplete: () -> Void
    
    @State private var isShattered = false
    @State private var particles: [GalleryGoldParticle] = []
    @State private var canvasOpacity: Double = 1.0
    @State private var pointing = false
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let goldenRatioY = h * 0.382
            let canvasW = w * 0.78
            let canvasH = h * 0.32
            
            ZStack {
                dreamyBackground(w: w, h: h)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.96, green: 0.93, blue: 0.86).opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                    
                    VStack(spacing: 12) {
                        dancingText
                        
                        Text("👆")
                            .font(.system(size: 28))
                            .offset(y: pointing ? -6 : 0)
                            .onAppear {
                                withAnimation(
                                    .easeInOut(duration: 0.7)
                                    .repeatForever(autoreverses: true)
                                ) {
                                    pointing = true
                                }
                            }
                    }
                }
                .frame(width: canvasW, height: canvasH)
                .position(x: w / 2, y: goldenRatioY)
                .opacity(isShattered ? 0 : canvasOpacity)
                .scaleEffect(isShattered ? 0.7 : 1)
                .rotationEffect(.degrees(isShattered ? 15 : 0))
                
                ForEach(particles) { p in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.galleryMellowGoldLight, Color.galleryMellowGold.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: p.size
                            )
                        )
                        .frame(width: p.size, height: p.size)
                        .position(p.position)
                        .opacity(p.opacity)
                }
            }
            .ignoresSafeArea()
            .onTapGesture {
                triggerShatter(centerX: w / 2, centerY: goldenRatioY)
            }
        }
    }
    
    private func dreamyBackground(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.galleryIceCreamPink,
                    Color.galleryIceCreamLavender,
                    Color.galleryIceCreamBlue,
                    Color.galleryIceCreamCream
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .fill(Color.galleryIceCreamPink.opacity(0.3))
                .frame(width: w * 0.5, height: w * 0.5)
                .blur(radius: 60)
                .position(x: w * 0.2, y: h * 0.7)
            
            Circle()
                .fill(Color.galleryIceCreamBlue.opacity(0.3))
                .frame(width: w * 0.4, height: w * 0.4)
                .blur(radius: 50)
                .position(x: w * 0.85, y: h * 0.3)
            
            Circle()
                .fill(Color.galleryIceCreamLavender.opacity(0.25))
                .frame(width: w * 0.45, height: w * 0.45)
                .blur(radius: 55)
                .position(x: w * 0.7, y: h * 0.8)
        }
        .frame(width: w, height: h)
    }
    
    private var dancingText: some View {
        let chars = Array("第一期线上画展")
        return HStack(spacing: 2) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.pingFang(size: 34, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.60, blue: 0.72),
                                Color(red: 1.0, green: 0.75, blue: 0.82),
                                Color(red: 0.95, green: 0.55, blue: 0.68)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.9, green: 0.5, blue: 0.6).opacity(0.3), radius: 2)
                    .modifier(GalleryDancingModifier(delay: Double(index) * 0.12))
            }
        }
    }
    
    private func triggerShatter(centerX: CGFloat, centerY: CGFloat) {
        let center = CGPoint(x: centerX, y: centerY)
        
        for _ in 0..<80 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 60...280)
            particles.append(GalleryGoldParticle(
                position: center,
                targetPosition: CGPoint(x: center.x + cos(angle) * distance,
                                        y: center.y + sin(angle) * distance),
                size: CGFloat.random(in: 4...11),
                opacity: 1.0
            ))
        }
        
        withAnimation(.easeOut(duration: 1.6)) {
            for i in particles.indices {
                particles[i].position = particles[i].targetPosition
                particles[i].opacity = 0
            }
        }
        
        withAnimation(.easeIn(duration: 0.6)) {
            isShattered = true
            canvasOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

// MARK: - GalleryHallScene
struct GalleryHallScene: View {
    let onExit: () -> Void
    
    enum CanvasState: Int {
        case white = 0
        case blue = 1
        case red = 2
        case ended = 3
    }
    
    @State private var canvasState: CanvasState = .white
    @State private var canvasScale: CGFloat = 0
    @State private var canvasOpacity: Double = 0
    @State private var endTextOpacity: Double = 0
    @State private var sparkles: [GallerySparkle] = []
    @State private var glowPulse = false
    @State private var sheenOffset: CGFloat = -1
    
    private func canvasColor(_ state: CanvasState) -> Color {
        switch state {
        case .white: return Color.white.opacity(0.95)
        case .blue: return Color(red: 0.2, green: 0.4, blue: 0.85).opacity(0.9)
        case .red: return Color(red: 0.82, green: 0.18, blue: 0.22).opacity(0.9)
        case .ended: return .clear
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w / 2
            let centerY = h / 2
            let horizonY = h * 0.30
            
            ZStack {
                velvetBackground(w: w, h: h, horizonY: horizonY)
                
                velvetSheen(w: w, h: h)
                
                ForEach(sparkles) { sparkle in
                    GalleryTwinklingStar(sparkle: sparkle)
                }
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(glowPulse ? 0.10 : 0.05),
                                Color.galleryMellowGold.opacity(0.03),
                                Color.white.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.45
                        )
                    )
                    .frame(width: w * 1.2, height: w * 1.2)
                    .position(x: centerX, y: centerY)
                    .blur(radius: 20)
                
                if canvasState != .ended {
                    let canvasW = w * 0.7
                    let canvasH = h * 0.35
                    
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.45),
                                        Color.black.opacity(0.15),
                                        Color.black.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: canvasW * 0.92, height: canvasH * 0.12)
                            .offset(y: canvasH / 2 + 4)
                            .blur(radius: 6)
                            .opacity(canvasOpacity)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(canvasColor(canvasState))
                            .frame(width: canvasW, height: canvasH)
                            .scaleEffect(canvasScale)
                            .opacity(canvasOpacity)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(0.35),
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0)
                                            ],
                                            center: UnitPoint(x: 0.5, y: 0.35),
                                            startRadius: 0,
                                            endRadius: canvasW * 0.75
                                        )
                                    )
                                    .blendMode(.overlay)
                                    .opacity(canvasOpacity)
                            )
                            .overlay(
                                RadialGradient(
                                    colors: [
                                        Color.galleryMellowGoldLight.opacity(0.12),
                                        Color.galleryMellowGoldLight.opacity(0)
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.35),
                                    startRadius: 0,
                                    endRadius: canvasW * 0.4
                                )
                                .frame(width: canvasW, height: canvasH)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .opacity(canvasOpacity)
                            )
                            .onTapGesture {
                                dismissCanvas()
                            }
                        
                        Path { path in
                            let beamTopY = centerY - canvasH / 2 - h * 0.35
                            let beamTopHalfWidth = canvasW * 0.08
                            let beamBottomHalfWidth = canvasW * 0.42
                            
                            path.move(to: CGPoint(x: centerX - beamTopHalfWidth, y: beamTopY))
                            path.addLine(to: CGPoint(x: centerX + beamTopHalfWidth, y: beamTopY))
                            path.addLine(to: CGPoint(x: centerX + beamBottomHalfWidth, y: centerY - canvasH / 2))
                            path.addLine(to: CGPoint(x: centerX - beamBottomHalfWidth, y: centerY - canvasH / 2))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .opacity(canvasOpacity)
                        .allowsHitTesting(false)
                    }
                }
                
                if canvasState == .ended {
                    VStack(spacing: 24) {
                        Text(L("本次展览到此结束，感谢观看", "This exhibition has ended, thank you for visiting"))
                            .font(.pingFang(size: 20, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.85))

                        Button(action: replay) {
                            Text(L("我想再看一遍", "Watch Again"))
                                .font(.pingFang(size: 16))
                                .foregroundColor(Color.white.opacity(0.8))
                                .padding(.horizontal, 36)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .opacity(endTextOpacity)
                }
                
                VStack {
                    Spacer()
                    Button(action: onExit) {
                        Text(L("退出", "Exit"))
                            .font(.pingFang(size: 16))
                            .foregroundColor(Color.white.opacity(0.8))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            generateSparkles()
            animateCanvas()
            animateSheen()
        }
    }
    
    private func dismissCanvas() {
        withAnimation(.easeIn(duration: 0.4)) {
            canvasScale = 0.5
            canvasOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let next = CanvasState(rawValue: canvasState.rawValue + 1) ?? .ended
            canvasState = next
            
            if next == .ended {
                withAnimation(.easeOut(duration: 0.8)) {
                    endTextOpacity = 1
                }
            } else {
                canvasScale = 0
                canvasOpacity = 0
                withAnimation(.easeOut(duration: 0.6)) {
                    canvasScale = 1
                    canvasOpacity = 1
                }
            }
        }
    }
    
    private func replay() {
        withAnimation(.easeIn(duration: 0.3)) {
            endTextOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            canvasState = .white
            canvasScale = 0
            canvasOpacity = 0
            withAnimation(.easeOut(duration: 0.6)) {
                canvasScale = 1
                canvasOpacity = 1
            }
        }
    }
    
    private func velvetBackground(w: CGFloat, h: CGFloat, horizonY: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.galleryVelvetDark,
                    Color.galleryVelvetMid,
                    Color.galleryVelvetDark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: horizonY))
                path.addLine(to: CGPoint(x: w, y: horizonY))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color.galleryVelvetDark,
                        Color(red: 0.04, green: 0.02, blue: 0.06),
                        Color.galleryVelvetDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Path { path in
                for i in 0..<8 {
                    let progress = pow(CGFloat(i) / 7, 1.5)
                    let y = galleryLerp(horizonY, h, progress)
                    let leftX = galleryLerp(w * 0.3, 0, progress)
                    let rightX = galleryLerp(w * 0.7, w, progress)
                    path.move(to: CGPoint(x: leftX, y: y))
                    path.addLine(to: CGPoint(x: rightX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.015), lineWidth: 1)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.galleryMellowGold.opacity(0.07),
                            Color.galleryMellowGold.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: w * 0.65
                    )
                )
                .frame(width: w * 1.3, height: w * 1.3)
                .position(x: w / 2, y: h / 2)
        }
        .ignoresSafeArea()
    }
    
    private func velvetSheen(w: CGFloat, h: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.04),
                Color.white.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: w * 0.5, height: h)
        .offset(x: sheenOffset * w)
        .blur(radius: 40)
        .blendMode(.screen)
    }
    
    private func generateSparkles() {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let bounds = screen.screen.bounds
        
        for _ in 0..<300 {
            let depthFactor = CGFloat.random(in: 0.3...1.0)
            sparkles.append(GallerySparkle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height)
                ),
                size: CGFloat.random(in: 1...3.5) * depthFactor,
                twinkleDelay: Double.random(in: 0...4),
                twinkleDuration: Double.random(in: 0.8...2.5),
                color: sparkleColor()
            ))
        }
    }
    
    private func sparkleColor() -> Color {
        let colors: [Color] = [
            Color.white,
            Color.white,
            Color.white,
            Color.galleryMellowGoldLight,
            Color.galleryIceCreamPink,
            Color.galleryIceCreamBlue,
            Color.galleryIceCreamLavender
        ]
        return colors.randomElement() ?? .white
    }
    
    private func animateCanvas() {
        withAnimation(.easeOut(duration: 1.5).delay(0.3)) {
            canvasScale = 1
            canvasOpacity = 1
        }
        
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }
    
    private func animateSheen() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: false)) {
            sheenOffset = 1.5
        }
    }
}

// MARK: - GalleryContentView
struct GalleryContentView: View {
    @State private var showPrepareExhibition = false
    @State private var showVisitExhibition = false
    @State private var showExhibitionDetail = false
    @State private var showPictureView = false
    @State private var currentPictureIndex = 0
    @State private var activeExhibition: ActiveExhibition? = nil
    @State private var exhibitionPictures: [PicturePainting] = []
    @State private var selectedNetworkExhibition: NetworkExhibition? = nil
    @ObservedObject private var exhibitionStore = ExhibitionStore.shared
    @Environment(\.dismiss) private var dismiss

    var exhibitionPaintings: [PicturePainting] = []
    var autoShowPrepare: Bool = false
    var autoShowVisit: Bool = false
    var userId: String = ""
    var userName: String = ""
    var onExhibitionConfirmed: ((String) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                if showPrepareExhibition {
                    PrepareExhibitionView(
                        paintings: exhibitionPaintings,
                        username: userName,
                        userId: userId,
                        onBack: {
                            dismiss()
                        },
                        onConfirm: { exhibition, paintings in
                            activeExhibition = exhibition
                            exhibitionPictures = paintings
                            let record = ExhibitionRecord(
                                name: exhibition.name,
                                introduction: exhibition.introduction,
                                startDate: exhibition.startDate,
                                endDate: exhibition.endDate,
                                firstPictureData: paintings.first?.data
                            )
                            saveExhibitionRecord(record)
                            // Directly increment exhibited counts in UserDefaults (bypass callback chain)
                            let exhibitsKey = "gallery_exhibited_counts_\(userId)"
                            var counts: [String: Int] = [:]
                            if let cd = UserDefaults.standard.data(forKey: exhibitsKey),
                               let decoded = try? JSONDecoder().decode([String: Int].self, from: cd) {
                                counts = decoded
                            }
                            for painting in paintings {
                                let key = painting.id.uuidString
                                counts[key] = (counts[key] ?? 0) + 1
                            }
                            if let encoded = try? JSONEncoder().encode(counts) {
                                UserDefaults.standard.set(encoded, forKey: exhibitsKey)
                            }
                            let paintingDataArray = paintings.map { $0.data }
                            let paintingIntros = Array(exhibition.paintingIntroductions.prefix(paintings.count))
                            Task {
                                await exhibitionStore.publish(
                                    userId: userId,
                                    userName: exhibition.username,
                                    name: exhibition.name,
                                    introduction: exhibition.introduction,
                                    startDate: exhibition.startDate,
                                    endDate: exhibition.endDate,
                                    firstPictureData: paintings.first?.data,
                                    paintings: paintingDataArray,
                                    paintingIntroductions: paintingIntros
                                )
                                await exhibitionStore.refreshCommunity(requesterUserId: userId)
                                await MainActor.run {
                                    onExhibitionConfirmed?(exhibition.name)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showPrepareExhibition = false
                                        showVisitExhibition = true
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showVisitExhibition {
                    VisitExhibitionView(
                        networkExhibitions: exhibitionStore.networkExhibitions,
                        userId: userId,
                        onBack: {
                            dismiss()
                        },
                        onSelectExhibition: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showVisitExhibition = false
                                showExhibitionDetail = true
                            }
                        },
                        onSelectNetworkExhibition: { netExhibition in
                            // Convert NetworkExhibition to ActiveExhibition + paintings
                            selectedNetworkExhibition = netExhibition
                            activeExhibition = ActiveExhibition(
                                name: netExhibition.name,
                                introduction: netExhibition.introduction,
                                username: netExhibition.userName,
                                paintingIntroductions: netExhibition.paintingIntroductions,
                                startDate: netExhibition.startDate,
                                endDate: netExhibition.endDate,
                                startTimestamp: netExhibition.timestamp.timeIntervalSince1970
                            )
                            // 异步加载画作图片（本地 Data 或远程 OSS URL）
                            Task {
                                let paintingData = await netExhibition.resolvePaintingData()
                                let pictures = paintingData.compactMap { data -> PicturePainting? in
                                    guard let uiImage = UIImage(data: data) else { return nil }
                                    return PicturePainting(
                                        image: Image(uiImage: uiImage),
                                        data: data,
                                        date: "",
                                        blessing: "",
                                        isPublic: false
                                    )
                                }
                                await MainActor.run {
                                    exhibitionPictures = pictures
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showVisitExhibition = false
                                        showExhibitionDetail = true
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showExhibitionDetail, let exhibition = activeExhibition {
                    ExhibitionDetailView(
                        exhibition: exhibition,
                        paintings: exhibitionPictures,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showExhibitionDetail = false
                                showVisitExhibition = true
                            }
                        },
                        onEnterPictures: {
                            currentPictureIndex = 0
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showExhibitionDetail = false
                                showPictureView = true
                            }
                        }
                    )
                    .transition(.opacity)
                } else if showPictureView, let exhibition = activeExhibition {
                    ExhibitionPictureView(
                        exhibition: exhibition,
                        paintings: exhibitionPictures,
                        currentIndex: currentPictureIndex,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPictureView = false
                                showExhibitionDetail = true
                            }
                        },
                        onExitToEnding: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPictureView = false
                                showExhibitionDetail = false
                                showVisitExhibition = true
                            }
                        },
                        onPrev: {
                            if currentPictureIndex > 0 {
                                currentPictureIndex -= 1
                            }
                        },
                        onNext: {
                            if currentPictureIndex < exhibitionPictures.count - 1 {
                                currentPictureIndex += 1
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                    /*
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showPrepareExhibition = true
                            }
                        }) {
                            ZStack {
                                // 云舞色底 (240, 238, 233)
                                Color(red: 240/255, green: 238/255, blue: 233/255)

                                // 左上桃粉+柠檬黄+樱花粉晕染（紧贴角落，占色块约20%面积）
                                RadialGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.85, blue: 0.78).opacity(0.65),  // peach
                                        Color(red: 1.0, green: 0.98, blue: 0.72).opacity(0.48),  // lemon yellow
                                        Color(red: 1.0, green: 0.82, blue: 0.88).opacity(0.28),  // sakura pink
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.06, y: 0.05),
                                    startRadius: 5,
                                    endRadius: 100
                                )
                                .blur(radius: 18)

                                // 底部玫瑰+粉+驼色晕染（紧贴角落）
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.95, green: 0.55, blue: 0.62).opacity(0.55),  // rose
                                        Color(red: 0.98, green: 0.72, blue: 0.80).opacity(0.36),  // pink
                                        Color(red: 0.76, green: 0.58, blue: 0.38).opacity(0.20),  // camel
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.92, y: 0.96),
                                    startRadius: 5,
                                    endRadius: 90
                                )
                                .blur(radius: 20)

                                VStack(spacing: 8) {
                                    Text(L("准备我的画展", "Prepare My Exhibition"))
                                        .font(.pingFang(size: 36, weight: .bold))
                                        .foregroundColor(Color(red: 0.45, green: 0.30, blue: 0.20))

                                    Text(L("策展你的专属艺术空间", "Curate your personal art space"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(red: 0.45, green: 0.30, blue: 0.20).opacity(0.7))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            loadActiveExhibition()
                            fetchNetworkExhibitions()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showVisitExhibition = true
                            }
                        }) {
                            GeometryReader { geo in
                                ZStack {
                                    // 陶土色底
                                    Color(red: 0.76, green: 0.46, blue: 0.32)

                                    // 桃绒毛质感层
                                    // 1. 整体柔和桃色渐变覆盖
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.96, green: 0.76, blue: 0.68).opacity(0.35),
                                            Color(red: 0.90, green: 0.62, blue: 0.52).opacity(0.18),
                                            Color(red: 0.82, green: 0.52, blue: 0.40).opacity(0.28)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )

                                    // 2. 多处柔和光晕晕染点，模拟绒毛光泽
                                    RadialGradient(
                                        colors: [
                                            Color(red: 1.00, green: 0.85, blue: 0.75).opacity(0.22),
                                            Color.clear
                                        ],
                                        center: UnitPoint(x: 0.15, y: 0.20),
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.45
                                    )
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.98, green: 0.82, blue: 0.70).opacity(0.18),
                                            Color.clear
                                        ],
                                        center: UnitPoint(x: 0.88, y: 0.35),
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.40
                                    )
                                    RadialGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.74, blue: 0.62).opacity(0.14),
                                            Color.clear
                                        ],
                                        center: UnitPoint(x: 0.55, y: 0.80),
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.50
                                    )
                                    RadialGradient(
                                        colors: [
                                            Color(red: 1.00, green: 0.88, blue: 0.78).opacity(0.12),
                                            Color.clear
                                        ],
                                        center: UnitPoint(x: 0.30, y: 0.90),
                                        startRadius: 0,
                                        endRadius: geo.size.width * 0.35
                                    )

                                    // 3. 细微粉色高光点缀，模拟绒毛纤维反光
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.12))
                                        .frame(width: 3, height: 3)
                                        .position(x: geo.size.width * 0.12, y: geo.size.height * 0.18)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.92, blue: 0.84).opacity(0.10))
                                        .frame(width: 2, height: 2)
                                        .position(x: geo.size.width * 0.25, y: geo.size.height * 0.55)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.88, blue: 0.80).opacity(0.11))
                                        .frame(width: 2.5, height: 2.5)
                                        .position(x: geo.size.width * 0.82, y: geo.size.height * 0.28)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.09))
                                        .frame(width: 2, height: 2)
                                        .position(x: geo.size.width * 0.70, y: geo.size.height * 0.72)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.92, blue: 0.85).opacity(0.11))
                                        .frame(width: 3, height: 3)
                                        .position(x: geo.size.width * 0.45, y: geo.size.height * 0.42)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.88, blue: 0.78).opacity(0.09))
                                        .frame(width: 2, height: 2)
                                        .position(x: geo.size.width * 0.92, y: geo.size.height * 0.88)
                                    Circle()
                                        .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.12))
                                        .frame(width: 2.5, height: 2.5)
                                        .position(x: geo.size.width * 0.08, y: geo.size.height * 0.78)

                                    VStack(spacing: 8) {
                                        Text(L("参观当前展览", "Visit Current Exhibition"))
                                            .font(.pingFang(size: 36, weight: .bold))
                                            .foregroundColor(.white)

                                        Text(L("走进虚拟艺术展厅", "Step into a virtual art gallery"))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                     */
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showExhibitionDetail && !showPictureView && !showPrepareExhibition && !showVisitExhibition {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(L("返回", "Back"))
                            }
                        }
                    }
                }
            }
        }
        .networkErrorBanner(show: $exhibitionStore.showNetworkError)
        .networkErrorBanner(show: $exhibitionStore.showModerationAlert, message: exhibitionStore.moderationMessage)
        .onAppear {
            loadActiveExhibition()
            if autoShowPrepare && !showPrepareExhibition {
                showPrepareExhibition = true
            }
            if autoShowVisit && !showVisitExhibition {
                fetchNetworkExhibitions()
                showVisitExhibition = true
            }
            // Re-publish local exhibition to server in case server was restarted
            republishLocalExhibitionIfNeeded()
        }
    }

    private func fetchNetworkExhibitions() {
        Task { await exhibitionStore.refreshCommunity(requesterUserId: userId) }
    }

    private func loadActiveExhibition() {
        let exhibitionKey = "gallery_active_exhibition_\(userId)"
        let picturesKey = "gallery_active_exhibition_pictures_\(userId)"
        if let data = UserDefaults.standard.data(forKey: exhibitionKey),
           let exhibition = try? JSONDecoder().decode(ActiveExhibition.self, from: data) {
            let weekInSeconds: Double = 7 * 24 * 3600
            if Date().timeIntervalSince1970 > exhibition.startTimestamp + weekInSeconds {
                UserDefaults.standard.removeObject(forKey: exhibitionKey)
                UserDefaults.standard.removeObject(forKey: picturesKey)
                activeExhibition = nil
                exhibitionPictures = []
            } else {
                activeExhibition = exhibition
                if let picData = UserDefaults.standard.data(forKey: picturesKey),
                   let dataList = try? JSONDecoder().decode([Data].self, from: picData) {
                    exhibitionPictures = dataList.compactMap { data in
                        guard let uiImage = UIImage(data: data) else { return nil }
                        return PicturePainting(
                            image: Image(uiImage: uiImage),
                            data: data,
                            date: "",
                            blessing: "",
                            isPublic: false
                        )
                    }
                }
            }
        }
    }

    /// Re-publish the local active exhibition to the server so other users can see it.
    /// This handles the case where the server was restarted (losing in-memory data)
    /// but the user's exhibition is still in local UserDefaults.
    private func republishLocalExhibitionIfNeeded() {
        guard let exhibition = activeExhibition, !exhibitionPictures.isEmpty else { return }
        let paintingDataArray = exhibitionPictures.map { $0.data }
        let paintingIntros = Array(exhibition.paintingIntroductions.prefix(paintingDataArray.count))
        Task {
            let published = await exhibitionStore.publish(
                userId: userId,
                userName: userName,
                name: exhibition.name,
                introduction: exhibition.introduction,
                startDate: exhibition.startDate,
                endDate: exhibition.endDate,
                firstPictureData: paintingDataArray.first,
                paintings: paintingDataArray,
                paintingIntroductions: paintingIntros
            )
            if published {
                print("[Gallery] Re-published local exhibition '\(exhibition.name)' to server")
            }
        }
    }
}

// MARK: - DiamondHallBackground
struct DiamondHallBackground: View {
    @State private var sparkles: [GallerySparkle] = []
    @State private var glowPulse = false
    @State private var sheenOffset: CGFloat = -1
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w / 2
            let centerY = h / 2
            let horizonY = h * 0.30
            
            ZStack {
                velvetBackground(w: w, h: h, horizonY: horizonY)
                
                velvetSheen(w: w, h: h)
                
                ForEach(sparkles) { sparkle in
                    GalleryTwinklingStar(sparkle: sparkle)
                }
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(glowPulse ? 0.10 : 0.05),
                                Color.galleryMellowGold.opacity(0.03),
                                Color.white.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.45
                        )
                    )
                    .frame(width: w * 1.2, height: w * 1.2)
                    .position(x: centerX, y: centerY)
                    .blur(radius: 20)
            }
        }
        .onAppear {
            generateSparkles()
            animateSheen()
        }
    }
    
    private func velvetBackground(w: CGFloat, h: CGFloat, horizonY: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.galleryVelvetDark,
                    Color.galleryVelvetMid,
                    Color.galleryVelvetDark
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: horizonY))
                path.addLine(to: CGPoint(x: w, y: horizonY))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color.galleryVelvetDark,
                        Color(red: 0.04, green: 0.02, blue: 0.06),
                        Color.galleryVelvetDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Path { path in
                for i in 0..<8 {
                    let progress = pow(CGFloat(i) / 7, 1.5)
                    let y = galleryLerp(horizonY, h, progress)
                    let leftX = galleryLerp(w * 0.3, 0, progress)
                    let rightX = galleryLerp(w * 0.7, w, progress)
                    path.move(to: CGPoint(x: leftX, y: y))
                    path.addLine(to: CGPoint(x: rightX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.015), lineWidth: 1)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.galleryMellowGold.opacity(0.07),
                            Color.galleryMellowGold.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: w * 0.65
                    )
                )
                .frame(width: w * 1.3, height: w * 1.3)
                .position(x: w / 2, y: h / 2)
        }
        .ignoresSafeArea()
    }
    
    private func velvetSheen(w: CGFloat, h: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(0.04),
                Color.white.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: w * 0.5, height: h)
        .offset(x: sheenOffset * w)
        .blur(radius: 40)
        .blendMode(.screen)
    }
    
    private func generateSparkles() {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let bounds = screen.screen.bounds
        
        for _ in 0..<300 {
            let depthFactor = CGFloat.random(in: 0.3...1.0)
            sparkles.append(GallerySparkle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...bounds.width),
                    y: CGFloat.random(in: 0...bounds.height)
                ),
                size: CGFloat.random(in: 1...3.5) * depthFactor,
                twinkleDelay: Double.random(in: 0...4),
                twinkleDuration: Double.random(in: 0.8...2.5),
                color: .white
            ))
        }
    }
    
    private func animateSheen() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            sheenOffset = 2
        }
        
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
    }
}

// MARK: - Exhibition Model
struct ExhibitionDraft: Codable {
    var name: String
    var introduction: String
    var paintingIntroductions: [String]
    var paintingDataList: [Data]
}

struct ActiveExhibition: Codable {
    let name: String
    let introduction: String
    let username: String
    let paintingIntroductions: [String]
    let startDate: String
    let endDate: String
    let startTimestamp: Double
}

private let kExhibitionDraftKey = "gallery_exhibition_draft"
private let kActiveExhibitionKey = "gallery_active_exhibition"
private let kActiveExhibitionPicturesKey = "gallery_active_exhibition_pictures"
private let kExhibitionHistoryKey = "gallery_exhibition_history"
private let kUserUploadedPicturesKey = "gallery_user_uploaded_pictures"

func saveUserPictureData(_ data: Data) {
    var list = loadUserPictureData()
    list.append(data)
    UserDefaults.standard.set(list, forKey: kUserUploadedPicturesKey)
}

func loadUserPictureData() -> [Data] {
    UserDefaults.standard.array(forKey: kUserUploadedPicturesKey) as? [Data] ?? []
}



// 用于「我的」页面展示的展览记录
struct ExhibitionRecord: Codable {
    let name: String
    let introduction: String
    let startDate: String
    let endDate: String
    let firstPictureData: Data?
}

func saveExhibitionRecord(_ record: ExhibitionRecord) {
    var records = loadExhibitionRecords()
    records.append(record)
    if let data = try? JSONEncoder().encode(records) {
        UserDefaults.standard.set(data, forKey: kExhibitionHistoryKey)
    }
}

func loadExhibitionRecords() -> [ExhibitionRecord] {
    guard let data = UserDefaults.standard.data(forKey: kExhibitionHistoryKey),
          let records = try? JSONDecoder().decode([ExhibitionRecord].self, from: data) else {
        return []
    }
    return records
}

// MARK: - 古董粉墙面（antique pink 218,136,144）
struct AntiquePinkWall: View {
    private let baseColor = Color(red: 218/255, green: 136/255, blue: 144/255)

    private func darkGrainOffset(index: Int) -> CGPoint {
        let x = sin(Double(index * 73) * 0.1) * 0.5 + 0.5
        let y = cos(Double(index * 117) * 0.1) * 0.5 + 0.5
        return CGPoint(x: x, y: y)
    }

    private func darkGrainSize(index: Int) -> CGFloat {
        CGFloat(sin(Double(index * 31) * 0.1) * 0.5 + 1) * 1.4
    }

    private func lightGrainOffset(index: Int) -> CGPoint {
        let x = sin(Double(index * 57 + 10) * 0.1) * 0.5 + 0.5
        let y = cos(Double(index * 133 + 20) * 0.1) * 0.5 + 0.5
        return CGPoint(x: x, y: y)
    }

    private func lightGrainSize(index: Int) -> CGFloat {
        CGFloat(sin(Double(index * 29) * 0.1) * 0.5 + 0.8) * 1.2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 墙面底色：古董粉 + 上下渐变（顶部受光稍亮，底部背光稍暗）
                LinearGradient(
                    colors: [
                        baseColor.opacity(0.92),
                        baseColor,
                        baseColor.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 左上柔光（模拟射灯从左上方打来）
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.08),
                        .clear
                    ],
                    center: UnitPoint(x: 0.15, y: 0.12),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.7
                )
                .ignoresSafeArea()
                .blur(radius: 30)

                // 右下阴影（墙角背光处）
                RadialGradient(
                    colors: [
                        Color(red: 0.45, green: 0.20, blue: 0.25).opacity(0.28),
                        Color(red: 0.50, green: 0.25, blue: 0.30).opacity(0.12),
                        .clear
                    ],
                    center: UnitPoint(x: 0.85, y: 0.90),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.75
                )
                .ignoresSafeArea()
                .blur(radius: 35)

                // 暗色颗粒（墙面细微凹凸的阴影）
                ForEach(0..<140, id: \.self) { i in
                    let offset = darkGrainOffset(index: i)
                    let size = darkGrainSize(index: i)
                    Circle()
                        .fill(Color(red: 0.50, green: 0.22, blue: 0.28).opacity(0.06))
                        .frame(width: size, height: size)
                        .position(x: offset.x * geo.size.width, y: offset.y * geo.size.height)
                }

                // 亮色颗粒（墙面细微反光）
                ForEach(0..<100, id: \.self) { i in
                    let offset = lightGrainOffset(index: i)
                    let size = lightGrainSize(index: i)
                    Circle()
                        .fill(Color(red: 1.0, green: 0.92, blue: 0.90).opacity(0.10))
                        .frame(width: size, height: size)
                        .position(x: offset.x * geo.size.width, y: offset.y * geo.size.height)
                }

                // 整体微噪点纹理（Canvas 随机斑点，模拟灰泥质感）
                Canvas { context, size in
                    for i in 0..<300 {
                        let s = Double(i)
                        let x = (sin(s * 130.3) * 0.5 + 0.5) * size.width
                        let y = (cos(s * 271.9) * 0.5 + 0.5) * size.height
                        let r: CGFloat = 0.6 + CGFloat(sin(s * 17.3)) * 0.4
                        let isLight = Int(s) % 3 == 0
                        let c = isLight
                            ? Color.white.opacity(0.06)
                            : Color(red: 0.50, green: 0.22, blue: 0.28).opacity(0.05)
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                     with: .color(c))
                    }
                }
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - PrepareExhibitionView
struct PrepareExhibitionView: View {
    let paintings: [PicturePainting]
    let username: String
    let userId: String
    let onBack: () -> Void
    let onConfirm: (ActiveExhibition, [PicturePainting]) -> Void
    
    @State private var exhibitionName: String = ""
    @State private var exhibitionIntro: String = ""
    @State private var introductions: [String]
    @State private var showPopup = false
    @State private var showSaveToast = false
    @State private var draftPaintings: [PicturePainting] = []
    @AppStorage(kExhibitionDraftKey) private var draftData: Data = Data()
    
    private var effectivePaintings: [PicturePainting] {
        draftPaintings.isEmpty ? paintings : draftPaintings
    }

    private enum MoveDirection { case up, down }

    private func movePicture(at index: Int, direction: MoveDirection) {
        let target: Int
        switch direction {
        case .up: target = index - 1
        case .down: target = index + 1
        }
        guard draftPaintings.indices.contains(index),
              draftPaintings.indices.contains(target) else { return }
        draftPaintings.swapAt(index, target)
        if introductions.indices.contains(index) && introductions.indices.contains(target) {
            introductions.swapAt(index, target)
        }
    }
    
    init(paintings: [PicturePainting], username: String, userId: String, onBack: @escaping () -> Void, onConfirm: @escaping (ActiveExhibition, [PicturePainting]) -> Void) {
        self.paintings = paintings
        self.username = username
        self.userId = userId
        self.onBack = onBack
        self.onConfirm = onConfirm
        self._introductions = State(initialValue: Array(repeating: "", count: max(paintings.count, 10)))
        // 初始化草稿图片为传入的图片，便于重排序
        self._draftPaintings = State(initialValue: paintings)
    }
    
    private var allFieldsFilled: Bool {
        guard !exhibitionName.trimmingCharacters(in: .whitespaces).isEmpty,
              !exhibitionIntro.trimmingCharacters(in: .whitespaces).isEmpty,
              !effectivePaintings.isEmpty else { return false }
        for i in 0..<effectivePaintings.count {
            if !introductions.indices.contains(i) || introductions[i].trimmingCharacters(in: .whitespaces).isEmpty {
                return false
            }
        }
        return true
    }
    
    private var body_inner: some View {
        ZStack {
            // 古董粉墙面（antique pink 218,136,144）+ 光影 + 纹理
            AntiquePinkWall()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(L("展览名称", "Exhibition Name"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.40, green: 0.35, blue: 0.30))

                        TextField(L("输入展览名称...", "Enter exhibition name..."), text: $exhibitionName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(red: 0.30, green: 0.25, blue: 0.20))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 0.60, green: 0.50, blue: 0.40).opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 20)

                    VStack(spacing: 12) {
                        Text(L("展览介绍", "Exhibition Intro"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.40, green: 0.35, blue: 0.30))

                        ZStack(alignment: .topLeading) {
                            if exhibitionIntro.isEmpty {
                                Text(L("输入展览介绍...", "Enter exhibition intro..."))
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.50, green: 0.45, blue: 0.40).opacity(0.5))
                                .padding(.top, 12)
                                .padding(.leading, 16)
                            }

                            TextEditor(text: $exhibitionIntro)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.30, green: 0.25, blue: 0.20))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 100)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(red: 0.60, green: 0.50, blue: 0.40).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)

                    if effectivePaintings.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45).opacity(0.4))

                            Text(L("请先在我的作品中选择10幅作品", "Please select 10 artworks from My Works first"))
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.35).opacity(0.7))
                        }
                        .frame(height: 300)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(effectivePaintings.enumerated()), id: \.element.id) { index, painting in
                                HStack(spacing: 12) {
                                    painting.image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(L("作品 \(index + 1)", "Artwork \(index + 1)"))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color(red: 0.40, green: 0.35, blue: 0.30))

                                        ZStack(alignment: .topLeading) {
                                            if introductions.indices.contains(index) && introductions[index].isEmpty {
                                                Text(L("输入作品介绍...", "Enter artwork intro..."))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(red: 0.50, green: 0.45, blue: 0.40).opacity(0.5))
                                                    .padding(.top, 10)
                                                    .padding(.leading, 12)
                                            }

                                            TextEditor(text: bindingForIntroduction(at: index))
                                                .font(.system(size: 14))
                                                .foregroundColor(Color(red: 0.30, green: 0.25, blue: 0.20))
                                                .scrollContentBackground(.hidden)
                                                .padding(8)
                                                .frame(minHeight: 80)
                                        }
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.7))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color(red: 0.60, green: 0.50, blue: 0.40).opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }

                                    VStack(spacing: 8) {
                                        Button(action: { movePicture(at: index, direction: .up) }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(index > 0 ? Color(red: 0.40, green: 0.35, blue: 0.30) : Color(red: 0.60, green: 0.55, blue: 0.50).opacity(0.3))
                                                .frame(width: 30, height: 30)
                                        }
                                        .disabled(index == 0)

                                        Button(action: { movePicture(at: index, direction: .down) }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(index < effectivePaintings.count - 1 ? Color(red: 0.40, green: 0.35, blue: 0.30) : Color(red: 0.60, green: 0.55, blue: 0.50).opacity(0.3))
                                                .frame(width: 30, height: 30)
                                        }
                                        .disabled(index == effectivePaintings.count - 1)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Button(action: {
                            showPopup = true
                        }) {
                            Text(L("发布", "Publish"))
                                .font(.pingFang(size: 18, weight: .semibold))
                                .foregroundColor(allFieldsFilled ? .white : .white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(allFieldsFilled ? Color.burgundy : Color.burgundy.opacity(0.4))
                                )
                        }
                        .disabled(!allFieldsFilled)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    Color.clear.frame(height: 40)
                }
            }
            
            if showSaveToast {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(L("已保存", "Saved"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                    )
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
            }
            
            if showPopup {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showPopup = false }
                
                VStack(spacing: 16) {
                    Text(L("您的展览「\(exhibitionName)」", "Your exhibition \"\(exhibitionName)\""))
                        .font(.pingFang(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text(L("已进入画廊", "has entered the gallery"))
                        .font(.pingFang(size: 20, weight: .semibold))
                        .foregroundColor(Color.galleryMellowGold)

                    Text(L("将从今天起展示一周", "will be displayed for one week starting today"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Button(action: {
                        showPopup = false
                        let now = Date()
                        let end = Calendar.current.date(byAdding: .day, value: 7, to: now)!
                        let exhibition = ActiveExhibition(
                            name: exhibitionName,
                            introduction: exhibitionIntro,
                            username: username,
                            paintingIntroductions: Array(introductions.prefix(effectivePaintings.count)),
                            startDate: dateString(from: now),
                            endDate: dateString(from: end),
                            startTimestamp: now.timeIntervalSince1970
                        )
                        saveActiveExhibition(exhibition, paintings: effectivePaintings)
                        clearDraft()
                        onConfirm(exhibition, effectivePaintings)
                    }) {
                        Text(L("确定", "Confirm"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.galleryMellowGold.opacity(0.8))
                            )
                    }
                    .padding(.top, 8)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.15, green: 0.10, blue: 0.20).opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.galleryMellowGold.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPopup)
        .animation(.easeInOut(duration: 0.3), value: showSaveToast)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("返回", "Back"))
                    }
                    .foregroundColor(Color(red: 0.40, green: 0.35, blue: 0.30))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: saveDraft) {
                    Text(L("保存", "Save"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.40, green: 0.35, blue: 0.30))
                }
            }
        }
        .onAppear { loadDraft() }
    }
    
    var body: some View {
        body_inner
    }
    
    private func saveDraft() {
        let dataList = effectivePaintings.map { $0.data }
        let draft = ExhibitionDraft(
            name: exhibitionName,
            introduction: exhibitionIntro,
            paintingIntroductions: introductions,
            paintingDataList: dataList
        )
        if let encoded = try? JSONEncoder().encode(draft) {
            draftData = encoded
        }
        showSaveToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSaveToast = false
        }
    }
    
    private func loadDraft() {
        guard !draftData.isEmpty else { return }
        if let draft = try? JSONDecoder().decode(ExhibitionDraft.self, from: draftData) {
            exhibitionName = draft.name
            exhibitionIntro = draft.introduction
            if !draft.paintingDataList.isEmpty {
                draftPaintings = draft.paintingDataList.compactMap { data in
                    guard let uiImage = UIImage(data: data) else { return nil }
                    return PicturePainting(
                        image: Image(uiImage: uiImage),
                        data: data,
                        date: "",
                        blessing: "",
                        isPublic: false
                    )
                }
                if introductions.count < draftPaintings.count {
                    introductions = Array(repeating: "", count: draftPaintings.count)
                }
            }
            for (i, intro) in draft.paintingIntroductions.enumerated() {
                if introductions.indices.contains(i) {
                    introductions[i] = intro
                }
            }
        }
    }
    
    private func clearDraft() {
        draftData = Data()
        draftPaintings = []
    }
    
    private func saveActiveExhibition(_ exhibition: ActiveExhibition, paintings: [PicturePainting]) {
        let exhibitionKey = "gallery_active_exhibition_\(userId)"
        let picturesKey = "gallery_active_exhibition_pictures_\(userId)"
        if let encoded = try? JSONEncoder().encode(exhibition) {
            UserDefaults.standard.set(encoded, forKey: exhibitionKey)
        }
        let dataList = paintings.map { $0.data }
        if let encoded = try? JSONEncoder().encode(dataList) {
            UserDefaults.standard.set(encoded, forKey: picturesKey)
        }
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
    
    private func bindingForIntroduction(at index: Int) -> Binding<String> {
        Binding(
            get: { introductions.indices.contains(index) ? introductions[index] : "" },
            set: { newValue in
                if introductions.indices.contains(index) {
                    introductions[index] = newValue
                }
            }
        )
    }
}

// MARK: - VisitExhibitionView
struct VisitExhibitionView: View {
    let networkExhibitions: [NetworkExhibition]
    let userId: String
    let onBack: () -> Void
    let onSelectExhibition: () -> Void
    let onSelectNetworkExhibition: (NetworkExhibition) -> Void
    @ObservedObject var exhibitionStore = ExhibitionStore.shared

    @State private var activeExhibition: ActiveExhibition? = nil
    @State private var reportingExhibition: NetworkExhibition? = nil
    @State private var showReportSuccess = false
    @State private var reportSuccessMessage = ""
    @State private var isSubmittingReport = false

    var body: some View {
        ZStack {
            DiamondHallBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Local exhibition (my own)
                    if let exhibition = activeExhibition {
                        VStack(spacing: 4) {
                            Text(L("我的展览", "My Exhibitions"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Button(action: onSelectExhibition) {
                                HStack(spacing: 8) {
                                    Text(exhibition.name)
                                        .font(.pingFang(size: 24, weight: .bold))
                                        .foregroundColor(.white)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color.galleryMellowGold)
                                }
                            }

                            Text(L("展期：\(exhibition.startDate) - \(exhibition.endDate)", "Duration: \(exhibition.startDate) - \(exhibition.endDate)"))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 40)
                    }

                    // Network exhibitions (from all users)
                    if !networkExhibitions.isEmpty {
                        VStack(spacing: 12) {
                            Text(L("社群展览", "Community Exhibition"))
                                .font(.pingFang(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, activeExhibition != nil ? 20 : 40)

                            ForEach(networkExhibitions) { exh in
                                HStack(spacing: 12) {
                                    Button(action: { onSelectNetworkExhibition(exh) }) {
                                        HStack(spacing: 12) {
                                            if let picData = exh.firstPictureData,
                                               let uiImage = UIImage(data: picData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 56, height: 56)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else if let urlStr = exh.firstPictureURL,
                                                      let url = URL(string: urlStr) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .empty:
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.white.opacity(0.15))
                                                            .frame(width: 56, height: 56)
                                                            .overlay(ProgressView())
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 56, height: 56)
                                                            .clipped()
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    case .failure:
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.white.opacity(0.15))
                                                            .frame(width: 56, height: 56)
                                                            .overlay(
                                                                Image(systemName: "photo")
                                                                    .foregroundColor(.white.opacity(0.3))
                                                            )
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(width: 56, height: 56)
                                                    .overlay(
                                                        Image(systemName: "photo")
                                                            .foregroundColor(.white.opacity(0.3))
                                                    )
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exh.name)
                                                    .font(.pingFang(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Text("\(exh.userName) · \(exh.startDate) - \(exh.endDate)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color.galleryMellowGold)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)

                                    // 举报按钮（不属于自己的展览才显示）
                                    if exh.userId != userId {
                                        Button(action: {
                                            reportingExhibition = exh
                                        }) {
                                            Image(systemName: "exclamationmark.circle")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white.opacity(0.4))
                                                .frame(width: 32, height: 32)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if activeExhibition == nil && networkExhibitions.isEmpty {
                        VStack(spacing: 24) {
                            Text(L("当前暂无展览", "No Current Exhibitions"))
                                .font(.pingFang(size: 28, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))

                            Text(L("敬请期待新的艺术展览", "Stay tuned for new art exhibitions"))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.top, 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }

            // 举报弹窗
            if let exh = reportingExhibition {
                reportOverlay(for: exh)
            }

            // 举报成功提示
            if showReportSuccess {
                successToast
            }
        }
        .networkErrorBanner(show: $exhibitionStore.showNetworkError)
        .networkErrorBanner(show: $exhibitionStore.showModerationAlert, message: exhibitionStore.moderationMessage)
        .onAppear { loadActiveExhibition() }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("返回", "Back"))
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - 举报弹窗
    private func reportOverlay(for exh: NetworkExhibition) -> some View {
        let reasons = ["垃圾内容", "不当内容", "侵权作品", "骚扰或恶意", "其他"]
        return ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { reportingExhibition = nil }

            VStack(spacing: 20) {
                Text(L("举报展览", "Report Exhibition"))
                    .font(.pingFang(size: 20, weight: .semibold))
                    .foregroundColor(.pictureTextDark)

                Text("「\(exh.name)」")
                    .font(.pingFang(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                VStack(spacing: 0) {
                    ForEach(reasons, id: \.self) { reason in
                        Button(action: {
                            submitReport(exhibition: exh, reason: reason, alsoBlock: false)
                        }) {
                            HStack {
                                Text(reason)
                                    .font(.pingFang(size: 16))
                                    .foregroundColor(.pictureTextDark)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(
                                Color.gray.opacity(0.05)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmittingReport)

                        if reason != reasons.last {
                            Divider()
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )

                // 举报并拉黑该用户
                Button(action: {
                    submitReport(exhibition: exh, reason: "不当内容", alsoBlock: true)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 14))
                        Text(L("举报并拉黑该用户", "Report and Block User"))
                            .font(.pingFang(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.burgundy)
                    .cornerRadius(8)
                }
                .disabled(isSubmittingReport)

                Button(action: { reportingExhibition = nil }) {
                    Text(L("取消", "Cancel"))
                        .font(.pingFang(size: 16))
                        .foregroundColor(.gray)
                }
                .disabled(isSubmittingReport)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        }
    }

    // MARK: - 举报成功提示
    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(reportSuccessMessage)
                    .font(.pingFang(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.75))
            .cornerRadius(12)
            .padding(.bottom, 60)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 提交举报
    private func submitReport(exhibition: NetworkExhibition, reason: String, alsoBlock: Bool) {
        guard !isSubmittingReport else { return }
        isSubmittingReport = true

        Task {
            let message = await exhibitionStore.report(
                exhibitionId: exhibition.id,
                reporterUserId: userId,
                reason: reason,
                blockedUserId: exhibition.userId,
                alsoBlock: alsoBlock
            )
            await MainActor.run {
                isSubmittingReport = false
                reportingExhibition = nil
                if let message {
                    reportSuccessMessage = message
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReportSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showReportSuccess = false
                        }
                    }
                }
                // message == nil → 举报失败，Store 已触发网络错误横幅
            }
        }
    }

    private func loadActiveExhibition() {
        let exhibitionKey = "gallery_active_exhibition_\(userId)"
        if let data = UserDefaults.standard.data(forKey: exhibitionKey),
           let exhibition = try? JSONDecoder().decode(ActiveExhibition.self, from: data) {
            let weekInSeconds: Double = 7 * 24 * 3600
            if Date().timeIntervalSince1970 > exhibition.startTimestamp + weekInSeconds {
                UserDefaults.standard.removeObject(forKey: exhibitionKey)
                activeExhibition = nil
            } else {
                activeExhibition = exhibition
            }
        }
    }
}

// MARK: - ExhibitionDetailView
struct ExhibitionDetailView: View {
    let exhibition: ActiveExhibition
    let paintings: [PicturePainting]
    let onBack: () -> Void
    let onEnterPictures: () -> Void
    
    var body: some View {
        ZStack {
            DiamondHallBackground()
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(exhibition.name)
                        .font(.pingFang(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(exhibition.username)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 20)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("展览介绍", "Exhibition Intro"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(exhibition.introduction)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(6)
                    }
                    
                    Spacer()
                    
                    Button(action: onEnterPictures) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.galleryMellowGold)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.galleryMellowGold.opacity(0.5), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("返回", "Back"))
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - ExhibitionPictureView
struct ExhibitionPictureView: View {
    let exhibition: ActiveExhibition
    let paintings: [PicturePainting]
    let currentIndex: Int
    let onBack: () -> Void
    let onExitToEnding: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void

    @State private var showEnding = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var lastPanOffset: CGSize = .zero
    private let maxZoom: CGFloat = 1.5

    var body: some View {
        ZStack {
            DiamondHallBackground()

            if showEnding {
                VStack {
                    Spacer()
                    Text(L("展览结束，感谢您的参观", "Exhibition ended, thank you for visiting"))
                        .font(.pingFang(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(exhibition.name)
                            .font(.pingFang(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(exhibition.username)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 20)

                    Spacer()

                    if paintings.indices.contains(currentIndex) {
                        paintings[currentIndex].image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 350)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                            .padding(.horizontal, 24)
                            .scaleEffect(zoomScale)
                            .offset(panOffset)
                            .animation(.easeInOut(duration: 0.2), value: zoomScale)
                            .animation(.easeInOut(duration: 0.2), value: panOffset)
                            .contentShape(Rectangle())
                            .gesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = lastZoomScale * value
                                            zoomScale = min(max(newScale, 1.0), maxZoom)
                                            clampPanToBounds()
                                        }
                                        .onEnded { _ in
                                            lastZoomScale = zoomScale
                                            if zoomScale <= 1.01 {
                                                resetZoomPan()
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            guard zoomScale > 1.01 else { return }
                                            panOffset.width = lastPanOffset.width + value.translation.width
                                            panOffset.height = lastPanOffset.height + value.translation.height
                                            clampPanToBounds()
                                        }
                                        .onEnded { _ in
                                            lastPanOffset = panOffset
                                        }
                                )
                            )
                            .onTapGesture(count: 2) {
                                if zoomScale > 1.01 {
                                    resetZoomPan()
                                } else {
                                    zoomScale = maxZoom
                                    lastZoomScale = maxZoom
                                }
                            }
                            .onChange(of: currentIndex) { _, _ in
                                resetZoomPan()
                            }
                    }

                    Spacer()

                    VStack(spacing: 8) {
                        if exhibition.paintingIntroductions.indices.contains(currentIndex) {
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(exhibition.paintingIntroductions[currentIndex])
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(5)
                                    .padding(.horizontal, 24)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(maxHeight: 120)
                        }

                        Text("\(currentIndex + 1) / \(paintings.count)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 20)

                    HStack(spacing: 40) {
                        if currentIndex > 0 {
                            Button(action: onPrev) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.15))
                                    )
                            }
                        } else {
                            Color.clear.frame(width: 50, height: 50)
                        }

                        Button(action: {
                            if currentIndex < paintings.count - 1 {
                                onNext()
                            } else {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    showEnding = true
                                }
                            }
                        }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.galleryMellowGold)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(Color.galleryMellowGold.opacity(0.2))
                                        .overlay(
                                            Circle()
                                                .stroke(Color.galleryMellowGold.opacity(0.5), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if showEnding {
                        onExitToEnding()
                    } else {
                        onBack()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("返回", "Back"))
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Zoom & Pan Helpers
    private func resetZoomPan() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = 1.0
            panOffset = .zero
            lastZoomScale = 1.0
            lastPanOffset = .zero
        }
    }

    private func clampPanToBounds() {
        let extra = (zoomScale - 1.0) * 260
        let maxX = max(0, extra / 2 + 40)
        let maxY = max(0, extra / 2 + 40)
        panOffset.width = min(max(panOffset.width, -maxX), maxX)
        panOffset.height = min(max(panOffset.height, -maxY), maxY)
    }
}

// MARK: - InkSplashShape
struct InkSplashShape: Shape {
    let seed: Int
    let downwardStretch: CGFloat
    
    init(seed: Int, downwardStretch: CGFloat = 1.0) {
        self.seed = seed
        self.downwardStretch = downwardStretch
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadiusX = rect.width * 0.42
        let baseRadiusY = rect.height * 0.42 * downwardStretch
        
        let points = 18
        for i in 0..<points {
            let angle = Double(i) / Double(points) * 2 * .pi
            let noise1 = sin(Double(seed * 7 + i * 3)) * 0.3
            let noise2 = sin(Double(seed * 11 + i * 5)) * 0.2
            let randomFactor = noise1 + noise2
            
            let radiusX = baseRadiusX * (1.0 + randomFactor * 0.6)
            let radiusY = baseRadiusY * (1.0 + randomFactor)
            
            let x = center.x + cos(angle) * radiusX
            let y = center.y + sin(angle) * radiusY
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prevAngle = Double(i - 1) / Double(points) * 2 * .pi
                let prevNoise = sin(Double(seed * 7 + (i - 1) * 3)) * 0.3 + sin(Double(seed * 11 + (i - 1) * 5)) * 0.2
                let prevRX = baseRadiusX * (1.0 + prevNoise * 0.6)
                let prevRY = baseRadiusY * (1.0 + prevNoise)
                let prevX = center.x + cos(prevAngle) * prevRX
                let prevY = center.y + sin(prevAngle) * prevRY
                
                let cpAngle = (prevAngle + angle) / 2
                let cpNoise = sin(Double(seed * 13 + i)) * 0.4
                let cpRX = baseRadiusX * (1.15 + cpNoise * 0.3)
                let cpRY = baseRadiusY * (1.2 + cpNoise * 0.5)
                let cpX = center.x + cos(cpAngle) * cpRX
                let cpY = center.y + sin(cpAngle) * cpRY
                
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cpX, y: cpY))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - PigmentDripShape
struct PigmentDripShape: Shape {
    let seed: Int
    let width: CGFloat
    let length: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width * width
        let h = rect.height * length
        let startY = rect.minY
        let centerX = rect.midX
        
        path.move(to: CGPoint(x: centerX - w * 0.4, y: startY))
        
        let segments = 8
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let y = startY + h * t
            let wobble = sin(Double(seed * 5 + i * 2)) * 0.15 + sin(Double(seed * 9 + i)) * 0.1
            let halfWidth = w * (0.5 - t * 0.3 + wobble * 0.2)
            let x = centerX - halfWidth
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        let tipY = startY + h
        let tipWobble = sin(Double(seed * 13)) * 0.1
        path.addQuadCurve(
            to: CGPoint(x: centerX + w * (0.2 + tipWobble), y: tipY),
            control: CGPoint(x: centerX - w * 0.05, y: tipY + h * 0.05)
        )
        
        for i in (0...segments).reversed() {
            let t = CGFloat(i) / CGFloat(segments)
            let y = startY + h * t
            let wobble = sin(Double(seed * 5 + i * 2 + 1)) * 0.15 + sin(Double(seed * 9 + i + 1)) * 0.1
            let halfWidth = w * (0.5 - t * 0.3 + wobble * 0.2)
            let x = centerX + halfWidth
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - InkSplashCanvasBackground
struct InkSplashCanvasBackground: View {
    let baseColor: Color
    let inkColor: Color
    let seed: Int
    let textureVariant: Int
    
    init(baseColor: Color, inkColor: Color, seed: Int, textureVariant: Int = 0) {
        self.baseColor = baseColor
        self.inkColor = inkColor
        self.seed = seed
        self.textureVariant = textureVariant
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvasBase(width: geo.size.width, height: geo.size.height)
                
                canvasGrain(width: geo.size.width, height: geo.size.height)
                
                ZStack(alignment: .top) {
                    InkSplashShape(seed: seed, downwardStretch: 1.6)
                        .fill(inkColor.opacity(0.9))
                        .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.5)
                        .position(x: geo.size.width * 0.3, y: geo.size.height * 0.15)
                    
                    InkSplashShape(seed: seed + 5, downwardStretch: 1.3)
                        .fill(inkColor.opacity(0.7))
                        .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.4)
                        .position(x: geo.size.width * 0.75, y: geo.size.height * 0.2)
                    
                    InkSplashShape(seed: seed + 3, downwardStretch: 1.8)
                        .fill(inkColor.opacity(0.55))
                        .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.55)
                        .position(x: geo.size.width * 0.5, y: geo.size.height * 0.3)
                    
                    PigmentDripShape(seed: seed + 10, width: 0.08, length: 0.5)
                        .fill(inkColor.opacity(0.8))
                        .frame(width: geo.size.width * 0.15, height: geo.size.height * 0.6)
                        .position(x: geo.size.width * 0.15, y: geo.size.height * 0.4)
                    
                    PigmentDripShape(seed: seed + 15, width: 0.06, length: 0.7)
                        .fill(inkColor.opacity(0.65))
                        .frame(width: geo.size.width * 0.12, height: geo.size.height * 0.75)
                        .position(x: geo.size.width * 0.88, y: geo.size.height * 0.5)
                    
                    PigmentDripShape(seed: seed + 20, width: 0.05, length: 0.4)
                        .fill(inkColor.opacity(0.5))
                        .frame(width: geo.size.width * 0.1, height: geo.size.height * 0.45)
                        .position(x: geo.size.width * 0.6, y: geo.size.height * 0.4)
                    
                    PigmentDripShape(seed: seed + 25, width: 0.04, length: 0.55)
                        .fill(inkColor.opacity(0.45))
                        .frame(width: geo.size.width * 0.08, height: geo.size.height * 0.6)
                        .position(x: geo.size.width * 0.35, y: geo.size.height * 0.5)
                    
                    PigmentDripShape(seed: seed + 30, width: 0.03, length: 0.35)
                        .fill(inkColor.opacity(0.4))
                        .frame(width: geo.size.width * 0.06, height: geo.size.height * 0.4)
                        .position(x: geo.size.width * 0.72, y: geo.size.height * 0.35)
                    
                    Circle()
                        .fill(inkColor.opacity(0.7))
                        .frame(width: 10, height: 10)
                        .position(x: geo.size.width * 0.92, y: geo.size.height * 0.25)
                    
                    Circle()
                        .fill(inkColor.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .position(x: geo.size.width * 0.05, y: geo.size.height * 0.6)
                    
                    Circle()
                        .fill(inkColor.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .position(x: geo.size.width * 0.45, y: geo.size.height * 0.75)
                    
                    Circle()
                        .fill(inkColor.opacity(0.4))
                        .frame(width: 5, height: 5)
                        .position(x: geo.size.width * 0.78, y: geo.size.height * 0.85)
                }
                .blur(radius: 0.2)
                
                pigmentEdgeGlow(width: geo.size.width, height: geo.size.height)
            }
        }
    }
    
    private func canvasBase(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            baseColor
            
            LinearGradient(
                colors: [
                    baseColor.opacity(0.9),
                    baseColor.opacity(1.0),
                    baseColor.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                colors: [
                    baseColor.opacity(0),
                    baseColor.opacity(0.15)
                ],
                center: .center,
                startRadius: width * 0.3,
                endRadius: width * 0.8
            )
        }
        .ignoresSafeArea()
    }
    
    private func canvasGrain(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<120, id: \.self) { i in
                let x = CGFloat(sin(Double(i * 7 + seed + textureVariant * 3)) * 0.5 + 0.5) * width
                let y = CGFloat(cos(Double(i * 11 + seed + textureVariant * 5)) * 0.5 + 0.5) * height
                let s = CGFloat(sin(Double(i * 3 + seed)) * 0.5 + 1) * 1.2
                let opacity = Double(sin(Double(i * 13 + seed)) * 0.5 + 0.5) * 0.06
                Circle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: s, height: s)
                    .position(x: x, y: y)
            }
            
            ForEach(0..<80, id: \.self) { i in
                let x = CGFloat(sin(Double(i * 17 + seed + textureVariant * 7)) * 0.5 + 0.5) * width
                let y = CGFloat(cos(Double(i * 19 + seed + textureVariant * 11)) * 0.5 + 0.5) * height
                let s = CGFloat(sin(Double(i * 5 + seed)) * 0.5 + 0.8) * 0.8
                Circle()
                    .fill(Color.black.opacity(0.04))
                    .frame(width: s, height: s)
                    .position(x: x, y: y)
            }
        }
    }
    
    private func pigmentEdgeGlow(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            inkColor.opacity(0.06)
                .blur(radius: 40)
                .frame(width: width * 0.9, height: height * 0.5)
                .position(x: width * 0.35, y: height * 0.2)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - PeachFuzzBackground
struct PeachFuzzBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.76, green: 0.46, blue: 0.32)

                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.76, blue: 0.68).opacity(0.35),
                        Color(red: 0.90, green: 0.62, blue: 0.52).opacity(0.18),
                        Color(red: 0.82, green: 0.52, blue: 0.40).opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.85, blue: 0.75).opacity(0.22),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.15, y: 0.20),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.45
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.82, blue: 0.70).opacity(0.18),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.88, y: 0.35),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.40
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.74, blue: 0.62).opacity(0.14),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.55, y: 0.80),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.50
                )
                RadialGradient(
                    colors: [
                        Color(red: 1.00, green: 0.88, blue: 0.78).opacity(0.12),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.30, y: 0.90),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.35
                )

                Circle()
                    .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.12))
                    .frame(width: 3, height: 3)
                    .position(x: geo.size.width * 0.12, y: geo.size.height * 0.18)
                Circle()
                    .fill(Color(red: 1.00, green: 0.92, blue: 0.84).opacity(0.10))
                    .frame(width: 2, height: 2)
                    .position(x: geo.size.width * 0.25, y: geo.size.height * 0.55)
                Circle()
                    .fill(Color(red: 1.00, green: 0.88, blue: 0.80).opacity(0.11))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.28)
                Circle()
                    .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.09))
                    .frame(width: 2, height: 2)
                    .position(x: geo.size.width * 0.70, y: geo.size.height * 0.72)
                Circle()
                    .fill(Color(red: 1.00, green: 0.92, blue: 0.85).opacity(0.11))
                    .frame(width: 3, height: 3)
                    .position(x: geo.size.width * 0.45, y: geo.size.height * 0.42)
                Circle()
                    .fill(Color(red: 1.00, green: 0.88, blue: 0.78).opacity(0.09))
                    .frame(width: 2, height: 2)
                    .position(x: geo.size.width * 0.92, y: geo.size.height * 0.88)
                Circle()
                    .fill(Color(red: 1.00, green: 0.90, blue: 0.82).opacity(0.12))
                    .frame(width: 2.5, height: 2.5)
                    .position(x: geo.size.width * 0.08, y: geo.size.height * 0.78)
            }
        }
    }
}

// MARK: - CloudDancerBackground
struct CloudDancerBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 240/255, green: 238/255, blue: 233/255)

                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.78).opacity(0.65),
                        Color(red: 1.0, green: 0.98, blue: 0.72).opacity(0.48),
                        Color(red: 1.0, green: 0.82, blue: 0.88).opacity(0.28),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.06, y: 0.05),
                    startRadius: 5,
                    endRadius: geo.size.width * 0.35
                )
                .blur(radius: 18)

                RadialGradient(
                    colors: [
                        Color(red: 0.95, green: 0.55, blue: 0.62).opacity(0.55),
                        Color(red: 0.98, green: 0.72, blue: 0.80).opacity(0.36),
                        Color(red: 0.76, green: 0.58, blue: 0.38).opacity(0.20),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.92, y: 0.96),
                    startRadius: 5,
                    endRadius: geo.size.width * 0.32
                )
                .blur(radius: 20)
            }
        }
    }
}

// MARK: - GalleryView (Main Entry)
struct GalleryView: View {
    var username: String = ""
    var userId: String = ""
    var onExhibitionConfirmed: ((String) -> Void)? = nil

    // 每次打开 app 时从用户上传的图片中随机选一张作为背景
    private var randomUserBackgroundImage: Image? {
        let pictures = loadUserPictureData()
        guard let randomData = pictures.randomElement(),
              let uiImage = UIImage(data: randomData) else { return nil }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let warmTaupe = Color(red: 120/255, green: 110/255, blue: 96/255)
                // 颜色对应：上传作品 = burgundy，计划策展 = antique rose，当前展览 = midnight blue
                let burgundy = Color(red: 0.50, green: 0.07, blue: 0.20)
                let antiqueRose = Color(red: 218/255, green: 136/255, blue: 144/255)
                let midnightBlue = Color(red: 0.10, green: 0.12, blue: 0.30)

                let strokeWidth: CGFloat = 1.5
                let leftBarWidth = geo.size.width * 0.25
                let rightAreaWidth = geo.size.width - leftBarWidth
                let edgePadding: CGFloat = 24
                let boxSpacing: CGFloat = 18
                let stripeWidth: CGFloat = 10
                let totalVerticalPadding = edgePadding * 2 + boxSpacing * 2
                let boxHeight = (geo.size.height - totalVerticalPadding) / 3
                // 盒子以 peach fuzz 右边界为起点，无需再额外加宽
                let boxWidth = rightAreaWidth - edgePadding
                // 盒子垂直中心点（各自）
                let box1CenterY = edgePadding + boxHeight / 2
                let box2CenterY = edgePadding + boxHeight + boxSpacing + boxHeight / 2    // 屏幕竖直中心
                let box3CenterY = edgePadding + boxHeight * 2 + boxSpacing * 2 + boxHeight / 2

                ZStack {
                    // 整页底层背景：云舞色渐变 ombre
                    CloudDancerBackground()
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        // 左侧 peach fuzz 长条（占屏幕 1/4 宽，全高，延伸到上下边缘之外）
                        PeachFuzzBackground()
                            .frame(width: leftBarWidth, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                            .offset(y: -geo.safeAreaInsets.top)

                        Color.clear.frame(width: rightAreaWidth, height: geo.size.height)
                    }

                    // ============ 三个盒子（无圆角 / 只画上右下边） ============
                    // 盒子1：上传作品（burgundy）
                    NavigationLink(destination: PictureView(username: username, userId: userId, onExhibitionConfirmed: onExhibitionConfirmed).trackScreen("picture")) {
                        threeSidedBox(
                            width: boxWidth,
                            height: boxHeight,
                            outlineColor: warmTaupe,
                            accentColor: burgundy,
                            strokeWidth: strokeWidth,
                            stripeWidth: stripeWidth
                        ) {
                            // 文本保持盒子居中
                            titledLabel(title: L("上传作品", "Upload"), accent: burgundy)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: boxWidth, height: boxHeight)
                    .position(x: leftBarWidth + boxWidth / 2, y: box1CenterY)

                    // 盒子2：计划策展（antique rose）
                    NavigationLink(destination: GalleryContentView(autoShowPrepare: true, userId: userId, userName: username, onExhibitionConfirmed: onExhibitionConfirmed)) {
                        threeSidedBox(
                            width: boxWidth,
                            height: boxHeight,
                            outlineColor: warmTaupe,
                            accentColor: antiqueRose,
                            strokeWidth: strokeWidth,
                            stripeWidth: stripeWidth
                        ) {
                            // 文本与其它两个盒子一样在盒子内部居中
                            titledLabel(title: L("计划策展", "Curate"), accent: antiqueRose)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: boxWidth, height: boxHeight)
                    .position(x: leftBarWidth + boxWidth / 2, y: box2CenterY)

                    // 盒子3：当前展览（midnight blue）
                    NavigationLink(destination: GalleryContentView(autoShowVisit: true, userId: userId, userName: username, onExhibitionConfirmed: onExhibitionConfirmed)) {
                        threeSidedBox(
                            width: boxWidth,
                            height: boxHeight,
                            outlineColor: warmTaupe,
                            accentColor: midnightBlue,
                            strokeWidth: strokeWidth,
                            stripeWidth: stripeWidth
                        ) {
                            titledLabel(title: L("当前展览", "Gallery"), accent: midnightBlue)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: boxWidth, height: boxHeight)
                    .position(x: leftBarWidth + boxWidth / 2, y: box3CenterY)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Box with top/bottom outline + right gradient color bar (no left, sharp corners)
    private func threeSidedBox<Content: View>(
        width: CGFloat,
        height: CGFloat,
        outlineColor: Color,
        accentColor: Color,
        strokeWidth: CGFloat,
        stripeWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topLeading) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 顶线
            Rectangle()
                .fill(outlineColor.opacity(0.85))
                .frame(width: width, height: strokeWidth)

            // 底线
            Rectangle()
                .fill(outlineColor.opacity(0.85))
                .frame(width: width, height: strokeWidth)
                .offset(y: height - strokeWidth)

            // 右端色块 — 从透明渐变到实色，平滑过渡
            // 总宽度 = 2 × (stripeWidth + strokeWidth)，左端透明，右端实色
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.0),
                            accentColor.opacity(0.25),
                            accentColor.opacity(0.6),
                            accentColor
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: (stripeWidth + strokeWidth) * 2, height: height)
                .offset(x: width - strokeWidth - (stripeWidth + strokeWidth))
        }
        .frame(width: width, height: height)
    }

    // MARK: - Liquid glass pill button with colored tint
    private func titledLabel(title: String, accent: Color) -> some View {
        Text(title)
            .font(.pingFang(size: 20, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // 1. 磨砂玻璃基底（ultraThinMaterial 透过底层彩色背景）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                    // 2. 彩色叠加（保留原 accent 色调，略加深让文字可读）
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.40))
                    // 3. 顶部高光：模拟玻璃上缘反光
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.50),
                                    Color.white.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.55)
                            )
                        )
                }
            )
            .overlay(
                // 4. 细白色渐变描边：玻璃边缘
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            // 5. 柔和投影：浮于背景之上
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
