//
//  CrystalView.swift
//  TheApp
//
//  Created by Yi Yang on 2026/8/7.
//

import SwiftUI
import AVFoundation
import Combine

// 金字塔高度比例（越小 = 金字塔越矮 = 尖端越不尖锐）
private let kPyramidRatio: CGFloat = 0.22

struct CrystalView: View {
    let onClose: () -> Void
    @State private var forkOffset: CGSize = .zero
    @State private var hasStruck = false
    @State private var isDragging = false
    @State private var crystalShakeX: CGFloat = 0
    @State private var crystalShakeAngle: Double = 0
    @State private var forkVibrate: CGFloat = 0
    @State private var crystalGlow = false
    @StateObject private var soundEngine = CrystalSoundEngine()

    // 净化模式：默认手动
    @State private var purifyMode: PurifyMode = .manual

    // 定时模式：沙漏进度（0→1，三分钟流完）与计时器
    @State private var sandProgress: CGFloat = 0
    @State private var sandTimer: Timer?

    private enum PurifyMode {
        case manual, timed
    }

    private var manualGuidelines: [String] {
        [
            L("首先让思绪安静下来", "First take a moment to quiet your thoughts"),
            L("拖动音叉敲击水晶，让声音充满空间", "Strike the tuning fork against the crystal and let its sound fill the space"),
            L("吸纳空间中的能量", "Take in the energy of the room"),
            L("享受此刻的安静沉思", "Savor the moment of quiet contemplation")
        ]
    }
    private var timedGuidelines: [String] {
        [
            L("躺下或坐着，保持舒服的姿势", "Lie down or sit in a comfortable position"),
            L("将注意力集中在自己的身体和感觉", "Focus on your own body and mind"),
            L("闭上双眼，缓慢呼吸", "Close your eyes and breathe slowly"),
            L("三分钟后，由水晶音叉将您唤醒", "The tuning fork will strike the crystal in three minutes to wake you up")
        ]
    }

