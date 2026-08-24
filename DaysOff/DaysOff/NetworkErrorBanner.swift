import SwiftUI

/// 顶部居中轻量提示条 — 网络不稳定时展示 "当前网络环境不稳定"
/// 3 秒后自动消失；也可以点击 × 手动关闭。
struct NetworkErrorBanner: View {
    @Binding var isPresented: Bool
    let message: String
    var autoDismissDelay: TimeInterval = 3.0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.35))

            Text(message)
                .font(.pingFang(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33))

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.40, green: 0.36, blue: 0.33).opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 250/255, green: 246/255, blue: 236/255))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 120/255, green: 110/255, blue: 96/255).opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            guard autoDismissDelay > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Helper overlay modifier

extension View {
    /// 在屏幕顶部居中叠加网络错误提示条；当 show 为 true 时滑入。
    @ViewBuilder
    func networkErrorBanner(show: Binding<Bool>, message: String = "当前网络环境不稳定") -> some View {
        overlay(
            VStack(spacing: 0) {
                if show.wrappedValue {
                    NetworkErrorBanner(isPresented: show, message: message)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .animation(.easeInOut(duration: 0.25), value: show.wrappedValue)
            , alignment: .top
        )
    }
}
