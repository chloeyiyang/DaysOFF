import SwiftUI
import Speech
import AVFoundation

struct MoodView: View {
    let feeling: String
    let isPositive: Bool
    var isHeartTap: Bool = false  // true = 粉色爱心点击 → 气泡页 → 水晶页
    let onEnvelopeSaved: (HappyDiaryData) -> Void
    let onClose: () -> Void
    @State private var showCrystal = false

    var body: some View {
        if isHeartTap {
            // 粉色爱心：气泡页 → 水晶页
            FeelingResultView(feeling: feeling, onContinue: {
                showCrystal = true
            })
            .navigationDestination(isPresented: $showCrystal) {
                CrystalView(onClose: onClose)
                    .trackScreen("crystal")
            }
        } else if isPositive {
            // 紫宝石 + 正面心情：心情信纸 + 信封
            HappyView(feeling: feeling, onEnvelopeSaved: onEnvelopeSaved)
                .trackScreen("happy")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { onClose() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
        } else {
            // 紫宝石 + 负面心情：大脑断舍离信纸 + 垃圾桶
            BrainDeclutterView(feeling: feeling, onClose: onClose)
                .trackScreen("brain_declutter")
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
    }
}

// MARK: - 大脑断舍离（负面心情信纸页面）
struct BrainDeclutterView: View {
    let feeling: String
    let onClose: () -> Void

    @State private var answer: String = ""

    // 语音识别
    @State private var isRecording = false
    @State private var audioEngine: AVAudioEngine?
    @State private var recognizer: SFSpeechRecognizer?
    @State private var request: SFSpeechAudioBufferRecognitionRequest?
    @State private var task: SFSpeechRecognitionTask?
    // 首次点击🎙️提示（与 HappyView 共享同一标记，避免重复弹窗）
    @AppStorage("mood_mic_hint_shown_v1") private var micHintShown = false
    @State private var showMicHintAlert = false

    private let dreamyPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
    private let paperBg = Color(red: 250/255, green: 246/255, blue: 236/255)

    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // 与 HappyView welcome 页一致的波点背景
            happyPolkaDotBackground
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 16) {
                    // 头部 HStack：note.text + "大脑断舍离" + 日期 + 🎙️（结构完全对齐 HappyView welcomePage）
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.title2)
                                .foregroundColor(dreamyPurple)
                            Text(L("大脑断舍离", "Brain Dump"))
                                .font(.headline)
                                .foregroundColor(dreamyPurple)
                        }

                        Spacer()