    // 点击定时后开始计时：沙子三分钟流完，随后播放 4096Hz 音叉声唤醒
    private func startTimedSession() {
        stopTimedSession()
        sandProgress = 0
        let step: CGFloat = 0.05 / 180  // 每 0.05s 前进一步
        sandTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                sandProgress += step
                if sandProgress >= 1 {
                    sandProgress = 1
                    stopTimedSession()
                    soundEngine.playCrystalSound(contactNormalized: 0.5)
                }
            }
        }
    }

    private func stopTimedSession() {
        sandTimer?.invalidate()
        sandTimer = nil
    }

    // 圆形线条选项按钮：无填色，选中时边框与文字同时加粗
    private func modeCircleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("PingFang SC", size: 12).weight(isSelected ? .bold : .regular))
                .foregroundColor(Color(red: 0.40, green: 0.52, blue: 0.68))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .stroke(Color(red: 0.40, green: 0.52, blue: 0.68), lineWidth: isSelected ? 2.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // 水晶位置（相对于 ZStack 中心）
    private let crystalX: CGFloat = 0
    private let crystalY: CGFloat = 86
    // 音叉初始位置
    private let forkHomeX: CGFloat = 115
    private let forkHomeY: CGFloat = 60
    private let forkHalfHeight: CGFloat = 55

    /// 副标题+引导文案块的中心 Y（相对屏幕中心）：净化水晶标题底边与水晶柱尖端的中点
    private func guideBlockCenterY(_ geo: GeometryProxy) -> CGFloat {
        let titleBottom: CGFloat = 49 + 34                     // 顶部间距 + 28pt 标题行高
        let crystalTip = geo.size.height / 2 + crystalY - 140  // 水晶柱高 280，尖端在顶边
        return (titleBottom + crystalTip) / 2 - geo.size.height / 2
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 245/255, green: 245/255, blue: 242/255)
                    .ignoresSafeArea()

                // 顶部标题（与上一页"没关系，慢慢来"同一水平线）
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 49)

                    Text(L("净化水晶", "Tuning Fork"))
                        .font(.custom("PingFang SC", size: 28, relativeTo: .title2).weight(.semibold))
                        .foregroundColor(Color(red: 0.40, green: 0.52, blue: 0.68))
                        // 手动 / 定时按钮（竖排）：手动上边与标题上边对齐，按钮中线与沙漏中线（屏幕中心 +115）对齐
                        .overlay(alignment: .top) {
                            VStack(spacing: 6) {
                                modeCircleButton(title: L("手动", "Hand"), isSelected: purifyMode == .manual) {
                                    purifyMode = .manual
                                    stopTimedSession()
                                    sandProgress = 0
                                }
                                modeCircleButton(title: L("定时", "Timer"), isSelected: purifyMode == .timed) {
                                    purifyMode = .timed
                                    startTimedSession()
                                }
                                // 定时模式选中时，按钮右侧显示铃铛（overlay 不影响按钮位置）
                                .overlay(alignment: .trailing) {
                                    if purifyMode == .timed {
                                        Text("🔔")
                                            .font(.system(size: 15))
                                            .offset(x: 22)
                                    }
                                }
                            }
                            .offset(x: 115)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)

                    Spacer()
                }
                .multilineTextAlignment(.center)

                // 副标题 + 引导文案：垂直居中于标题底边与水晶柱尖端之间
                VStack(spacing: 16) {
                    Text(L("～ 4096赫兹 ～", "～ 4096Hz ～"))
                        .font(.custom("PingFang SC", size: 16))
                        .foregroundColor(Color(red: 0.48, green: 0.58, blue: 0.72).opacity(0.85))
                    VStack(spacing: 6) {
                        ForEach(purifyMode == .manual ? manualGuidelines : timedGuidelines, id: \.self) { line in
                            Text(line)
                                .font(.custom("PingFang SC", size: 15))
                                .foregroundColor(Color(red: 0.50, green: 0.60, blue: 0.72).opacity(0.82))
                        }
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .offset(y: guideBlockCenterY(geo))

                crystalView
                if purifyMode == .manual {
                    tuningForkView
                } else {
                    hourglassView
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear { stopTimedSession() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { onClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
        }
    }

    // MARK: - Crystal
    private var crystalView: some View {
        CrystalColumn()
            .frame(width: 130, height: 280)
            .offset(x: crystalX + crystalShakeX, y: crystalY)
            .rotationEffect(.degrees(crystalShakeAngle), anchor: .bottom)
            .shadow(
                color: crystalGlow ? Color(red: 0.5, green: 0.75, blue: 0.95).opacity(0.5) : .clear,
                radius: crystalGlow ? 18 : 0
            )
    }

    // MARK: - Tuning Fork
    private var tuningForkView: some View {
        Color.clear
            .frame(width: 50, height: 130)
            .contentShape(Rectangle())
            .overlay(
                TuningFork(vibration: forkVibrate)
                    .frame(width: 28, height: 110)
            )
            .shadow(color: .black.opacity(isDragging ? 0.18 : 0.10), radius: isDragging ? 5 : 2, x: 1, y: 2)
            .scaleEffect(isDragging ? 1.08 : 1.0)
            .offset(x: forkHomeX, y: forkHomeY)
            .offset(forkOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        forkOffset = value.translation
                        checkHit()
                    }
                    .onEnded { _ in
                        isDragging = false
                        hasStruck = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            forkOffset = .zero
                        }
                        withAnimation(.easeOut(duration: 0.3)) {
                            forkVibrate = 0
                        }
                    }
            )
    }

    // MARK: - Hourglass（定时模式：替代音叉，与音叉视觉中心对齐，高度与音叉可见高度一致）
    private var hourglassView: some View {
        SandHourglass(progress: sandProgress)
            .frame(width: 36, height: 90)
            .shadow(color: .black.opacity(0.10), radius: 2, x: 1, y: 2)
            // 音叉图形因内部 offset 绘制，视觉中心比其 frame 中心低 18.5pt，沙漏对齐音叉视觉位置
            .offset(x: forkHomeX, y: forkHomeY + 18.5)
    }

    // MARK: - Hit Detection
    private func checkHit() {
        guard !hasStruck else { return }
        let forkTipX = forkHomeX + forkOffset.width
        let forkTipY = forkHomeY + forkOffset.height - forkHalfHeight
        let dx = forkTipX - crystalX
        let dy = forkTipY - crystalY
        // 椭圆形敲击区：覆盖整根水晶（上窄下宽，匹配锥形轮廓）
        // x 半径 62（水晶宽 130 / 2 ≈ 65），y 半径 138（水晶高 280 / 2 = 140）
        let hitRadiusX: CGFloat = 62
        let hitRadiusY: CGFloat = 138
        let normalizedDist = (dx * dx) / (hitRadiusX * hitRadiusX) + (dy * dy) / (hitRadiusY * hitRadiusY)
        if normalizedDist < 1.0 {
            hasStruck = true
            // 归一化垂直敲击位置：0 = 水晶顶部（尖），1 = 水晶底部（座）
            let crystalTopY = crystalY - 140.0
            let crystalBotY = crystalY + 140.0
            let contactYN = max(0, min(1, (forkTipY - crystalTopY) / (crystalBotY - crystalTopY)))
            soundEngine.playCrystalSound(contactNormalized: contactYN)
            shakeCrystal()
            vibrateFork()
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }
    }

    private func shakeCrystal() {
        withAnimation(.easeOut(duration: 0.06)) { crystalShakeX = 5; crystalShakeAngle = 0.8; crystalGlow = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.06)) { crystalShakeX = -4; crystalShakeAngle = -0.6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.06)) { crystalShakeX = 3; crystalShakeAngle = 0.4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.06)) { crystalShakeX = -2; crystalShakeAngle = -0.2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.easeOut(duration: 0.2)) { crystalShakeX = 0; crystalShakeAngle = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 1.0)) { crystalGlow = false }
        }
    }

    private func vibrateFork() {
        withAnimation(.easeInOut(duration: 0.04)) { forkVibrate = 2.5 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            withAnimation(.easeInOut(duration: 0.04)) { forkVibrate = -2.5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.04)) { forkVibrate = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeInOut(duration: 0.04)) { forkVibrate = -1.5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.04)) { forkVibrate = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeOut(duration: 0.15)) { forkVibrate = 0 }
        }
    }
}

