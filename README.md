> [!WARNING]
> 本应用未经过 Apple 开发者签名与公证，首次运行时 macOS 可能提示「已损坏，无法打开」。
> 请在终端执行一次以下命令，然后重新打开应用：
>
> ```bash
> xattr -dr com.apple.quarantine "/Applications/NetProfile Switcher.app"
> ```

# NetProfile Switcher for macOS

<div align="center">

<img src="NetworkSelectorForMacOS\Assets.xcassets\AppIcon.appiconset\NetworkSelector_128.png" alt="NetProfile Switcher" width="128">

**基于 SwiftUI 的 macOS 网络配置预设切换工具<br/>在多个 IPv4 网络配置、DNS 与 DHCP 之间快速切换**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6-F05138)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS-0078D4)](https://developer.apple.com/swiftui/)

[English](README_EN.md) | **简体中文**

</div>

---

## 📖 简介

NetProfile Switcher for macOS 是一款面向 macOS 桌面的网络配置预设工具。它可以保存不同的网络配置（IPv4 地址、子网掩码、网关与 DNS），并在需要时一键切换到指定配置。

适合经常在直连网络、旁路网关、代理网关、实验室网络、公司与家庭网络之间切换的场景。你不需要反复进入 macOS 系统设置手动修改网络参数，只要维护好预设，点击即可应用。

## 🖼️ 界面预览

![NetProfile Switcher 界面预览](README/1.png)

## ✨ 功能特性

- **多配置管理**：保存配置名称、IPv4 地址、子网掩码、网关与 DNS 服务器。
- **快速切换预设**：在侧边栏选择配置后点击「应用」即可切换，也支持右键菜单快速应用。
- **一次授权免密执行**：首次切换网络参数时配置受限的 `sudoers` 规则，之后调用 `networksetup` 不再要求输入密码。
- **DHCP 快捷恢复**：可一键切回 DHCP 地址并清空自定义 DNS。
- **macOS 快捷指令集成**：暴露 `Apply Network Configuration` 与 `Switch Network Service to DHCP` 两个 App Intents，可在快捷指令中结合条件、时间、位置等自动化规则使用。

## 🚀 快速开始

### 系统要求

- macOS 26 (Tahoe) 或更高版本
- 可用的 Wi-Fi、Ethernet 或其他 macOS 网络服务

### 安装

#### 🛠️ 从 GitHub Releases 获取

从 [GitHub Releases](https://github.com/sixiaolong1117/NetProfile-Switcher-for-macOS/releases) 下载最新的 `.dmg` 安装包。

首次运行时若被 Gatekeeper 拦截，请先按文首的警告说明执行 `xattr` 命令。

#### 🛠️ 从源码构建

1. 克隆仓库：

```bash
git clone https://github.com/sixiaolong1117/NetProfile-Switcher-for-macOS.git
```

2. 使用 Xcode 26.5 或更高版本打开 `NetworkSelectorForMacOS.xcodeproj`。
3. 选择 `My Mac` 作为运行目标。
4. 点击 Run 或按 `⌘R` 构建并运行。

## 📖 使用指南

### ➕ 添加静态网络配置

1. 在工具栏点击 **＋** 按钮。
2. 填写配置名称，例如"旁路网关"或"公司网络"。
3. 填写 IPv4 地址、子网掩码、网关与 DNS 服务器。
4. 点击 **Save** 保存配置。

### 🔁 切换配置

| 操作 | 说明 |
|------|------|
| 选择配置 → 应用 | 选中配置后点击工具栏「应用」按钮立即将该静态网络配置应用到当前网络服务；也支持右键菜单快速切换 |
| DHCP 按钮 | 将当前网络服务切回 DHCP 地址并清空 DNS |
| 右侧当前网络信息面板 | 查看当前网络服务实际生效的 IP、子网掩码、网关与 DNS |

> 应用配置后，macOS 系统设置中的网络面板可能需要重新打开才能显示最新结果。

### ⚙️ 快捷指令自动化

应用提供了两个快捷指令动作，可在 macOS「快捷指令」App 中搜索使用：

| 动作 | 说明 |
|------|------|
| Apply Network Configuration | 将指定网络服务切换到已保存的静态 IP 配置 |
| Switch Network Service to DHCP | 将指定网络服务切换回 DHCP，并清空自定义 DNS |

你可以结合条件判断、时间触发、菜单选择等自动化规则，实现网络配置的自动切换。

## 🔒 隐私

NetProfile Switcher for macOS 不会收集、使用或分享个人信息。所有配置数据仅保存在本地 UserDefaults 中。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。

## 📄 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。