                        Text(currentDate)
                            .font(.subheadline)
                            .foregroundColor(dreamyPurple.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(dreamyPurple.opacity(0.1))
                            .cornerRadius(6)
                            .padding(.trailing, 16)

                        // 麦克风 + 波形（与 HappyView 完全一致）
                        HStack(spacing: 4) {
                            Text("🎙️")
                                .font(.system(size: isRecording ? 28 : 20))
                                .onTapGesture {
                                    if !micHintShown {
                                        micHintShown = true
                                        showMicHintAlert = true
                                        return
                                    }
                                    if isRecording {
                                        stopRecording()
                                    } else {
                                        startVoiceFlow()
                                    }
                                }
                            if isRecording {
                                TimelineView(.animation) { timeline in
                                    let t = timeline.date.timeIntervalSinceReferenceDate
                                    HStack(spacing: 2) {
                                        ForEach(0..<3, id: \.self) { i in
                                            Capsule()
                                                .fill(dreamyPurple.opacity(0.6))
                                                .frame(width: 3, height: 8 + abs(sin(t * 4 + Double(i) * 0.7)) * 18)
                                        }
                                    }
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: isRecording)
                        .alert(L("麦克风语音输入", "Voice Input"), isPresented: $showMicHintAlert) {
                            Button(L("知道了", "Got It"), role: .cancel) {}
                        } message: {
                            Text(L("打开麦克风语音输入您的心情手记，便于您快速记录。再次点击关闭语音输入。", "Turn on the microphone to voice input your mood journal for quick recording. Tap again to turn off."))
                        }

                        Spacer()
                    }

                    // 信纸主体（圆角 16，背景色与 HappyView 一致）
                    ZStack(alignment: .topLeading) {
                        // 占位提示
                        if answer.isEmpty {
                            Text(L("写下你想释放的「\(feeling)」想法，写完把它们通通丢掉...", "Write down your \"\(M(feeling))\" thoughts, then toss them all away..."))
                                .font(.system(size: 20))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }

                        TextEditor(text: $answer)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 340)
                            .font(.system(size: 20))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(paperBg.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(paperBg.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
                )
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // 底部按钮：紫色圆圈 + 白色垃圾桶图标（替代 HappyView 的信封按钮）
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        answer = ""
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundColor(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                          ? .white.opacity(0.7)
                                          : .white)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      ? dreamyPurple.opacity(0.5)
                                      : dreamyPurple)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .animation(.easeInOut, value: answer.isEmpty)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // 与 HappyView 完全相同的波点背景
    private var happyPolkaDotBackground: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let dotSize: CGFloat = 6
            let spacing: CGFloat = 36
            let dotPurple = Color(red: 81/255, green: 29/255, blue: 102/255)

            ZStack {
                Color(red: 247/255, green: 247/255, blue: 247/255)

                ForEach(0..<Int(w / spacing) + 2, id: \.self) { col in
                    ForEach(0..<Int(h / spacing) + 2, id: \.self) { row in
                        Circle()
                            .fill(dotPurple.opacity(0.35))
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: CGFloat(col) * spacing + (row % 2 == 0 ? spacing / 2 : 0),
                                y: CGFloat(row) * spacing
                            )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 语音识别（与 HappyView 完全一致的实现）
    private func startVoiceFlow() {
        requestSpeechPermission()
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                beginRecording()
            }
        }
    }

    private func beginRecording() {
        if task != nil { task?.cancel(); task = nil }
        if audioEngine != nil { audioEngine?.stop(); audioEngine = nil }
        request = nil

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard recognizer != nil, recognizer!.isAvailable else { return }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)

        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true

            task = recognizer?.recognitionTask(with: request) { result, error in
                DispatchQueue.main.async {
                    if self.isRecording, let result = result {
                        self.answer = result.bestTranscription.formattedString
                    }
                    if error != nil {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            isRecording = false
        }
    }

    private func stopRecording() {
        isRecording = false
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

struct FeelingResultView: View {
    let feeling: String
    let onContinue: () -> Void
    @State private var showContinue = false
    @State private var auroraPhase: Double = 0
    @State private var textFloatOffset: CGFloat = 0

    private let sandBrown = Color(red: 0.55, green: 0.45, blue: 0.35)

    private var auroraBackground: some View {
        GeometryReader { geo in
            ZStack {
                // Soft cream-white base
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

                // Pink irregular blob (top left)
                RadialGradient(
                    colors: [
                        Color(red: 0.98, green: 0.80, blue: 0.88).opacity(0.85),
                        Color(red: 0.96, green: 0.70, blue: 0.82).opacity(0.45),
                        .clear
                    ],
                    center: UnitPoint(x: 0.15 + sin(auroraPhase) * 0.05,
                                      y: 0.20 + cos(auroraPhase * 0.8) * 0.05),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.60
                )
                .blur(radius: 55)

                // Mint green irregular blob (top right)
                RadialGradient(
                    colors: [
                        Color(red: 0.75, green: 0.95, blue: 0.85).opacity(0.80),
                        Color(red: 0.65, green: 0.90, blue: 0.78).opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.85 + sin(auroraPhase * 0.9 + 0.5) * 0.06,
                                      y: 0.18 + cos(auroraPhase * 1.1) * 0.05),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.55
                )
                .blur(radius: 60)

                // Sky blue irregular blob (middle)
                RadialGradient(
                    colors: [
                        Color(red: 0.75, green: 0.88, blue: 0.98).opacity(0.80),
                        Color(red: 0.60, green: 0.80, blue: 0.95).opacity(0.40),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50 + sin(auroraPhase * 1.2) * 0.07,
                                      y: 0.50 + cos(auroraPhase * 0.7) * 0.06),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.65
                )
                .blur(radius: 65)

                // Dreamy purple irregular blob (bottom)
                RadialGradient(
                    colors: [
                        Color(red: 0.85, green: 0.78, blue: 0.96).opacity(0.78),
                        Color(red: 0.75, green: 0.68, blue: 0.92).opacity(0.38),
                        .clear
                    ],
                    center: UnitPoint(x: 0.40 + sin(auroraPhase * 0.6 + 0.8) * 0.06,
                                      y: 0.82 + cos(auroraPhase * 1.0) * 0.05),
                    startRadius: 20,
                    endRadius: geo.size.width * 0.60
                )
                .blur(radius: 60)

                // Faint light specks for sparkle
                Canvas { context, size in
                    for i in 0..<60 {
                        let s = Double(i)
                        let x = sin(s * 130.3) * 0.5 + 0.5
                        let y = cos(s * 271.9) * 0.5 + 0.5
                        let r = CGFloat(0.8 + sin(s * 31.7) * 0.7)
                        let opacity = 0.25 + sin(s * 53.2 + auroraPhase * 1.4) * 0.18
                        let pt = CGPoint(x: x * size.width, y: y * size.height)
                        context.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                                     with: .color(Color.white.opacity(Double(opacity))))
                    }
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: true)) {
                    auroraPhase = .pi * 2
                }
            }
        }
    }

    private func acrylicParagraph(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.pingFang(size: 20, weight: .semibold))
                .foregroundColor(sandBrown)

            Text(body)
                .font(.pingFang(size: 15))
                .foregroundColor(sandBrown.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.55), lineWidth: 1.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
                .padding(2.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    var body: some View {
        ZStack {
            auroraBackground

            GeometryReader { geo in
                let goldenY = geo.size.height * 0.618

                // 顶部文字内容（居中，不与气泡重叠）
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 60)

                    VStack(spacing: 14) {
                        Text(L("给自己一分钟时间", "Take a Moment for Yourself"))
                            .font(.pingFang(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(sandBrown)

                        Text(L("共振呼吸练习", "Resonant Breathing"))
                            .font(.pingFang(size: 16))
                            .foregroundColor(sandBrown.opacity(0.8))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)

                    Spacer()
                        .frame(height: 16)

                    VStack(spacing: 6) {
                        Text(L("吸气5.5秒", "Inhale 5.5s"))
                            .font(.pingFang(size: 15))
                            .foregroundColor(sandBrown.opacity(0.75))
                        Text(L("吐气5.5秒", "Exhale 5.5s"))
                            .font(.pingFang(size: 15))
                            .foregroundColor(sandBrown.opacity(0.75))
                        Text(L("一分钟总共呼吸5.5次", "5.5 breaths per minute"))
                            .font(.pingFang(size: 15))
                            .foregroundColor(sandBrown.opacity(0.75))
                        Text(L("练习完美呼吸节奏", "Practice perfect breathing rhythm"))
                            .font(.pingFang(size: 15))
                            .foregroundColor(sandBrown.opacity(0.75))
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .offset(y: textFloatOffset)

                // 漩涡气泡 + 阴影（放置在黄金分割点）
                TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, size in
                        let bubbles = BubbleView.makeBubbles(
                            t: t,
                            cx: Double(size.width / 2),
                            cy: Double(size.height / 2)
                        )
                        BubbleView.drawBubbles(context: context, bubbles: bubbles)
                    }
                    .frame(width: 260, height: 500)
                }
                .position(x: geo.size.width / 2, y: goldenY)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showContinue {
                        Button(L("继续", "Continue")) {
                            onContinue()
                        }
                        .font(.pingFang(size: 16, weight: .medium))
                        .foregroundColor(sandBrown)
                        .transition(.opacity)
                    }
                }
            }
        }
        .onAppear {
            // 文字呼吸浮动：上浮 5.5s / 下落 5.5s，与页面 吸气/吐气 提示同步
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                textFloatOffset = -14
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showContinue = true
                }
            }
        }
    }
}

// MARK: - Happy Module

private extension Color {
    static let happyLilac = Color(red: 0.86, green: 0.82, blue: 0.92)
    static let happyPromptBlue = Color(red: 0.2, green: 0.35, blue: 0.75)
    static let happyPeach = Color(red: 0.96, green: 0.85, blue: 0.78)
    static let happyMintGreen = Color(red: 0.82, green: 0.92, blue: 0.82)
    static let happySoftPurple = Color(red: 0.88, green: 0.82, blue: 0.94)
    static let happyHeartPurple = Color(red: 0.65, green: 0.45, blue: 0.80)
    static let happyWarmYellow = Color(red: 0.98, green: 0.94, blue: 0.82)
    static let happySoftPink = Color(red: 0.95, green: 0.87, blue: 0.88)
}

private enum HappyPageType {
    case welcome
    case `default`
    case summary
}

struct HappyDiaryData: Codable, Identifiable, Equatable {
    let id: UUID
    let date: String
    let content1: String
    let content2: String
    var envelopeColor: EnvelopeColor = .ivory