// MARK: - Crystal Sound Engine

class CrystalSoundEngine: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pitchEffect = AVAudioUnitTimePitch()
    private let reverb = AVAudioUnitReverb()
    private let format: AVAudioFormat

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        audioEngine.attach(playerNode)
        audioEngine.attach(pitchEffect)
        audioEngine.attach(reverb)
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 25

        audioEngine.connect(playerNode, to: pitchEffect, format: format)
        audioEngine.connect(pitchEffect, to: reverb, format: format)
        audioEngine.connect(reverb, to: audioEngine.mainMixerNode, format: format)

        try? audioEngine.start()
    }

    /// - Parameter contactNormalized: 0 = 水晶顶部（短促 4.5s），1 = 水晶底部（悠长 6.0s）
    func playCrystalSound(contactNormalized: CGFloat) {
        // 确保音频会话为播放模式
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if !audioEngine.isRunning { try? audioEngine.start() }
        // 敲击位置 → 总时长 4.5s ... 6.0s
        let duration = 4.5 + Double(contactNormalized) * 1.5
        // 顶（0）→ 高频略亮、衰减略快；底（1）→ 温暖、基音占优、衰减略慢
        let timbre = Double(contactNormalized)
        guard let buffer = Self.generateCrystalBuffer(format: format,
                                                      duration: duration,
                                                      timbre: timbre) else { return }
        // 每次敲击音高微调，模拟自然差异（±20 音分 = 约 4.7Hz @ 4096）
        pitchEffect.pitch = Float.random(in: -20...20)
        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        playerNode.play()
    }

    private static func generateCrystalBuffer(format: AVAudioFormat,
                                              duration: Double,
                                              timbre: Double) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let fundamental: Double = 4096.0 // 水晶音叉标准频率

        // 钟铃状非谐谐波（最高到 5.0 倍，确保在 44.1k 采样率下不混叠：4096×5 = 20480 < 22050）
        // timbre = 0（顶）：高频比例略高、衰减略快（清脆）
        // timbre = 1（底）：基音比例略高、衰减略慢（温暖悠长）
        let base: [(freq: Double, amp: Double, decay: Double)] = [
            (1.0, 1.00, 2.0),
            (2.0, 0.55, 2.5),
            (3.0, 0.35, 3.0),
            (4.2, 0.22, 3.4),
            (5.0, 0.12, 3.8),
        ]
        // 时长与音色联动：duration 越长 → 整体衰减时间基准越大
        let durationScale = duration / 4.5
        let partials: [(freq: Double, amp: Double, decay: Double)] = base.enumerated().map { idx, p in
            let isHigh = idx >= 2
            // 顶部 timbre→0，高频略抬 (0.9...1.15)，底部 timbre→1，高频略压 (1.0 → 0.85)
            let highBoost: Double = 1.0 + (isHigh ? (1.0 - timbre) * 0.25 : timbre * 0.1)
            // 顶部 timbre→0，高频衰减加快 0.92x；底部 timbre→1，整体衰减放慢
            let decayBoost: Double = durationScale * (isHigh
                ? (0.92 + timbre * 0.28)
                : (1.00 + timbre * 0.22))
            return (p.freq, p.amp * highBoost, p.decay / decayBoost)
        }

        let numSamples = Int(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(numSamples)
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        // 起音包络：前 2.5ms 平滑淡入，避免 click
        let attackSamples = max(1, Int(sampleRate * 0.0025))

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sample: Double = 0
            for p in partials {
                let envelope = exp(-p.decay * t)
                sample += p.amp * envelope * sin(2 * .pi * fundamental * p.freq * t)
            }
            let attackGain: Double = (i < attackSamples) ? (Double(i) / Double(attackSamples)) : 1.0
            channelData[i] = Float(sample * 0.12 * attackGain)
        }
        return buffer
    }
}

// MARK: - Crystal Column

