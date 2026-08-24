//
//  BubbleView.swift
//  TheApp
//
//  由 Bubble 项目导入，原 ContentView.swift 重命名以避免冲突
//  Created by Yi Yang on 2026/8/6.
//

import SwiftUI

// 气泡数据：路径 + 中心 + 阴影
struct BubbleData {
    let path: Path
    let centerX: Double
    let centerY: Double
    let shadow: Path
}

// 气泡样式：描边色 + 线宽
struct BubbleStyle {
    let strokeColor: Color
    let lineWidth: CGFloat
}

struct BubbleView: View {
    var body: some View {
        ZStack {
            Color(red: 245/255, green: 245/255, blue: 242/255)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Days OFF")
                    .font(Font.custom("IowanOldStyle-Bold", size: 48))
                    .foregroundColor(Color(red: 0.58, green: 0.58, blue: 0.60))
                    .tracking(-0.5)
                    .padding(.top, 42)

                Spacer(minLength: 0)
            }

            TimelineView(.animation(minimumInterval: 1.0/30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let bubbles = Self.makeBubbles(
                        t: t,
                        cx: Double(size.width / 2),
                        cy: Double(size.height / 2)
                    )
                    Self.drawBoards(context: context, cx: Double(size.width / 2), cy: Double(size.height / 2))
                    Self.drawBubbles(context: context, bubbles: bubbles)
                }
                .frame(width: 260, height: 500)
            }
        }
    }

    // 生成所有气泡路径
    static func makeBubbles(t: Double, cx: Double, cy: Double) -> [(data: BubbleData, style: BubbleStyle)] {
        let shadowCenterY = cy + 245

        func bubblePath(
            rx: Double, ry: Double,
            speed1: Double, speed2: Double, speed3: Double,
            freq1: Double, freq2: Double, freq3: Double,
            phase: Double,
            windAmpX: Double, windAmpY: Double,
            windSpeedX: Double, windSpeedY: Double,
            windPhaseX: Double, windPhaseY: Double,
            rotation: Double = 0
        ) -> BubbleData {
            let windX = sin(t * windSpeedX + windPhaseX) * windAmpX
            let windY = cos(t * windSpeedY + windPhaseY) * windAmpY
            let centerShiftX = cx + windX
            let centerShiftY = cy + windY
            let pointCount = 64
            let cosR = cos(rotation)
            let sinR = sin(rotation)

            var path = Path()
            var shadow = Path()
            for i in 0...pointCount {
                let theta = Double(i) / Double(pointCount) * 2 * .pi
                let w =
                    sin(t * speed1 + theta * freq1 + phase) * 4
                  + sin(t * speed2 + theta * freq2 + phase + 1.2) * 3
                  + sin(t * speed3 + theta * freq3 + phase + 0.7) * 2
                // 原始坐标（相对中心）
                let dx = cos(theta) * (rx + w)
                let dy = sin(theta) * (ry + w)
                // 旋转后坐标
                let rx2 = dx * cosR - dy * sinR
                let ry2 = dx * sinR + dy * cosR
                let x = centerShiftX + rx2
                let y = centerShiftY + ry2
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                // 阴影不旋转，保持水平
                let sx = centerShiftX + cos(theta) * (rx + w) * 0.70
                let sy = shadowCenterY + sin(theta) * 5
                if i == 0 {
                    shadow.move(to: CGPoint(x: sx, y: sy))
                } else {
                    shadow.addLine(to: CGPoint(x: sx, y: sy))
                }
            }
            path.closeSubpath()
            shadow.closeSubpath()

            return BubbleData(path: path, centerX: centerShiftX, centerY: centerShiftY, shadow: shadow)
        }

        let pink = bubblePath(
            rx: 110, ry: 172,
            speed1: 1.3, speed2: 0.9, speed3: 1.7,
            freq1: 3, freq2: 5, freq3: 2,
            phase: 0,
            windAmpX: 5, windAmpY: 2,
            windSpeedX: 0.6, windSpeedY: 0.5,
            windPhaseX: 0, windPhaseY: 0
        )
        let blue = bubblePath(
            rx: 107, ry: 164,
            speed1: 1.1, speed2: 1.0, speed3: 1.9,
            freq1: 4, freq2: 6, freq3: 3,
            phase: 1.5,
            windAmpX: 6, windAmpY: 3,
            windSpeedX: 0.55, windSpeedY: 0.45,
            windPhaseX: 1.2, windPhaseY: 0.8
        )
        let purple = bubblePath(
            rx: 113, ry: 169,
            speed1: 1.0, speed2: 1.4, speed3: 0.8,
            freq1: 5, freq2: 3, freq3: 7,
            phase: 2.4,
            windAmpX: 7, windAmpY: 5,
            windSpeedX: 0.7, windSpeedY: 0.65,
            windPhaseX: 2.0, windPhaseY: 1.5
        )
        let pinkStyle = BubbleStyle(strokeColor: Color(red: 0.95, green: 0.55, blue: 0.75), lineWidth: 1.5)
        let blueStyle = BubbleStyle(strokeColor: Color(red: 0.45, green: 0.65, blue: 0.95), lineWidth: 1.5)
        let purpleStyle = BubbleStyle(strokeColor: Color(red: 0.65, green: 0.45, blue: 0.85), lineWidth: 1.5)

        return [
            (pink, pinkStyle),
            (blue, blueStyle),
            (purple, purpleStyle)
        ]
    }

    // 绘制所有气泡（阴影 + 描边）
    static func drawBubbles(
        context: GraphicsContext,
        bubbles: [(data: BubbleData, style: BubbleStyle)]
    ) {
        let shadowStroke = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        let bubbleStroke = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

        // 先画所有阴影
        let shadowColors: [Color] = [
            Color(red: 0.95, green: 0.55, blue: 0.75),
            Color(red: 0.45, green: 0.65, blue: 0.95),
            Color(red: 0.65, green: 0.45, blue: 0.85)
        ]
        for (i, b) in bubbles.enumerated() {
            context.stroke(b.data.shadow, with: .color(shadowColors[i]), style: shadowStroke)
        }

        // 再画所有气泡描边
        for b in bubbles {
            context.stroke(b.data.path, with: .color(b.style.strokeColor), style: bubbleStroke)
        }
    }

    // 绘制四块竖向叠放的白色矩形板（底部和右侧各有一条黑线）
    private static func drawBoards(context: GraphicsContext, cx: Double, cy: Double) {
        // 气泡 ry ≈ 172，顶部气泡中心 cy=250，
        // 气泡上缘 ≈ 250 - 172 = 78，气泡下缘 ≈ 250 + 172 = 422
        let boardW: Double = 72
        let boardH: Double = 14
        // 最上一块略高于气泡上缘；最下一块略高于气泡下缘
        let topY: Double = 56
        let bottomY: Double = 390
        let count = 4
        let gap: Double = (bottomY - topY) / Double(count - 1)

        for i in 0..<count {
            let yTop = topY + Double(i) * gap - boardH / 2
            let rect = CGRect(
                x: cx - boardW / 2,
                y: yTop,
                width: boardW,
                height: boardH
            )
            // 与屏幕背景同色：中性护眼纸白
            context.fill(Path(rect), with: .color(Color(red: 245/255, green: 245/255, blue: 242/255)))
            // 黑边：底部 + 右侧
            var bottomLine = Path()
            bottomLine.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            bottomLine.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            // 中性银灰色
            let silver = Color(red: 0.58, green: 0.58, blue: 0.60)
            // 粗马克笔风格：粗线宽 + 圆端圆接
            let silverStroke = StrokeStyle(
                lineWidth: 3.0,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 0
            )
            // 稍微错开两段，模拟马克笔叠画的厚重感
            context.stroke(bottomLine, with: .color(silver), style: silverStroke)
            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: rect.minX + 1, y: rect.maxY + 0.6))
                    p.addLine(to: CGPoint(x: rect.maxX + 0.6, y: rect.maxY + 0.6))
                },
                with: .color(silver.opacity(0.55)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