    init(id: UUID = UUID(), date: String, content1: String, content2: String, envelopeColor: EnvelopeColor = .ivory) {
        self.id = id
        self.date = date
        self.content1 = content1
        self.content2 = content2
        self.envelopeColor = envelopeColor
    }
}

enum EnvelopeColor: String, CaseIterable, Codable {
    case ivory, sakura, cherry, mocha, blue

    /// 信封纸面颜色
    var color: Color {
        switch self {
        case .ivory:  return Color(red: 255/255, green: 251/255, blue: 240/255)
        case .sakura: return Color(red: 254/255, green: 223/255, blue: 225/255)
        case .cherry: return Color(red: 201/255, green: 55/255,  blue: 86/255)
        case .mocha: return Color(red: 164/255, green: 120/255, blue: 100/255)
        case .blue:   return Color(red: 81/255,  green: 168/255, blue: 221/255)
        }
    }

    /// 信封封盖颜色
    var coverColor: Color {
        switch self {
        case .ivory:  return Color(red: 139/255, green: 129/255, blue: 195/255) // 紫
        case .sakura: return Color(red: 177/255, green: 150/255, blue: 147/255) // 粉灰
        case .cherry: return Color(red: 140/255, green: 67/255,  blue: 86/255)  // 梅
        case .mocha:  return Color(red: 150/255, green: 75/255,  blue: 55/255)  // 深赤陶陶土色（暖大地色，与奶茶棕纸面同色系呼应）
        case .blue:   return Color(red: 0/255,   green: 92/255,  blue: 175/255) // 釉蓝
        }
    }