private struct CrystalColumn: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                crystalBaseShadow
                crystalOuterGlow
                crystalLeftFace
                crystalRightFace
                crystalCenterFace
                crystalPyramid
                crystalPyramidLeftSlope
                crystalPyramidRightSlope
                crystalBaseFace
                crystalLeftRim
                crystalOuterStroke
                crystalEdgeLines
                crystalTextureOverlay
                centerFaceHighlight
                internalShard
                facetShard
                sparklesLayer(w: w, h: h)
                specularGlint
                roundedTipCap(w: w)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    private var crystalBaseShadow: some View {
        CrystalShape()
            .fill(Color.black.opacity(0.08))
            .offset(x: 2, y: 4)
            .blur(radius: 2)
    }

    private var crystalOuterGlow: some View {
        CrystalShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.70, green: 0.84, blue: 0.96).opacity(0.12),
                        Color(red: 0.82, green: 0.90, blue: 0.98).opacity(0.05),
                        Color(red: 0.66, green: 0.80, blue: 0.94).opacity(0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color(red: 0.55, green: 0.75, blue: 0.95).opacity(0.22), radius: 14, x: 0, y: 0)
    }

    private var crystalLeftFace: some View {
        CrystalLeftFace()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.58, blue: 0.76).opacity(0.44),
                        Color(red: 0.32, green: 0.48, blue: 0.68).opacity(0.34),
                        Color(red: 0.26, green: 0.42, blue: 0.62).opacity(0.48)
                    ],
                    startPoint: UnitPoint(x: 0.95, y: 0.05),
                    endPoint: UnitPoint(x: 0.05, y: 0.95)
                )
            )
    }

    private var crystalRightFace: some View {
        CrystalRightFace()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.54, green: 0.70, blue: 0.88).opacity(0.34),
                        Color(red: 0.42, green: 0.58, blue: 0.78).opacity(0.24),
                        Color(red: 0.36, green: 0.52, blue: 0.72).opacity(0.40)
                    ],
                    startPoint: UnitPoint(x: 0.05, y: 0.05),
                    endPoint: UnitPoint(x: 0.95, y: 0.95)
                )
            )
    }

    private var crystalCenterFace: some View {
        CrystalCenterFace()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.96, blue: 1.00).opacity(0.62),
                        Color(red: 0.72, green: 0.86, blue: 0.96).opacity(0.38),
                        Color(red: 0.58, green: 0.76, blue: 0.92).opacity(0.30),
                        Color(red: 0.68, green: 0.84, blue: 0.96).opacity(0.46)
                    ],
                    startPoint: UnitPoint(x: 0.30, y: 0),
                    endPoint: UnitPoint(x: 0.70, y: 1)
                )
            )
    }

    private var crystalPyramid: some View {
        CrystalPyramid()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.99, blue: 1.00).opacity(0.72),
                        Color(red: 0.62, green: 0.78, blue: 0.92).opacity(0.26)
                    ],
                    startPoint: UnitPoint(x: 0.45, y: 0),
                    endPoint: UnitPoint(x: 0.55, y: 1)
                )
            )
    }

    private var crystalPyramidLeftSlope: some View {
        CrystalPyramidLeftSlope()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.30, green: 0.46, blue: 0.66).opacity(0.50),
                        Color(red: 0.42, green: 0.58, blue: 0.76).opacity(0.30)
                    ],
                    startPoint: UnitPoint(x: 1.0, y: 0),
                    endPoint: UnitPoint(x: 0.0, y: 1)
                )
            )
    }

    private var crystalPyramidRightSlope: some View {
        CrystalPyramidRightSlope()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.44, green: 0.62, blue: 0.82).opacity(0.36),
                        Color(red: 0.56, green: 0.72, blue: 0.90).opacity(0.22)
                    ],
                    startPoint: UnitPoint(x: 0.0, y: 0),
                    endPoint: UnitPoint(x: 1.0, y: 1)
                )
            )
    }

    private var crystalBaseFace: some View {
        CrystalBaseFace()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.38, blue: 0.58).opacity(0.58),
                        Color(red: 0.38, green: 0.54, blue: 0.74).opacity(0.30)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
    }

    private var crystalLeftRim: some View {
        CrystalLeftRim()
            .stroke(
                Color(red: 0.96, green: 0.99, blue: 1.00).opacity(0.82),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
            )
    }

    private var crystalOuterStroke: some View {
        CrystalShape()
            .stroke(
                Color(red: 0.78, green: 0.88, blue: 0.98).opacity(0.70),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
            )
    }

    private var crystalEdgeLines: some View {
        CrystalEdgeLines()
            .stroke(
                Color(red: 0.32, green: 0.48, blue: 0.68).opacity(0.52),
                style: StrokeStyle(lineWidth: 0.6, lineCap: .round, lineJoin: .round)
            )
    }

    private var crystalTextureOverlay: some View {
        CrystalTextureOverlay()
            .opacity(0.6)
    }

    private var centerFaceHighlight: some View {
        CenterFaceHighlight()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.55),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 0.4)
    }

    private var internalShard: some View {
        InternalShard()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.58),
                        Color(red: 0.90, green: 0.96, blue: 1.0).opacity(0.24),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 0.6)
    }

    private var facetShard: some View {
        FacetShard()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.28),
                        Color.white.opacity(0.50),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 0.5)
    }

    private func sparklesLayer(w: CGFloat, h: CGFloat) -> some View {
        SparklesLayer()
            .frame(width: w, height: h)
    }

    private var specularGlint: some View {
        SpecularGlint()
            .fill(Color.white.opacity(0.72))
            .blur(radius: 0.3)
    }

    // 圆润尖端帽（让尖端不那么尖锐）
    private func roundedTipCap(w: CGFloat) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.96, blue: 1.00).opacity(0.65),
                        Color(red: 0.70, green: 0.82, blue: 0.94).opacity(0.30)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 8, height: 5)
            .position(x: w * 0.5, y: 2.5)
    }
}

// MARK: - Crystal Texture Overlay (rough facets)

