//
//  NetworkAutomation.swift
//  NetworkSelectorForMacOS
//  处理网络配置的自动化逻辑，包括执行系统命令和提供快捷指令支持
//

import AppIntents
import Foundation

enum NetworkAutomation {

    // 从 UserDefaults 中获取保存的网络配置文件列表
    static func storedProfiles() -> [NetworkProfile] {
        let storedProfiles = UserDefaults.standard.string(forKey: "networkProfiles") ?? "[]"

        guard let data = storedProfiles.data(using: .utf8),
              let decodedProfiles = try? JSONDecoder().decode([NetworkProfile].self, from: data) else {
            return []
        }

        return decodedProfiles
    }

    // 将指定的网络配置应用到指定的网络服务上，执行系统命令进行配置
    static func apply(profile: NetworkProfile, serviceName: String) async -> SudoersAccessResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ipAddress = profile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let subnetMask = profile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        let router = profile.router.trimmingCharacters(in: .whitespacesAndNewlines)
        // 将 DNS 服务器列表拆分成单个地址，支持逗号、空格、换行和制表符分隔
        let dnsServers = profile.dnsServers
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map(String.init)

        // 验证输入，确保网络服务名称和必要的静态 IP 配置字段不为空
        guard !service.isEmpty else {
            return SudoersAccessResult(success: false, message: appText("status.networkRequired", languageSetting: AppLanguage.system.rawValue))
        }

        // 对于静态 IP 配置，IP 地址、子网掩码和网关都是必填项
        guard !ipAddress.isEmpty, !subnetMask.isEmpty, !router.isEmpty else {
            return SudoersAccessResult(success: false, message: appText("status.staticFieldsRequired", languageSetting: AppLanguage.system.rawValue))
        }

        // 构建 networksetup 参数，设置静态 IP 和 DNS 服务器
        let commands = [
            ["-setmanual", service, ipAddress, subnetMask, router],
            ["-setdnsservers", service] + (dnsServers.isEmpty ? ["Empty"] : dnsServers)
        ]