    /// 日期文字颜色：cherry / mocha / blue 深色/中深色封盖用象牙白，其余浅色封盖直接用封盖色
    var dateTextColor: Color {
        switch self {
        case .cherry, .mocha, .blue:
            return Color(red: 255/255, green: 251/255, blue: 240/255) // 象牙白（cover 上日期白色）
        case .ivory, .sakura:
            return coverColor
        }
    }
}

struct HappyView: View {
    let feeling: String
    let onEnvelopeSaved: (HappyDiaryData) -> Void
    @State private var currentPage: HappyPageType = .welcome
    @State private var answer1 = ""
    @State private var answer2 = ""
    @State private var hasSubmitted1 = false
    @State private var hasSubmitted2 = false
    @State private var showEnvelope = false
    @State private var selectedEnvelopeColor: EnvelopeColor = .ivory

    // 语音识别
    @State private var isRecording = false
    @State private var audioEngine: AVAudioEngine?
    @State private var recognizer: SFSpeechRecognizer?
    @State private var request: SFSpeechAudioBufferRecognitionRequest?
    @State private var task: SFSpeechRecognitionTask?
    // 首次点击🎙️提示（仅在用户首次进入心情页点击麦克风时弹出一次）
    @AppStorage("mood_mic_hint_shown_v1") private var micHintShown = false
    @State private var showMicHintAlert = false

    private let negativeMoods: Set<String> = ["压抑", "忧虑", "烦躁", "无聊", "不安"]
    private var isNegativeMood: Bool { negativeMoods.contains(feeling) }
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private let lineHeight: CGFloat = 34
    private let dreamyPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
    
    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()
            
            switch currentPage {
            case .welcome:
                welcomePage
            case .default:
                pageContent(
                    line1: "常常微笑，常常快乐",
                    line2: "我还想继续...",
                    hint: "以后我还想要...",
                    answer: $answer2,
                    hasSubmitted: hasSubmitted2,
                    onSubmit: submitSecondPage
                )
            case .summary:
                summaryView
            }
        }
        .animation(.easeInOut(duration: 0.8), value: currentPage)
        .animation(.easeInOut(duration: 0.5), value: showEnvelope)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private var backgroundView: some View {
        switch currentPage {
        case .welcome:
            return AnyView(happyPolkaDotBackground)
        case .default:
            return AnyView(Color.happySoftPink.opacity(0.5))
        case .summary:
            return AnyView(happyPolkaDotBackground)
        }
    }

    private var happyPolkaDotBackground: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let dotSize: CGFloat = 6
            let spacing: CGFloat = 36
            let dotPurple = Color(red: 81/255, green: 29/255, blue: 102/255)