/// 晶面粗糙纹理：内部裂纹 + 包裹体 + 表面微粒
private struct CrystalTextureOverlay: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // 内部裂纹线（细而不规则曲线）
            let fractures: [(Double, Double, Double, Double, Double)] = [
                (0.35, 0.30, 0.45, 0.45, 0.15),
                (0.55, 0.40, 0.50, 0.60, 0.12),
                (0.42, 0.55, 0.58, 0.70, 0.10),
                (0.48, 0.35, 0.40, 0.50, 0.08),
                (0.60, 0.50, 0.52, 0.65, 0.11),
                (0.38, 0.65, 0.46, 0.78, 0.09),
            ]
            for f in fractures {
                var path = Path()
                let x1 = f.0 * w, y1 = f.1 * h
                let x2 = f.2 * w, y2 = f.3 * h
                let midX = (x1 + x2) * 0.5 + 2
                let midY = (y1 + y2) * 0.5 - 1.5
                path.move(to: CGPoint(x: x1, y: y1))
                path.addQuadCurve(to: CGPoint(x: x2, y: y2), control: CGPoint(x: midX, y: midY))
                context.stroke(path, with: .color(Color.white.opacity(f.4)), lineWidth: 0.35)
            }

            // 包裹体（不规则小斑点）
            let inclusions: [(Double, Double, Double, Bool)] = [
                (0.38, 0.42, 0.8, true),
                (0.52, 0.38, 0.6, false),
                (0.45, 0.62, 1.0, true),
                (0.55, 0.72, 0.7, false),
                (0.42, 0.25, 0.5, true),
                (0.58, 0.55, 0.9, false),
            ]
            for inc in inclusions {
                let x = inc.0 * w
                let y = inc.1 * h
                let r = inc.2
                let color = inc.3
                    ? Color.white.opacity(0.22)
                    : Color(red: 0.3, green: 0.4, blue: 0.55).opacity(0.16)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }

            // 表面微粒（让晶面不那么光滑）
            let dust: [(Double, Double, Double)] = [
                (0.34, 0.38, 0.3), (0.48, 0.44, 0.25), (0.56, 0.48, 0.3),
                (0.40, 0.58, 0.2), (0.52, 0.68, 0.25), (0.46, 0.32, 0.2),
                (0.58, 0.62, 0.3), (0.44, 0.72, 0.2), (0.50, 0.50, 0.25),
            ]
            for d in dust {
                let x = d.0 * w
                let y = d.1 * h
                let r = d.2
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.12)))
            }
        }
    }
}

// MARK: - Tuning Fork

private struct TuningFork: View {
    var vibration: CGFloat = 0

    private let prongWidth: CGFloat = 3.5
    private let prongHeight: CGFloat = 58
    private let prongGap: CGFloat = 10
    private let stemWidth: CGFloat = 4
    private let stemHeight: CGFloat = 24
    private let bulbRadius: CGFloat = 6
    private let uHeight: CGFloat = 10

    var body: some View {
        ZStack(alignment: .top) {
            prongs
            uConnection
            stem
            bulb
        }
    }

    private var metalGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.40, blue: 0.43),
                Color(red: 0.68, green: 0.70, blue: 0.73),
                Color(red: 0.88, green: 0.90, blue: 0.93),
                Color(red: 0.62, green: 0.64, blue: 0.67),
                Color(red: 0.40, green: 0.42, blue: 0.45),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var prongs: some View {
        HStack(spacing: prongGap) {
            RoundedRectangle(cornerRadius: 1)
                .fill(metalGradient)
                .frame(width: prongWidth, height: prongHeight)
                .offset(x: vibration)

            RoundedRectangle(cornerRadius: 1)
                .fill(metalGradient)
                .frame(width: prongWidth, height: prongHeight)
                .offset(x: -vibration)
        }
    }

    private var uConnection: some View {
        TuningForkU()
            .fill(metalGradient)
            .frame(width: prongWidth * 2 + prongGap, height: uHeight)
            .offset(y: prongHeight - 5)
    }

    private var stem: some View {
        Rectangle()
            .fill(metalGradient)
            .frame(width: stemWidth, height: stemHeight)
            .offset(y: prongHeight + uHeight - 7)
    }

    private var bulb: some View {
        Circle()
            .fill(metalGradient)
            .frame(width: bulbRadius * 2, height: bulbRadius * 2)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
            )
            .offset(y: prongHeight + uHeight + stemHeight - 9)
    }
}

private struct TuningForkU: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let prongW: CGFloat = 3.5

        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h * 0.2))
        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.2),
                       control: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w - prongW, y: 0))
        p.addLine(to: CGPoint(x: w - prongW, y: h * 0.2))
        p.addQuadCurve(to: CGPoint(x: prongW, y: h * 0.2),
                       control: CGPoint(x: w * 0.5, y: h - 3))
        p.addLine(to: CGPoint(x: prongW, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Sand Hourglass（定时模式）

/// 沙漏：白色边框，蓝色沙子。progress 0 = 沙全在上方，1 = 全部流到下方
private struct SandHourglass: View {
    let progress: CGFloat

    private let sandBlue = Color(red: 0.40, green: 0.52, blue: 0.68)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                // 上方剩余沙子（随时间减少）
                TopSandShape(remaining: max(0, 1 - progress))
                    .fill(sandBlue)
                // 流动中的沙线（仅在流动期间可见）
                if progress > 0 && progress < 1 {
                    Rectangle()
                        .fill(sandBlue)
                        .frame(width: 1.5, height: h / 2)
                        .offset(y: h / 4)
                }
                // 下方已流入沙子（随时间增多，盖住沙线下端）
                BottomSandShape(filled: max(0, progress))
                    .fill(sandBlue)
                // 白色边框
                HourglassOutlineShape()
                    .stroke(Color.white, lineWidth: 2)
            }
            .frame(width: geo.size.width, height: h)
        }
    }
}

