# NetProfile Switcher

[English](README.en.md)

一个 macOS 网络配置切换器，可以在多个预设配置间快速切换。

## 功能

- 保存多个静态 IP 预设配置。
- 在预设配置和 DHCP 之间快速切换。
- 支持选择不同网络服务，例如 `Wi-Fi`、`Ethernet`。
- 支持配置 IP 地址、子网掩码、网关和 DNS 服务器。
- 支持 macOS 快捷指令，可在自动化流程中切换网络配置。

## 使用场景

- 在公司、家里、实验室等不同网络环境之间切换。
- 在 DHCP 和固定 IP 之间来回切换。
- 为路由器、交换机、嵌入式设备调试保存常用静态 IP 配置。
- 通过快捷指令按条件自动切换配置。

## 安装

从 GitHub Releases 下载最新的 `.dmg` 安装包，打开后将应用拖入 `Applications`。

首次运行时，macOS 可能会提示确认打开来自网络下载的应用。

## 使用方法

1. 打开应用。
2. 在右上角选择网络服务，例如 `Wi-Fi`。
3. 点击配置列表中的 `+` 添加配置。
4. 填写名称、IP 地址、子网掩码、网关和 DNS。
5. 选择一个配置后点击 `Apply` 应用。
6. 点击底部 `DHCP` 可将当前网络服务切回 DHCP。

切换网络配置需要调用 macOS 的 `networksetup`，执行时可能会弹出管理员权限确认。

## 快捷指令

应用暴露了两个快捷指令动作：

- `Apply Network Configuration`：将指定网络服务切换到已保存的静态 IP 配置。
- `Switch Network Service to DHCP`：将指定网络服务切换回 DHCP，并清空自定义 DNS。

可以在 macOS「快捷指令」中搜索应用名称或动作名称，然后结合条件、菜单、时间、位置等自动化规则使用。

## 开发

要求：

- macOS 26 或更新版本
- Xcode 26 或更新版本

构建：

```bash
xcodebuild build \
  -project NetworkSelectorForMacOS.xcodeproj \
  -scheme NetworkSelectorForMacOS \
  -configuration Debug \
  -destination "platform=macOS"
```

## 发布

项目包含 GitHub Actions：

- 分支 push：执行 Debug 构建校验。
- tag push：同步 `MARKETING_VERSION` 到 tag 版本，执行构建校验，构建 Release 产物，生成 `.dmg`，并上传到对应 GitHub Release。

发布示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

tag 格式支持：

- `1.2.3`
- `v1.2.3`

## 权限说明

应用通过 `/usr/sbin/networksetup` 修改 macOS 网络配置。由于这是系统网络设置，切换配置时可能需要管理员权限。

## License

本项目基于 [LICENSE](LICENSE) 文件中的条款开源。