            ZStack {
                Color(red: 247/255, green: 247/255, blue: 247/255)

                ForEach(0..<Int(w / spacing) + 2, id: \.self) { col in
                    ForEach(0..<Int(h / spacing) + 2, id: \.self) { row in
                        Circle()
                            .fill(dotPurple.opacity(0.35))
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: CGFloat(col) * spacing + (row % 2 == 0 ? spacing / 2 : 0),
                                y: CGFloat(row) * spacing
                            )
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    private var welcomePage: some View {
        let dreamyPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
        
        return VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundColor(dreamyPurple)
                        Text(L("心情", "Mood"))
                            .font(.headline)
                            .foregroundColor(dreamyPurple)
                    }

                    Spacer()

                    Text(currentDate)
                        .font(.subheadline)
                        .foregroundColor(dreamyPurple.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(dreamyPurple.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.trailing, 16)

                    // 麦克风 + 波形
                    HStack(spacing: 4) {
                        Text("🎙️")
                            .font(.system(size: isRecording ? 28 : 20))
                            .onTapGesture {
                                // 首次点击弹出提示，不立即开始录音
                                if !micHintShown {
                                    micHintShown = true
                                    showMicHintAlert = true
                                    return
                                }
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startVoiceFlow()
                                }
                            }
                        if isRecording {
                            TimelineView(.animation) { timeline in
                                let t = timeline.date.timeIntervalSinceReferenceDate
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Capsule()
                                            .fill(dreamyPurple.opacity(0.6))
                                            .frame(width: 3, height: 8 + abs(sin(t * 4 + Double(i) * 0.7)) * 18)
                                    }
                                }
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
                    .alert(L("麦克风语音输入", "Voice Input"), isPresented: $showMicHintAlert) {
                        Button(L("知道了", "Got It"), role: .cancel) {}
                    } message: {
                        Text(L("打开麦克风语音输入您的心情手记，便于您快速记录。再次点击关闭语音输入。", "Turn on the microphone to voice input your mood journal for quick recording. Tap again to turn off."))
                    }

                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    if answer1.isEmpty && !hasSubmitted1 && !isNegativeMood {
                        Text(L("试着描述一下这种\(feeling)的感觉...", "Try to describe this \(M(feeling)) feeling..."))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    
                    TextEditor(text: $answer1)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 340)
                        .font(.system(size: 20))
                        .disabled(hasSubmitted1)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.8))
                    .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
            )
            .padding(.horizontal, 24)