/// 沙漏外框：上下两个三角形尖对尖
private struct HourglassOutlineShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.midY))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// 上方沙子：以颈部为尖的小三角，remaining 1 → 0 逐渐缩小
private struct TopSandShape: Shape {
    var remaining: CGFloat
    func path(in r: CGRect) -> Path {
        let level = r.midY - remaining * r.height / 2
        let halfW = r.width / 2 * remaining
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX - halfW, y: level))
        p.addLine(to: CGPoint(x: r.midX + halfW, y: level))
        p.closeSubpath()
        return p
    }
}

/// 下方沙子：从底部向上堆积的梯形，filled 0 → 1 逐渐增高
private struct BottomSandShape: Shape {
    var filled: CGFloat
    func path(in r: CGRect) -> Path {
        let level = r.maxY - filled * r.height / 2
        let halfW = r.width / 2 * (1 - filled)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX + halfW, y: level))
        p.addLine(to: CGPoint(x: r.midX - halfW, y: level))
        p.closeSubpath()
        return p
    }
}

// MARK: - Crystal Shapes

/// 对给定 y（在柱体区间内）返回线性插值后的 x 坐标
private func taperX(_ topX: CGFloat, _ botX: CGFloat,
                    _ y: CGFloat, _ pyramidBottomY: CGFloat, _ baseY: CGFloat) -> CGFloat {
    guard baseY > pyramidBottomY else { return botX }
    let t = (y - pyramidBottomY) / (baseY - pyramidBottomY)
    return topX + (botX - topX) * t
}

