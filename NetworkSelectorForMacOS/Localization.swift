//
//  Localization.swift
//  NetworkSelectorForMacOS
//  本地化
//
//  Created by 司晓龙 on 2026/5/13.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String {
        rawValue
    }

    var languageCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }
}

func appText(_ key: String, languageSetting: String) -> String {
    let language = AppLanguage(rawValue: languageSetting) ?? .system

    guard language.languageCode == "zh-Hans" else {
        return englishText[key] ?? key
    }

    return simplifiedChineseText[key] ?? englishText[key] ?? key
}

func appText(_ key: String, languageSetting: String, _ arguments: CVarArg...) -> String {
    String(format: appText(key, languageSetting: languageSetting), arguments: arguments)
}

private let englishText: [String: String] = [
    "about.author": "Author",
    "about.description": "A macOS network configuration switcher for quickly switching between multiple preset configurations.",
    "about.license": "许可证",
    "about.repository": "仓库",
    "about.title": "About NetProfile Switcher",
    "about.version": "Version %@",
    "action.apply": "Apply",
    "action.cancel": "Cancel",
    "action.dhcp": "DHCP",
    "action.edit": "Edit",
    "action.save": "Save",
    "configuration.add": "Add Configuration",
    "configuration.copyName": "%@ Copy",
    "configuration.copyUntitled": "Untitled Copy",
    "configuration.delete": "Delete Configuration",
    "configuration.duplicate": "Duplicate Configuration",
    "configuration.edit": "Edit Configuration",
    "configuration.empty": "No Configurations",
    "configuration.new": "New Configuration",
    "configuration.nextName": "Configuration %d",
    "configuration.noIP": "No IP address",
    "configuration.noneSelected": "No Configuration Selected",
    "configuration.static": "Static IP configuration",
    "configuration.title": "Configurations",
    "configuration.untitled": "Untitled",
    "editor.dns": "DNS Servers",
    "editor.ip": "IP Address",
    "editor.name": "Name",
    "editor.router": "Router",
    "editor.subnet": "Subnet Mask",
    "intent.dialog.appliedToService": "Applied %@ to %@.",
    "intent.dialog.chooseConfiguration": "Choose a saved configuration.",
    "language.english": "English",
    "language.simplifiedChinese": "Simplified Chinese",
    "language.system": "System",
    "network.label": "Network",
    "network.noServices": "No Services",
    "settings.defaultSubnet": "Default subnet mask",
    "settings.language": "Application Language",
    "settings.languageSection": "Language",
    "settings.newConfigurations": "New Configurations",
    "settings.networkServices": "Network Services",
    "settings.refreshOnLaunch": "Refresh service list on launch",
    "settings.showDisabled": "Show disabled network services",
    "status.applied": "Applied %@.",
    "status.applyFailed": "Failed: %@",
    "status.applying": "Applying %@...",
    "status.commandExited": "Command exited with code %d.",
    "status.defaultConfiguration": "selected configuration",
    "status.dhcpComplete": "%@ is now using DHCP.",
    "status.dhcpSwitching": "Switching %@ to DHCP...",
    "status.loadServicesFailed": "Failed to load network services.",
    "status.loadServicesFailedDetail": "Failed to load network services: %@",
    "status.networkRequired": "Network service name is required.",
    "status.profileRequired": "Select a configuration first.",
    "status.staticFieldsRequired": "IP address, subnet mask, and router are required.",
    "status.currentInfo": "Current Network Info",
    "status.currentIP": "Current IP",
    "status.currentSubnet": "Current Subnet Mask",
    "status.currentRouter": "Current Gateway",
    "status.currentDNS": "Current DNS",
    "status.refreshInfo": "Refresh",
    "status.noInfo": "Unable to retrieve network information",
    "subtitle": "Static profiles and DHCP for local network services",
    "title": "NetProfile Switcher"
]

private let simplifiedChineseText: [String: String] = [
    "about.author": "作者",
    "about.description": "一个 macOS 网络配置切换器，可以在多个预设配置间快速切换。",
    "about.license": "License",
    "about.repository": "Repo",
    "about.title": "关于 NetProfile Switcher",
    "about.version": "版本 %@",
    "action.apply": "应用",
    "action.cancel": "取消",
    "action.dhcp": "DHCP",
    "action.edit": "编辑",
    "action.save": "保存",
    "configuration.add": "添加配置",
    "configuration.copyName": "%@ 副本",
    "configuration.copyUntitled": "未命名副本",
    "configuration.delete": "删除配置",
    "configuration.duplicate": "复制配置",
    "configuration.edit": "编辑配置",
    "configuration.empty": "暂无配置",
    "configuration.new": "新建配置",
    "configuration.nextName": "配置 %d",
    "configuration.noIP": "未设置 IP 地址",
    "configuration.noneSelected": "未选择配置",
    "configuration.static": "静态 IP 配置",
    "configuration.title": "配置列表",
    "configuration.untitled": "未命名",
    "editor.dns": "DNS 服务器",
    "editor.ip": "IP 地址",
    "editor.name": "名称",
    "editor.router": "网关",
    "editor.subnet": "子网掩码",
    "intent.dialog.appliedToService": "已将 %@ 应用到 %@。",
    "intent.dialog.chooseConfiguration": "请选择一个已保存的配置。",
    "language.english": "英语",
    "language.simplifiedChinese": "简体中文",
    "language.system": "跟随系统",
    "network.label": "网络",
    "network.noServices": "无网络服务",
    "settings.defaultSubnet": "默认子网掩码",
    "settings.language": "应用语言",
    "settings.languageSection": "语言",
    "settings.newConfigurations": "新建配置",
    "settings.networkServices": "网络服务",
    "settings.refreshOnLaunch": "启动时刷新服务列表",
    "settings.showDisabled": "显示已禁用的网络服务",
    "status.applied": "已应用 %@。",
    "status.applyFailed": "失败：%@",
    "status.applying": "正在应用 %@...",
    "status.commandExited": "命令退出，代码 %d。",
    "status.defaultConfiguration": "所选配置",
    "status.dhcpComplete": "%@ 已切换为 DHCP。",
    "status.dhcpSwitching": "正在将 %@ 切换到 DHCP...",
    "status.loadServicesFailed": "加载网络服务失败。",
    "status.loadServicesFailedDetail": "加载网络服务失败：%@",
    "status.networkRequired": "需要网络服务名称。",
    "status.profileRequired": "请先选择一个配置。",
    "status.staticFieldsRequired": "IP 地址、子网掩码和网关不能为空。",
    "status.currentInfo": "当前网络信息",
    "status.currentIP": "当前 IP",
    "status.currentSubnet": "当前子网掩码",
    "status.currentRouter": "当前网关",
    "status.currentDNS": "当前 DNS",
    "status.refreshInfo": "刷新",
    "status.noInfo": "无法获取网络信息",
    "subtitle": "为本机网络服务切换静态配置和 DHCP",
    "title": "NetProfile Switcher"
]