            if !hasSubmitted1 {
                Button(action: submitFirstPage) {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                        .foregroundColor(answer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? .white.opacity(0.7)
                                         : .white)
                        .padding(14)
                        .background(
                            Circle()
                                .fill(answer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      ? dreamyPurple.opacity(0.5)
                                      : dreamyPurple)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .disabled(answer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .animation(.easeInOut, value: hasSubmitted1)
    }
    
    private var summaryView: some View {
        ZStack {
            if !showEnvelope {
                VStack(spacing: 30) {
                    Spacer()

                    VStack(spacing: 16) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.title2)
                                    .foregroundColor(dreamyPurple)
                                Text(L("心情", "Mood"))
                                    .font(.headline)
                                    .foregroundColor(dreamyPurple)
                            }

                            Spacer()

                            Text(currentDate)
                                .font(.subheadline)
                                .foregroundColor(dreamyPurple.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(dreamyPurple.opacity(0.1))
                                .cornerRadius(6)

                            Spacer()
                        }

                        ScrollView(.vertical, showsIndicators: false) {
                            Text(answer1)
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                        .frame(minHeight: 340)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.8))
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showEnvelope = true
                        }
                    }) {
                        Image(systemName: "envelope.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(dreamyPurple)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }

                    Spacer()
                }
                .transition(.opacity)
            }
            
            if showEnvelope {
                ZStack {
                    // 信封居中于屏幕
                    VStack {
                        Spacer()
                        // 扇形彩色纸条供用户选择，位于信封上方
                        colorFanView
                            .padding(.bottom, 24)
                        // 信封
                        Button(action: {
                            let data = HappyDiaryData(
                                date: currentDate,
                                content1: answer1,
                                content2: answer2,
                                envelopeColor: selectedEnvelopeColor
                            )
                            onEnvelopeSaved(data)
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedEnvelopeColor.color)
                                    .frame(width: 200, height: 130)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(selectedEnvelopeColor.coverColor.opacity(0.4), lineWidth: 1.5)
                                    )

                                HappyInvertedTriangle()
                                    .fill(selectedEnvelopeColor.coverColor.opacity(0.35))
                                    .frame(width: 200, height: 130)

                                Text(currentDate)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(selectedEnvelopeColor.dateTextColor)
                                    .offset(y: -20)

                                HappyHeartShape()
                                    .fill(selectedEnvelopeColor.coverColor)
                                    .frame(width: 14, height: 14)
                                    .offset(y: 50)
                            }
                            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - 横排菱形颜色选择器

    private var colorFanView: some View {
        let colors = EnvelopeColor.allCases

        return HStack(spacing: 14) {
            ForEach(colors, id: \.self) { color in
                let isSelected = selectedEnvelopeColor == color
                let scale: CGFloat = isSelected ? 1.35 : 1.0

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEnvelopeColor = color
                    }
                }) {
                    Diamond()
                        .fill(color.color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Diamond()
                                .stroke(color.coverColor, lineWidth: 1.5)
                        )
                        .overlay(
                            Diamond()
                                .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                        .scaleEffect(scale)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .zIndex(isSelected ? 10 : 1)
            }
        }
        .frame(height: 36)
    }

    private func pageContent(line1: String, line2: String?, hint: String, answer: Binding<String>, hasSubmitted: Bool, onSubmit: @escaping () -> Void) -> some View {
        let dreamyPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
        
        return VStack(spacing: 24) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 10) {
                Text(line1)
                    .font(.pingFang(size: 28))
                    .fontWeight(.medium)
                    .foregroundColor(dreamyPurple)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                
                if let line2 = line2 {
                    Text(line2)
                        .font(.pingFang(size: 18))
                        .fontWeight(.regular)
                        .foregroundColor(dreamyPurple.opacity(0.7))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            VStack(spacing: 14) {
                ZStack(alignment: .topLeading) {
                    if answer.wrappedValue.isEmpty && !hasSubmitted {
                        Text(hint)
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    
                    TextEditor(text: answer)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 240)
                        .font(.system(size: 20))
                        .disabled(hasSubmitted)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 250/255, green: 246/255, blue: 236/255).opacity(0.8))
                    .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 4)
            )
            .padding(.horizontal, 24)
            
            if !hasSubmitted {
                Button(action: onSubmit) {
                    Text(L("完成", "Done"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(dreamyPurple)
                        .cornerRadius(12)
                }
                .disabled(answer.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(answer.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .animation(.easeInOut, value: hasSubmitted)
    }
    
    private func submitFirstPage() {
        guard !answer1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hasSubmitted1 = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showEnvelope = true
            currentPage = .summary
        }
    }
    
    private func submitSecondPage() {
        guard !answer2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        hasSubmitted2 = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            currentPage = .summary
        }
    }

    // MARK: - 语音识别
    private func startVoiceFlow() {
        requestSpeechPermission()
    }

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                beginRecording()
            }
        }
    }

    private func beginRecording() {
        if task != nil { task?.cancel(); task = nil }
        if audioEngine != nil { audioEngine?.stop(); audioEngine = nil }
        request = nil

        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard recognizer != nil, recognizer!.isAvailable else { return }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)

        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true

            task = recognizer?.recognitionTask(with: request) { result, error in
                DispatchQueue.main.async {
                    if self.isRecording, let result = result {
                        let text = result.bestTranscription.formattedString
                        if self.currentPage == .welcome {
                            self.answer1 = text
                        } else {
                            self.answer2 = text
                        }
                    }
                    if error != nil {
                        self.stopRecording()
                    }
                }
            }
        } catch {
            isRecording = false
        }
    }

    private func stopRecording() {
        isRecording = false
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        // 恢复音频会话为播放模式，避免影响后续音频播放
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

private struct HappyInvertedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct HappyHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width / 2, y: height))
        
        path.addCurve(
            to: CGPoint(x: 0, y: height / 4),
            control1: CGPoint(x: width / 2, y: height * 0.75),
            control2: CGPoint(x: 0, y: height / 2)
        )
        
        path.addCurve(
            to: CGPoint(x: width / 2, y: height / 4),
            control1: CGPoint(x: 0, y: 0),
            control2: CGPoint(x: width / 2, y: 0)
        )
        
        path.addCurve(
            to: CGPoint(x: width, y: height / 4),
            control1: CGPoint(x: width / 2, y: 0),
            control2: CGPoint(x: width, y: 0)
        )
        
        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width, y: height / 2),
            control2: CGPoint(x: width / 2, y: height * 0.75)
        )
        
        return path
    }
}
