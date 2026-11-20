import SwiftUI

private struct UpdateInfo: Identifiable {
    let id = UUID()
    let versionName: String
    let changelog: String
    let updateURL: URL
}

struct ContentView: View {
    @StateObject private var controller = GameController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var showFeedbackSheet = false
    @State private var feedbackText = ""
    @State private var updateDialogShown = false
    @State private var updateInfo: UpdateInfo?

    private let feedbackURL = "https://formsubmit.co/ajax/49743fbfbc880f648553cfd63aba0a11"
    private let rawUpdateURL = "https://raw.githubusercontent.com/shiyuen88888-a11y/xiaoxiaole/main/version.json"
    private let cdnUpdateURL = "https://cdn.jsdelivr.net/gh/shiyuen88888-a11y/xiaoxiaole@main/version.json"
    private let defaultUpdatePage = "https://github.com/shiyuen88888-a11y/xiaoxiaole/releases"

    private let demoFruits = ["apple", "banana", "grape", "strawberry", "blueberry"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0x38 / 255, green: 0xBD / 255, blue: 0xF8 / 255),
                    Color(red: 0xA8 / 255, green: 0x55 / 255, blue: 0xF7 / 255),
                    Color(red: 0xF4 / 255, green: 0x72 / 255, blue: 0xB6 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if controller.inGame {
                gameScreen
            } else {
                startScreen
            }

            if let end = controller.levelEndState {
                levelEndOverlay(end)
            }

            if controller.showComboBanner {
                Text("牛逼！")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0xFA / 255, green: 0xCC / 255, blue: 0x15 / 255), radius: 14, x: 0, y: 4)
                    .scaleEffect(controller.comboBannerScale)
                    .opacity(controller.comboBannerOpacity)
                    .allowsHitTesting(false)
            }

            if let toast = controller.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showFeedbackSheet) {
            feedbackSheet
        }
        .alert(item: $updateInfo) { info in
            Alert(
                title: Text("发现新版本 v\(info.versionName)"),
                message: Text(info.changelog.isEmpty ? "已有新版本可用，前往更新吧！" : info.changelog),
                primaryButton: .default(Text("前往更新")) {
                    openURL(info.updateURL)
                },
                secondaryButton: .cancel(Text("稍后再说"))
            )
        }
        .onAppear {
            if !updateDialogShown {
                checkForUpdate()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && !updateDialogShown {
                checkForUpdate()
            }
        }
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 8) {
                ForEach(demoFruits, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 44 * 0.11))
                }
            }

            Image("rabbit")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 52 * 0.11))
                .padding(.top, 14)

            Text("消消乐")
                .font(.system(size: 60, weight: .bold))
                .kerning(4)
                .foregroundColor(.white)
                .padding(.top, 4)

            Text("原创作者：施予恩")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .padding(.top, 10)

            Button {
                controller.startGame()
            } label: {
                Text("开始游戏")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255),
                                Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 28)

            if controller.bestScore > 0 {
                Text("历史最高分：\(controller.bestScore)")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.85))
                    .padding(.top, 16)
            }

            VStack(spacing: 6) {
                Text("公告")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255))
                Text("v3.7.3版本公告\n• 更新检测更稳")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255))
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.top, 20)

            Button {
                feedbackText = ""
                showFeedbackSheet = true
            } label: {
                Text("💬 反馈建议")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
            }
            .padding(.top, 16)

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Game Screen

    private var gameScreen: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                hudPill(title: "关卡", value: "\(controller.level)", valueColor: Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255))
                hudPill(title: "分数", value: "\(controller.score)", valueColor: Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255))
                hudPill(title: "目标", value: "\(controller.target)", valueColor: Color(red: 0x93 / 255, green: 0x33 / 255, blue: 0xEA / 255))
                hudPill(title: "剩余步数", value: "\(controller.moves)", valueColor: Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255))

                Button {
                    controller.toggleMute()
                } label: {
                    Text(controller.muted ? "🔇" : "🔊")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 54)
                        .background(Color.white.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            ProgressView(
                value: controller.target > 0
                    ? min(1.0, Double(controller.score) / Double(controller.target))
                    : 0.0
            )
            .tint(Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255))
            .background(Color.white.opacity(0.45))
            .clipShape(Capsule())
            .scaleEffect(x: 1, y: 1.8, anchor: .center)
            .padding(.vertical, 2)

            BoardView(controller: controller)

            HStack(spacing: 10) {
                Button {
                    controller.restartLevel()
                } label: {
                    Text("🔄 重新开始")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }

                Button {
                    controller.showHint()
                } label: {
                    Text("💡 提示")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }

                Button {
                    controller.backToStart()
                } label: {
                    Text("🏠 返回")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
                }
            }

            Text("原创作者：施予恩")
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }

    private func hudPill(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255))
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Level End Overlay

    private func levelEndOverlay(_ end: LevelEndState) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(end.win ? "🎉 过关啦！" : "😢 步数用完了")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255))

                Text("第 \(end.level) 关" + (end.win ? "完成！" : "差一点点") + "\n得分 \(end.score) / 目标 \(end.target)")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0x66 / 255, green: 0x66 / 255, blue: 0x66 / 255))

                Button {
                    controller.startLevel(end.win ? end.level + 1 : end.level)
                } label: {
                    Text(end.win ? "下一关" : "再来一次")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0xF9 / 255, green: 0x73 / 255, blue: 0x16 / 255),
                                    Color(red: 0xEC / 255, green: 0x48 / 255, blue: 0x99 / 255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Feedback Sheet

    private var feedbackSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("欢迎提出问题或建议，提交后会直接发送给作者。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(20)
            .navigationTitle("反馈建议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showFeedbackSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") {
                        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            controller.showToast("请先输入内容")
                            return
                        }
                        showFeedbackSheet = false
                        sendFeedback(trimmed)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sendFeedback(_ text: String) {
        controller.showToast("正在发送…")
        guard let url = URL(string: feedbackURL) else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://muse.ai/", forHTTPHeaderField: "Referer")

        let payload: [String: String] = [
            "name": "消消乐玩家",
            "subject": "消消乐反馈建议",
            "message": text
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, _ in
            var ok = false
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let successBool = json["success"] as? Bool {
                    ok = successBool
                } else if let successStr = json["success"] as? String {
                    ok = (successStr == "true")
                }
            }
            DispatchQueue.main.async {
                controller.showToast(ok ? "反馈已发送，谢谢！" : "发送失败，请检查网络后重试")
            }
        }.resume()
    }

    // MARK: - Update Check (GitHub Raw first, jsDelivr fallback, silent when offline)

    private func checkForUpdate() {
        let currentCode = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        Task {
            let info = await fetchVersionJSON(rawUpdateURL) ?? await fetchVersionJSON(cdnUpdateURL)
            guard let info else { return }
            let latestCode = info["versionCode"] as? Int ?? 0
            let latestName = info["versionName"] as? String ?? ""
            let changelog = info["changelog"] as? String ?? ""
            let targetUrlStr = (info["iosUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? defaultUpdatePage

            if latestCode > currentCode, let url = URL(string: targetUrlStr) {
                await MainActor.run {
                    guard !updateDialogShown else { return }
                    updateDialogShown = true
                    updateInfo = UpdateInfo(versionName: latestName, changelog: changelog, updateURL: url)
                }
            }
        }
    }

    private func fetchVersionJSON(_ urlString: String) async -> [String: Any]? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}
