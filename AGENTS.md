# AGENTS.md

macOS 网络配置切换工具（NetProfile Switcher），SwiftUI 单 Target Xcode 工程，无第三方依赖、无测试 Target。

## 构建与验证

```bash
xcodebuild -project NetworkSelectorForMacOS.xcodeproj -scheme NetworkSelectorForMacOS -configuration Debug build
```

项目没有测试与 lint 配置，验证方式只有构建成功。默认 configuration 是 Release（CI 与 release 流程均构建 Release）。

## 环境约束

- `MACOSX_DEPLOYMENT_TARGET = 26.4`（macOS 26 / Tahoe），依赖 Xcode 26.5，以 pbxproj 为准。
- 使用 macOS 26 专属 API（如 `.glass` 按钮样式），不要替换为旧式等价写法，也不要按低版本写法实现。

## 架构

- `ContentView.swift`：主界面（`NavigationSplitView` 侧边栏 + 详情）+ 全部交互逻辑（`@AppStorage` 状态、配置增删改、切换/应用、网络信息轮询刷新）。
- `NetworkAutomation.swift`：网络命令执行、信息解析、App Intents 与 `AppShortcutsProvider`。
- `SudoersAccessManager.swift`：提权核心。首次使用时安装受限 sudoers 规则与 wrapper 脚本，之后通过 `sudo -n` 免密执行；安装/移除需管理员授权（osascript 弹窗）。
- `AppPages.swift`：设置与关于窗口（含 sudoers 启用/移除开关）。
- `Localization.swift`：`appText(_:languageSetting:_:)` 国际化入口。

## 关键约定

- **用户可见文案一律走本地化**：key 定义在 `en.lproj/Localizable.strings` 与 `zh-Hans.lproj/Localizable.strings`，新增 key 必须同时加到两个文件。不要写死 `Text("文字")`。
- `appText` 的可变参数重载基于 `String(format:)`，字符串里的 `%@` 必须与实际传参数量匹配。
- **网络切换命令禁止绕过 sudoers**：执行 `networksetup -setmanual/-setdhcp/-setdnsservers` 一律走 `SudoersAccessManager.execute`（参数数组形式，命令不可含 shell 拼接）。查询命令（`-getinfo`、`-getdnsservers`）无需提权，走 `NetworkAutomation.runCommand`。
- 配置文件以 JSON 字符串存在 UserDefaults（key `networkProfiles`），通过 `@AppStorage` 读写。
- 侧边栏使用系统 `sidebarToggle` 切换按钮，该按钮在工具栏「图标和文本」模式下会跑到右侧（macOS 26 已知 bug）。已用侧边栏列的 `.navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)` 规避，不要移除该列宽约束，否则 bug 复现。
- 修改源文件后需手动把新文件加入 `NetworkSelectorForMacOS.xcodeproj`（文件未在工程中会自动 Build 失败；必要时用 `xcodebuild` 校验）。

## Git / 发布

- 提交遵循约定式提交，用中文信息（见 commit-guide 技能）。
- Release 由打 tag `vX.Y.Z` 触发 CI：自动把 `MARKETING_VERSION` 改为 tag 版本并生成 DMG 发布，无需手动改版本号。