        // 首次使用时安装 sudoers 授权，之后通过 sudo -n 免密执行。
        return await runAuthorizedCommands(commands)
    }

    // 将指定的网络服务切换到 DHCP 模式，并清除自定义 DNS 服务器设置
    static func switchToDHCP(serviceName: String) async -> SudoersAccessResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证输入，确保网络服务名称不为空
        guard !service.isEmpty else {
            return SudoersAccessResult(success: false, message: appText("status.networkRequired", languageSetting: AppLanguage.system.rawValue))
        }

        // 构建 networksetup 参数，切换到 DHCP 模式并清除 DNS 服务器设置
        let commands = [
            ["-setdhcp", service],
            ["-setdnsservers", service, "Empty"]
        ]

        // 优先通过特权助手免密执行，否则回退到管理员授权弹窗
        return await runAuthorizedCommands(commands)
    }

    // 执行一组 networksetup 命令：首次使用时一次性安装 sudoers 授权，失败时不回退到每次弹密码的 osascript。
    private static func runAuthorizedCommands(_ commands: [[String]]) async -> SudoersAccessResult {
        if let result = await SudoersAccessManager.execute(commands) {
            return SudoersAccessResult(success: result.success, message: result.message)
        }

        let installation = await SudoersAccessManager.install()
        guard installation.success else {
            return SudoersAccessResult(success: false, message: appText("status.sudoersInstallFailedDetail", languageSetting: AppLanguage.system.rawValue) + " " + installation.message)
        }

        guard let result = await SudoersAccessManager.execute(commands) else {
            return SudoersAccessResult(success: false, message: appText("status.sudoersUnavailable", languageSetting: AppLanguage.system.rawValue))
        }
        return SudoersAccessResult(success: result.success, message: result.message)
    }

    /// 获取当前网络服务的 IP、子网掩码、网关信息
    nonisolated static func getCurrentNetworkInfo(serviceName: String) -> NetworkInfoResult {
        // 清理输入，去除多余的空白字符
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 验证输入，确保网络服务名称不为空
        guard !service.isEmpty else {
            return .empty
        }

        // 构建系统命令，使用 networksetup 工具获取网络服务的配置信息
        let quotedService = shellQuoted(service)

        // 获取 IP/子网掩码/网关
        let infoCommand = "/usr/sbin/networksetup -getinfo \(quotedService)"
        let infoOutput = runCommand(command: infoCommand)

        // 获取 DNS
        let dnsCommand = "/usr/sbin/networksetup -getdnsservers \(quotedService)"
        let dnsOutput = runCommand(command: dnsCommand)

        // 解析命令输出并返回结构化的网络信息结果
        return parseNetworkInfo(infoOutput: infoOutput, dnsOutput: dnsOutput)
    }

    // 获取网络信息，并在信息为空时异步重试（DHCP 切换后网卡获取租约需要几秒）
    nonisolated static func getCurrentNetworkInfoPolling(serviceName: String) async -> NetworkInfoResult {
        var info = getCurrentNetworkInfo(serviceName: serviceName)
        var attempts = 0
        while info.isEmpty && attempts < 10 {
            try? await Task.sleep(for: .seconds(0.5))
            info = getCurrentNetworkInfo(serviceName: serviceName)
            attempts += 1
        }
        return info
    }

    // 执行系统命令并返回输出结果
    nonisolated private static func runCommand(command: String) -> String {
        // 构建并运行系统命令，捕获标准输出和错误输出
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // 使用 zsh 作为执行环境，以支持更复杂的命令语法和环境变量
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 执行命令并返回输出结果，如果执行失败则返回错误信息
        do {
            try process.run()
            process.waitUntilExit()
            return readText(from: outputPipe)
        } catch {
            return ""
        }
    }

    // 解析 networksetup 命令的输出，提取 IP 地址、子网掩码、网关和 DNS 服务器信息
    nonisolated private static func parseNetworkInfo(infoOutput: String, dnsOutput: String) -> NetworkInfoResult {
        // 初始化变量来存储解析结果
        var ipAddress = ""
        var subnetMask = ""
        var router = ""

        // 解析 getinfo 输出
        let lines = infoOutput.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("IP address:") {
                ipAddress = String(trimmed.dropFirst("IP address:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Subnet mask:") {
                subnetMask = String(trimmed.dropFirst("Subnet mask:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if trimmed.hasPrefix("Router:") {
                router = String(trimmed.dropFirst("Router:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 解析 getinfo 首行，判断是否为 DHCP 配置
        let isDHCP = lines
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "DHCP Configuration"

        // 解析 DNS 输出
        var dnsServers: [String] = []
        let dnsLines = dnsOutput.components(separatedBy: .newlines)
        for line in dnsLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("There aren't any DNS Servers set on") {
                dnsServers.append(trimmed)
            }
        }

        // 返回解析结果
        return NetworkInfoResult(
            ipAddress: ipAddress,
            subnetMask: subnetMask,
            router: router,
            dnsServers: dnsServers,
            isDHCP: isDHCP
        )
    }

    // 返回与当前网络信息完全一致的配置文件（四项全等）；DHCP 或不完整的配置不参与匹配
    static func matchingProfile(for info: NetworkInfoResult, profiles: [NetworkProfile]) -> NetworkProfile? {
        guard !info.isEmpty, !info.isDHCP else { return nil }

        return profiles.first { profile in
            let ip = profile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let subnet = profile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
            let router = profile.router.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ip.isEmpty, !subnet.isEmpty, !router.isEmpty else { return false }

            return ip.caseInsensitiveCompare(info.ipAddress) == .orderedSame
                && subnet.caseInsensitiveCompare(info.subnetMask) == .orderedSame
                && router.caseInsensitiveCompare(info.router) == .orderedSame
                && dnsSet(profile.dnsServers) == dnsSet(info.dnsServers.joined(separator: " "))
        }
    }

    // 将 DNS 字符串解析为集合（逗号/空格/换行/制表符分隔，忽略空项，大小写不敏感），用于顺序无关比较
    nonisolated private static func dnsSet(_ value: String) -> Set<String> {
        Set(value
            .split { $0 == "," || $0 == " " || $0 == "\n" || $0 == "\t" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
    }

    // 当前配置的显示文案：DHCP 显示 DHCP；命中的配置显示配置名；否则提示未匹配
    static func currentProfileLabel(for info: NetworkInfoResult, profiles: [NetworkProfile], languageSetting: String) -> String {
        if info.isEmpty { return "—" }
        if info.isDHCP { return appText("action.dhcp", languageSetting: languageSetting) }
        if let profile = matchingProfile(for: info, profiles: profiles) {
            return profile.name.isEmpty ? appText("configuration.untitled", languageSetting: languageSetting) : profile.name
        }
        return appText("status.currentProfileNone", languageSetting: languageSetting)
    }

    nonisolated static func readText(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

// 网络信息结构体
struct NetworkInfoResult {
    static let empty = NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [], isDHCP: false)

    let ipAddress: String
    let subnetMask: String
    let router: String
    let dnsServers: [String]
    let isDHCP: Bool

    var dnsServersString: String {
        dnsServers.joined(separator: ", ")
    }

    var isEmpty: Bool {
        ipAddress.isEmpty && subnetMask.isEmpty && router.isEmpty && dnsServers.isEmpty
    }
}

// 网络配置实体
struct NetworkProfileEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Network Configuration")
    static let defaultQuery = NetworkProfileEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name.isEmpty ? appText("configuration.untitled", languageSetting: AppLanguage.system.rawValue) : name)")
    }
}

// 网络配置实体查询，提供快捷指令中网络配置的查询和建议功能
struct NetworkProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [NetworkProfileEntity.ID]) async throws -> [NetworkProfileEntity] {
        NetworkAutomation.storedProfiles()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { NetworkProfileEntity(profile: $0) }
    }

    func suggestedEntities() async throws -> [NetworkProfileEntity] {
        NetworkAutomation.storedProfiles().map { NetworkProfileEntity(profile: $0) }
    }

    func defaultResult() async -> NetworkProfileEntity? {
        NetworkAutomation.storedProfiles().first.map { NetworkProfileEntity(profile: $0) }
    }
}

// 关于页面，展示应用信息和作者信息
extension NetworkProfileEntity {
    init(profile: NetworkProfile) {
        id = profile.id.uuidString
        name = profile.name
    }
}

// 快捷指令：应用网络配置到指定网络服务
struct ApplyNetworkConfigurationIntent: AppIntent {
    // 快捷指令标题和描述，定义在快捷指令库中显示的名称和说明
    static let title: LocalizedStringResource = "Apply Network Configuration"
    static let description = IntentDescription("Switches a network service to one of the saved static IP configurations.")
    static let openAppWhenRun = false

    // 快捷指令参数，用户在快捷指令中选择要应用的网络配置和目标网络服务
    @Parameter(title: "Configuration")
    var configuration: NetworkProfileEntity

    // 快捷指令参数，用户选择要应用配置的网络服务，默认为 "Wi-Fi"
    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    // 快捷指令执行逻辑
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 从存储的网络配置文件中查找与用户选择的配置 ID 匹配的配置文件
        guard let profile = NetworkAutomation.storedProfiles().first(where: { $0.id.uuidString == configuration.id }) else {
            return .result(dialog: "\(appText("intent.dialog.chooseConfiguration", languageSetting: AppLanguage.system.rawValue))")
        }

        // 将选中的网络配置应用到指定的网络服务上，并根据结果返回相应的对话框提示用户操作结果
        let result = await NetworkAutomation.apply(profile: profile, serviceName: serviceName)

        // 根据执行结果返回不同的对话框提示，成功时显示应用成功的消息，失败时显示错误信息
        if result.success {
            let displayName = profile.name.isEmpty ? appText("status.defaultConfiguration", languageSetting: AppLanguage.system.rawValue) : profile.name
            return .result(dialog: "\(appText("intent.dialog.appliedToService", languageSetting: AppLanguage.system.rawValue, displayName, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

// 快捷指令：将指定网络服务切换到 DHCP 模式，并清除自定义 DNS 服务器设置
struct SwitchNetworkServiceToDHCPIntent: AppIntent {
    // 快捷指令标题和描述，定义在快捷指令库中显示的名称和说明
    static let title: LocalizedStringResource = "Switch Network Service to DHCP"
    static let description = IntentDescription("Switches a network service to DHCP and clears custom DNS servers.")
    static let openAppWhenRun = false

    // 快捷指令参数，用户选择要切换的网络服务，默认为 "Wi-Fi"
    @Parameter(title: "Network Service", default: "Wi-Fi")
    var serviceName: String

    init() {}

    // 快捷指令执行逻辑
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await NetworkAutomation.switchToDHCP(serviceName: serviceName)

        // 根据执行结果返回不同的对话框提示，成功时显示切换成功的消息，失败时显示错误信息
        if result.success {
            return .result(dialog: "\(appText("status.dhcpComplete", languageSetting: AppLanguage.system.rawValue, serviceName))")
        } else {
            return .result(dialog: "\(appText("status.applyFailed", languageSetting: AppLanguage.system.rawValue, result.message))")
        }
    }
}

// 快捷指令提供者，注册应用支持的快捷指令
struct NetworkSelectorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApplyNetworkConfigurationIntent(),
            phrases: [
                "Apply network configuration with \(.applicationName)",
                "Switch network profile with \(.applicationName)"
            ],
            shortTitle: "Apply Configuration",
            systemImageName: "network"
        )

        AppShortcut(
            intent: SwitchNetworkServiceToDHCPIntent(),
            phrases: [
                "Switch to DHCP with \(.applicationName)",
                "Reset network service with \(.applicationName)"
            ],
            shortTitle: "Switch to DHCP",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