private struct CrystalShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY: CGFloat = r.minY
        let baseY: CGFloat = r.maxY
        let pyramidBottomY = tipY + h * kPyramidRatio

        // 顶部（窄）和底部（宽）的 x 值
        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let colR_top = r.maxX - w * 0.12, colR_bot = r.maxX - w * 0.06
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        // 按 y 插值（顶部 = pyramidBottomY，底部 = baseY）
        let colL_py = taperX(colL_top, colL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let colR_py = taperX(colR_top, colR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let chamferY = baseY - 5
        let midL_ch = taperX(midL_top, midL_bot, chamferY, pyramidBottomY, baseY)
        let midR_ch = taperX(midR_top, midR_bot, chamferY, pyramidBottomY, baseY)
        let colL_bs = taperX(colL_top, colL_bot, baseY, pyramidBottomY, baseY)
        let colR_bs = taperX(colR_top, colR_bot, baseY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: tipY))
        p.addLine(to: CGPoint(x: colL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: colL_bs, y: baseY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        p.addLine(to: CGPoint(x: colR_bs, y: baseY))
        p.addLine(to: CGPoint(x: colR_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalLeftFace: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let midX = r.midX

        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let chamferY = baseY - 5
        let colL_bs = taperX(colL_top, colL_bot, baseY, pyramidBottomY, baseY)
        let midL_ch = taperX(midL_top, midL_bot, chamferY, pyramidBottomY, baseY)
        let colL_py = taperX(colL_top, colL_bot, pyramidBottomY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: colL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: colL_bs, y: baseY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.addLine(to: CGPoint(x: midX, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalCenterFace: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let midX = r.midX

        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let midL_py = taperX(midL_top, midL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midR_py = taperX(midR_top, midR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let chamferY = baseY - 5
        let midL_ch = taperX(midL_top, midL_bot, chamferY, pyramidBottomY, baseY)
        let midR_ch = taperX(midR_top, midR_bot, chamferY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        p.addLine(to: CGPoint(x: midR_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalRightFace: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let midX = r.midX

        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let colR_top = r.maxX - w * 0.12, colR_bot = r.maxX - w * 0.06
        let colR_py = taperX(colR_top, colR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let chamferY = baseY - 5
        let midR_ch = taperX(midR_top, midR_bot, chamferY, pyramidBottomY, baseY)
        let colR_bs = taperX(colR_top, colR_bot, baseY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midX, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        p.addLine(to: CGPoint(x: colR_bs, y: baseY))
        p.addLine(to: CGPoint(x: colR_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalPyramid: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        // 金字塔底部接柱体顶部（窄）
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let midL_py = taperX(midL_top, midL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midR_py = taperX(midR_top, midR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midX = r.midX

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midR_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalPyramidLeftSlope: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let colL_py = taperX(colL_top, colL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midL_py = taperX(midL_top, midL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midX = r.midX

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: colL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midL_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalPyramidRightSlope: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let midX = r.midX
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let colR_top = r.maxX - w * 0.12, colR_bot = r.maxX - w * 0.06
        let midR_py = taperX(midR_top, midR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let colR_py = taperX(colR_top, colR_bot, pyramidBottomY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midR_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: colR_py, y: pyramidBottomY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalBaseFace: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let pyramidBottomY = r.minY + h * kPyramidRatio
        let baseY = r.maxY
        let chamferY = baseY - 5
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let colR_top = r.maxX - w * 0.12, colR_bot = r.maxX - w * 0.06
        let midL_ch = taperX(midL_top, midL_bot, chamferY, pyramidBottomY, baseY)
        let midR_ch = taperX(midR_top, midR_bot, chamferY, pyramidBottomY, baseY)
        let colL_bs = taperX(colL_top, colL_bot, baseY, pyramidBottomY, baseY)
        let colR_bs = taperX(colR_top, colR_bot, baseY, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: colL_bs, y: baseY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        p.addLine(to: CGPoint(x: colR_bs, y: baseY))
        p.closeSubpath()
        return p
    }
}

private struct CrystalLeftRim: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let baseY = r.maxY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let colL_py = taperX(colL_top, colL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let colL_bs = taperX(colL_top, colL_bot, baseY, pyramidBottomY, baseY)
        let midX = r.midX

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: colL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: colL_bs, y: baseY))
        return p
    }
}

private struct CrystalEdgeLines: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let tipY = r.minY
        let pyramidBottomY = tipY + h * kPyramidRatio
        let baseY = r.maxY
        let chamferY = baseY - 5
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        let colL_top = r.minX + w * 0.12, colL_bot = r.minX + w * 0.06
        let colR_top = r.maxX - w * 0.12, colR_bot = r.maxX - w * 0.06
        let midL_py = taperX(midL_top, midL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midR_py = taperX(midR_top, midR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let midL_ch = taperX(midL_top, midL_bot, chamferY, pyramidBottomY, baseY)
        let midR_ch = taperX(midR_top, midR_bot, chamferY, pyramidBottomY, baseY)
        let colL_py = taperX(colL_top, colL_bot, pyramidBottomY, pyramidBottomY, baseY)
        let colR_py = taperX(colR_top, colR_bot, pyramidBottomY, pyramidBottomY, baseY)
        let colL_bs = taperX(colL_top, colL_bot, baseY, pyramidBottomY, baseY)
        let colR_bs = taperX(colR_top, colR_bot, baseY, pyramidBottomY, baseY)
        let midX = r.midX

        var p = Path()
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.move(to: CGPoint(x: midX, y: tipY))
        p.addLine(to: CGPoint(x: midR_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        // 中央垂直棱线
        let midX_chamferY = chamferY
        p.move(to: CGPoint(x: midX, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: midX, y: midX_chamferY))
        // 柱体顶部横线（pyramidBottomY）
        p.move(to: CGPoint(x: colL_py, y: pyramidBottomY))
        p.addLine(to: CGPoint(x: colR_py, y: pyramidBottomY))
        // 底部倒角线
        p.move(to: CGPoint(x: colL_bs, y: baseY))
        p.addLine(to: CGPoint(x: midL_ch, y: chamferY))
        p.move(to: CGPoint(x: colR_bs, y: baseY))
        p.addLine(to: CGPoint(x: midR_ch, y: chamferY))
        return p
    }
}

private struct CenterFaceHighlight: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let pyramidBottomY = r.minY + h * kPyramidRatio
        let baseY = r.maxY
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        // 高光顶部和底部的 midL 插值
        let yTop = pyramidBottomY + 2
        let yBotA = baseY - 10
        let yBotB = baseY - 8
        let midL_topY = taperX(midL_top, midL_bot, yTop, pyramidBottomY, baseY)
        let midL_botA = taperX(midL_top, midL_bot, yBotA, pyramidBottomY, baseY)
        let midL_botB = taperX(midL_top, midL_bot, yBotB, pyramidBottomY, baseY)
        let x0a = midL_topY + 1.0
        let x1a = midL_topY + 4.5
        let x1b = midL_botA + 4.0
        let x0b = midL_botB + 0.5
        var p = Path()
        p.move(to: CGPoint(x: x0a, y: yTop))
        p.addLine(to: CGPoint(x: x1a, y: pyramidBottomY + 3))
        p.addLine(to: CGPoint(x: x1b, y: yBotA))
        p.addLine(to: CGPoint(x: x0b, y: yBotB))
        p.closeSubpath()
        return p
    }
}

private struct InternalShard: Shape {
    func path(in r: CGRect) -> Path {
        let h = r.height
        let topY = r.minY + h * 0.12
        let bottomY = r.minY + h * 0.86
        let midX = r.midX

        var p = Path()
        p.move(to: CGPoint(x: midX - 1.5, y: topY))
        p.addLine(to: CGPoint(x: midX + 5, y: topY + h * 0.22))
        p.addLine(to: CGPoint(x: midX - 2, y: topY + h * 0.48))
        p.addLine(to: CGPoint(x: midX + 1.5, y: topY + h * 0.70))
        p.addLine(to: CGPoint(x: midX + 4, y: bottomY))
        p.addLine(to: CGPoint(x: midX - 3, y: bottomY - 2))
        p.addLine(to: CGPoint(x: midX - 6, y: topY + h * 0.70))
        p.addLine(to: CGPoint(x: midX + 0.5, y: topY + h * 0.48))
        p.addLine(to: CGPoint(x: midX - 5, y: topY + h * 0.22))
        p.closeSubpath()
        return p
    }
}

private struct SymmetricWaveDivider: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let midY = r.midY
        let amp = r.height / 2
        var p = Path()
        // 两段对称正弦波：左半一个完整向下+向上，右半镜像，中线水平
        // 总长度 w 分为 4 段，每段 w/4：↓↗↘↖ (中点处回到中线水平)
        let steps = 80
        p.move(to: CGPoint(x: r.minX, y: midY))
        for i in 0...steps {
            let x = r.minX + CGFloat(i) / CGFloat(steps) * w
            // 归一化 s ∈ [0, 1]
            let s = Double(i) / Double(steps)
            // 对称波形：sin(2πs) * sin(πs)^2
            // sin(2πs) 提供两次起伏；sin(πs)^2 使两端收束到 0（水平进出）
            let t = s * 2 * .pi
            let envelope = pow(sin(s * .pi), 2.0)
            let y = midY - amp * CGFloat(sin(t) * envelope)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

private struct FacetShard: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let pyramidBottomY = r.minY + h * kPyramidRatio
        let baseY = r.maxY
        let y0 = r.minY + h * 0.42
        let y1 = r.minY + h * 0.50
        let midL_top = r.minX + w * 0.32, midL_bot = r.minX + w * 0.28
        let midR_top = r.maxX - w * 0.32, midR_bot = r.maxX - w * 0.28
        // y0/y1 位于柱体区间内，按 y 插值
        let midL_y0 = taperX(midL_top, midL_bot, y0, pyramidBottomY, baseY)
        let midR_y0 = taperX(midR_top, midR_bot, y0 + 2, pyramidBottomY, baseY)
        let midR_y1 = taperX(midR_top, midR_bot, y1 + 1, pyramidBottomY, baseY)
        let midL_y1 = taperX(midL_top, midL_bot, y1, pyramidBottomY, baseY)

        var p = Path()
        p.move(to: CGPoint(x: midL_y0 + 2, y: y0))
        p.addLine(to: CGPoint(x: midR_y0 - 3, y: y0 + 2))
        p.addLine(to: CGPoint(x: midR_y1 - 1, y: y1 + 1))
        p.addLine(to: CGPoint(x: midL_y1 + 4, y: y1))
        p.closeSubpath()
        return p
    }
}

private struct SpecularGlint: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width
        let h = r.height
        let cx = r.minX + w * 0.38
        let cy = r.minY + h * 0.42
        let r1: CGFloat = 1.8
        let r2: CGFloat = 0.6
        let dot = CGRect(x: cx - r1, y: cy - r1, width: r1 * 2, height: r1 * 2)
        var p = Path(ellipseIn: dot)
        let tiny = CGRect(x: cx + 4, y: cy - 8, width: r2 * 2, height: r2 * 2)
        p.addPath(Path(ellipseIn: tiny))
        return p
    }
}

private struct SparklesLayer: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let sparkles: [(Double, Double, Double, Bool)] = [
                (0.42, 0.36, 1.1, true),
                (0.54, 0.52, 0.8, false),
                (0.58, 0.64, 1.0, true),
                (0.48, 0.76, 0.9, false),
                (0.56, 0.22, 0.7, true),
                (0.40, 0.58, 0.6, false),
                (0.61, 0.44, 0.5, true),
                (0.52, 0.84, 0.9, false),
                (0.46, 0.28, 0.4, true),
            ]
            for s in sparkles {
                let cx = s.0 * Double(w)
                let cy = s.1 * Double(h)
                let r: Double = s.2
                let opacity: Double = 0.55 + s.2 * 0.22
                if s.3 {
                    var p = Path()
                    let sz = r + 0.5
                    p.move(to: CGPoint(x: cx - sz, y: cy))
                    p.addLine(to: CGPoint(x: cx + sz, y: cy))
                    context.stroke(p, with: .color(Color.white.opacity(opacity)), lineWidth: 0.55)
                    p = Path()
                    p.move(to: CGPoint(x: cx, y: cy - sz))
                    p.addLine(to: CGPoint(x: cx, y: cy + sz))
                    context.stroke(p, with: .color(Color.white.opacity(opacity)), lineWidth: 0.55)
                }
                let dot = CGRect(x: cx - r * 0.3, y: cy - r * 0.3, width: r * 0.6, height: r * 0.6)
                context.fill(Path(ellipseIn: dot), with: .color(Color.white.opacity(opacity)))
            }
        }
    }
}

struct CrystalView_Previews: PreviewProvider {
    static var previews: some View {
        CrystalView(onClose: {})
    }
}
