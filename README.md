# 消消乐 iOS 版（Swift + SwiftUI）

由安卓版《消消乐》（v3.7.3 / versionCode 24）1:1 移植的 iOS 原生应用，支持 iOS 16.0 及以上、仅竖屏、零第三方依赖、离线可玩。

- 原创作者：施予恩
- Bundle ID：`com.shiyuen.match3`
- 分发方式：仅自用 / 测试分发（不上架 App Store）
- 推荐安装方式：**AltStore / SideStore 自签**

---

## 一、如何编译出 `.ipa`（无需 Mac）

1. 在 GitHub 新建一个公开仓库（或推送到现有仓库），将本目录所有文件（含 `.github/workflows/build-ios.yml`）推到 `main` 分支。
2. 打开仓库的 **Actions** 页面，点击 **Build iOS IPA**（推送后会自动运行，也可点 **Run workflow** 手动触发）。
3. 等待 macOS runner 编译完成，在运行详情页底部 **Artifacts** 下载 `Xiaoxiaole-iOS-IPA`，解压得到未签名的 `Xiaoxiaole.ipa`。

如有 Mac，直接用 Xcode 打开 `Xiaoxiaole.xcodeproj`，选择目标设备或真机即可 `Cmd + R` 编译运行。

---

## 二、安装到 iPhone（默认：AltStore / SideStore 自签）

### 推荐方式：AltStore / SideStore 自签（零成本）
1. 在电脑或 iPhone 上安装 [AltStore](https://altstore.io/) 或 [SideStore](https://sidestore.io/)，使用任意免费 Apple ID 登录。
2. 将 `Xiaoxiaole.ipa` 发送到 iPhone（隔空投送、文件 App 等）。
3. 在 AltStore / SideStore 中点击 `+` 选择 `Xiaoxiaole.ipa` 完成签名安装。
4. 在 iPhone **设置 → 通用 → VPN 与设备管理** 中信任自己的 Apple ID 证书即可打开。
5. 免费账号签名的证书每 7 天过期，到期前在 AltStore / SideStore 里刷新续签即可（不丢存档）。

### 备选方式：TestFlight（需 99 美元/年 Apple Developer 账号）
1. 在 Xcode 中将 `DEVELOPMENT_TEAM` 改为你的付费开发者团队，签名并 `Product → Archive` 上传到 App Store Connect。
2. 在 App Store Connect 的 TestFlight 页面添加内部或外部测试员，测试员通过 TestFlight App 下载安装（每版有效期 90 天）。

### 备选方式：Xcode 直装（需一台 Mac + 数据线）
1. 用数据线将 iPhone 连到 Mac，并在 iPhone 上开启开发者模式（设置 → 隐私与安全性 → 开发者模式）。
2. 在 Xcode 打开 `Xiaoxiaole.xcodeproj`，在 **Signing & Capabilities** 登录 Apple ID。
3. 顶部设备栏选择你的 iPhone，点击运行（`Cmd + R`）即可装入手机（免费账号有效期 7 天）。

---

## 三、`version.json` 说明

iOS 版与安卓版共用同一份 `version.json`（优先请求 GitHub 原始链接，失败回退到 jsDelivr）。检测到 `versionCode` 大于当前版本时，弹窗提示“发现新版本”，点击“前往更新”后跳转到 `version.json` 里的 `iosUrl` 字段；如果没有 `iosUrl`，则跳转到 GitHub Releases 发布页。

**注意：第一次发布 iOS 版时，记得在 `version.json` 里加一个 `iosUrl` 字段，值填 iOS 安装包的下载地址**（例如 GitHub Release 里 `.ipa` 的链接，或 AltStore 的安装说明页）。不加的话，点“前往更新”只会打开 Releases 页，那里现在还没有 iOS 的包。

---

## 四、审校记录（相对初版的改动）

- **修复编译配置**：工程里没有共享 scheme，`xcodebuild -scheme` 在 CI 上会找不到 scheme 而失败；已改为 `-target Xiaoxiaole` 编译。
- **补上应用图标**：`AppIcon.appiconset` 原来是空的，装上去图标是空白的；已用安卓版同款兔子图补上 1024×1024 图标。开始界面的兔子也从 🐰 表情换成了同一张兔子图。
- **反馈补上 Referer**：与安卓版保持一致，提交反馈时带上 `Referer: https://muse.ai/` 请求头。
- **手势与安卓版对齐**：短距离斜向拖动现在按点选抬起的格子处理（原来直接忽略）。
- **下落顺序修正**：安卓版消除后同列水果的上下顺序会翻过来（`applyGravityAndRefill` 未反转堆栈）；iOS 版已按正确重力顺序实现，水果直落不串位。
- **开局死局修正**：安卓版开局棋盘不保证有可走的步，极少数情况会开局即死局； iOS 版开局会检测，无解自动洗牌。
- **音效说明**：iOS 版音效为代码合成的提示音（零音频文件），与安卓版生成的音效文件音色不同，触发时机一致。
