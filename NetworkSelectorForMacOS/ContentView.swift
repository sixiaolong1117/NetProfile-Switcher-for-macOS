//
//  ContentView.swift
//  NetworkSelectorForMacOS
//  主界面、交互逻辑
//

import SwiftUI

// 网络配置文件数据模型
struct NetworkProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServers: String

    // 创建一个空白配置文件的工厂方法，方便在添加新配置时使用
    static func blank(named name: String) -> NetworkProfile {
        NetworkProfile(
            name: name,
            ipAddress: "",
            subnetMask: "255.255.0.0",
            router: "",
            dnsServers: ""
        )
    }
}

// 当前网络信息数据模型
struct NetworkService: Identifiable, Equatable {
    let name: String
    let isDisabled: Bool    // 是否被禁用（在 networksetup 的输出中以 * 开头表示被禁用）

    var id: String {
        name
    }

    var displayName: String {
        isDisabled ? "\(name) (Disabled)" : name
    }
}

struct ContentView: View {
    // 使用 AppStorage 来持久化用户设置和数据，简化状态管理
    @AppStorage("networkServiceName") private var serviceName = "Wi-Fi"     // 默认选择 Wi-Fi，可以根据需要调整
    @AppStorage("networkProfiles") private var storedProfiles = "[]"        // 存储配置文件的 JSON 字符串
    @AppStorage("showDisabledNetworkServices") private var showDisabledNetworkServices = true           // 是否显示被禁用的网络服务
    @AppStorage("refreshNetworkServicesOnLaunch") private var refreshNetworkServicesOnLaunch = true     // 是否在应用启动时刷新网络服务列表
    @AppStorage("defaultSubnetMask") private var defaultSubnetMask = "255.255.0.0"      // 添加默认子网掩码设置
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue    // 应用默认语言设置

    @State private var networkServices: [NetworkService] = []           // 当前可用的网络服务列表
    @State private var profiles: [NetworkProfile] = []                  // 当前保存的网络配置文件列表
    @State private var selectedProfileID: NetworkProfile.ID?            // 当前选中的配置文件 ID
    @State private var draftProfile = NetworkProfile.blank(named: "")   // 用于编辑时的临时配置文件数据
    @State private var editingProfileID: NetworkProfile.ID?             // 当前正在编辑的配置文件 ID，nil 表示正在创建新配置
    @State private var isEditorPresented = false        // 是否显示配置编辑界面
    @State private var isLoadingServices = false        // 是否正在加载网络服务列表
    @State private var statusMessage = ""               // 用于显示操作状态和错误信息
    @State private var isSwitching = false              // 是否正在切换网络配置，控制界面交互状态
    @State private var currentNetworkInfo = NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: []) // 当前网络信息
    @State private var isLoadingInfo = false            // 是否正在加载当前网络信息

    // 主界面布局
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .backgroundExtensionEffect()

            VStack(spacing: 12) {
                header

                HStack(spacing: 12) {
                    profileList
                        .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

                    profileDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .padding(12)
        }
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            loadProfiles()
            if refreshNetworkServicesOnLaunch {
                loadNetworkServices()
            }
            refreshCurrentNetworkInfo()
        }
        .onChange(of: serviceName) { _, _ in
            refreshCurrentNetworkInfo()
        }
        .onChange(of: showDisabledNetworkServices) {
            if !visibleNetworkServices.contains(where: { $0.name == serviceName }) {
                serviceName = visibleNetworkServices.first?.name ?? serviceName
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            NetworkProfileEditor(
                title: editingProfileID == nil
                    ? text("configuration.new")
                    : text("configuration.edit"),
                profile: $draftProfile,
                languageSetting: appLanguage,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveDraftProfile()
                }
            )
        }
    }

    // 头部区域
    var header: some View {
        HStack {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(text("title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(text("subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(text("network.label"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(text("network.label"), selection: $serviceName) {
                if visibleNetworkServices.isEmpty {
                    Text(serviceName.isEmpty ? text("network.noServices") : serviceName)
                        .tag(serviceName)
                } else {
                    ForEach(visibleNetworkServices) { service in
                        Text(service.displayName)
                            .tag(service.name)
                    }
                }
            }
            .labelsHidden()
            .frame(minWidth: 150, idealWidth: 180)
            .disabled(isLoadingServices || visibleNetworkServices.isEmpty)

            Button {
                loadNetworkServices()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .disabled(isLoadingServices)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 20)
    }

    // 配置文件列表区域
    var profileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(text("configuration.title"))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    addProfile()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if profiles.isEmpty {
                emptyList
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contextMenu {
                        Button(text("configuration.add")) {
                            addProfile()
                        }
                    }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(profiles) { profile in
                            profileRow(profile)
                                .contextMenu {
                                    Button(text("configuration.edit")) {
                                        editProfile(profile)
                                    }

                                    Button(text("configuration.duplicate")) {
                                        duplicateProfile(profile)
                                    }

                                    Divider()

                                    Button(text("configuration.delete"), role: .destructive) {
                                        deleteProfile(profile)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .contextMenu {
                    Button(text("configuration.add")) {
                        addProfile()
                    }
                }
            }
        }
        .glassPanel(cornerRadius: 20)
    }

    // 空列表占位视图
    var emptyList: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)

            Text(text("configuration.empty"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // 配置文件行视图
    func profileRow(_ profile: NetworkProfile) -> some View {
        Button {
            selectedProfileID = profile.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(profile.id == selectedProfileID ? .white : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name.isEmpty ? text("configuration.untitled") : profile.name)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(profile.ipAddress.isEmpty ? text("configuration.noIP") : profile.ipAddress)
                        .font(.caption)
                        .foregroundStyle(profile.id == selectedProfileID ? .white.opacity(0.75) : .secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .background {
                if profile.id == selectedProfileID {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.tint)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.clear)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // 配置文件详情区域
    var profileDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedProfile {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedProfile.name.isEmpty ? text("configuration.untitled") : selectedProfile.name)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(text("configuration.static"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack {
                        Button {
                            applySelectedProfile()
                        } label: {
                            Label(text("action.apply"), systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.return)
                        .disabled(isSwitching)

                        Button {
                            editProfile(selectedProfile)
                        } label: {
                            Label(text("action.edit"), systemImage: "pencil")
                        }
                        .buttonStyle(.glass)
                        .disabled(isSwitching)
                    }
                }

                LazyVGrid(columns: detailColumns, spacing: 12) {
                    detailTile(text("editor.ip"), selectedProfile.ipAddress, "number")
                    detailTile(text("editor.subnet"), selectedProfile.subnetMask, "rectangle.3.group")
                    detailTile(text("editor.router"), selectedProfile.router, "point.3.connected.trianglepath.dotted")
                    detailTile(text("editor.dns"), selectedProfile.dnsServers, "server.rack")
                }

                Spacer()
            } else {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)

                    Text(text("configuration.noneSelected"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .padding(18)
        .glassPanel(cornerRadius: 22)
    }

    // 配置文件详情的网格布局
    var detailColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)
        ]
    }

    // 配置文件详情的单元格视图
    func detailTile(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value.isEmpty ? "-" : value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minHeight: 78, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    // 底部区域
    var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    switchToDHCP()
                } label: {
                    Label(text("action.dhcp"), systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.glass)
                .disabled(isSwitching)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // 当前网络信息面板
            currentNetworkInfoView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassPanel(cornerRadius: 18)
    }

    // 当前网络信息面板
    var currentNetworkInfoView: some View {
        HStack(spacing: 0) {
            Label(text("status.currentInfo"), systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 12)

            if isLoadingInfo {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else if currentNetworkInfo.isEmpty {
                Text(text("status.noInfo"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 16) {
                    infoBadge(text("status.currentIP"), currentNetworkInfo.ipAddress, "number")
                    infoBadge(text("status.currentSubnet"), currentNetworkInfo.subnetMask, "rectangle.3.group")
                    infoBadge(text("status.currentRouter"), currentNetworkInfo.router, "point.3.connected.trianglepath.dotted")
                    infoBadge(text("status.currentDNS"), currentNetworkInfo.dnsServersString, "server.rack")
                }
            }

            Spacer(minLength: 8)

            Button {
                refreshCurrentNetworkInfo()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(text("status.refreshInfo"))
            .disabled(isLoadingInfo)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    // 当前网络信息面板中的信息徽章视图
    func infoBadge(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(value.isEmpty ? "-" : value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    // 计算属性，获取当前选中的配置文件对象，方便在界面中显示详细信息和进行编辑操作
    var selectedProfile: NetworkProfile? {
        guard let selectedProfileID else {
            return nil
        }

        return profiles.first { $0.id == selectedProfileID }
    }

    // 文本本地化函数
    func text(_ key: String) -> String {
        appText(key, languageSetting: appLanguage)
    }

    // 计算属性，根据用户设置决定是否显示被禁用的网络服务，确保用户可以根据需要选择合适的网络接口进行配置
    var visibleNetworkServices: [NetworkService] {
        showDisabledNetworkServices
            ? networkServices
            : networkServices.filter { !$0.isDisabled }
    }

    // 添加新配置文件的函数
    func addProfile() {
        draftProfile = NetworkProfile.blank(named: nextProfileName())
        draftProfile.subnetMask = defaultSubnetMask.trimmingCharacters(in: .whitespacesAndNewlines)
        editingProfileID = nil
        isEditorPresented = true
    }

    // 编辑现有配置文件的函数
    func editProfile(_ profile: NetworkProfile) {
        draftProfile = profile
        editingProfileID = profile.id
        isEditorPresented = true
    }

    // 保存配置文件的函数
    func saveDraftProfile() {
        let normalizedProfile = NetworkProfile(
            id: draftProfile.id,
            name: draftProfile.name.trimmingCharacters(in: .whitespacesAndNewlines),
            ipAddress: draftProfile.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subnetMask: draftProfile.subnetMask.trimmingCharacters(in: .whitespacesAndNewlines),
            router: draftProfile.router.trimmingCharacters(in: .whitespacesAndNewlines),
            dnsServers: draftProfile.dnsServers.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let editingProfileID,
           let index = profiles.firstIndex(where: { $0.id == editingProfileID }) {
            profiles[index] = normalizedProfile
        } else {
            profiles.append(normalizedProfile)
        }

        selectedProfileID = normalizedProfile.id
        saveProfiles()
        isEditorPresented = false
    }

    // 复制配置文件的函数
    func duplicateProfile(_ profile: NetworkProfile) {
        var copy = profile
        copy.id = UUID()
        copy.name = profile.name.isEmpty
            ? text("configuration.copyUntitled")
            : appText("configuration.copyName", languageSetting: appLanguage, profile.name)
        profiles.append(copy)
        selectedProfileID = copy.id
        saveProfiles()
    }

    // 删除配置文件的函数
    func deleteProfile(_ profile: NetworkProfile) {
        profiles.removeAll { $0.id == profile.id }

        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }

        saveProfiles()
    }

    // 切换到 DHCP 的函数
    func switchToDHCP() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !service.isEmpty else {
            statusMessage = text("status.networkRequired")
            return
        }

        isSwitching = true
        statusMessage = appText("status.dhcpSwitching", languageSetting: appLanguage, service)

        Task { @MainActor in
            let result = await NetworkAutomation.switchToDHCP(serviceName: service)
            isSwitching = false
            statusMessage = result.success
                ? appText("status.dhcpComplete", languageSetting: appLanguage, service)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
            if result.success {
                refreshCurrentNetworkInfo()
            }
        }
    }

    // 应用选中配置文件的函数
    func applySelectedProfile() {
        guard let profile = selectedProfile else {
            statusMessage = text("status.profileRequired")
            return
        }

        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? text("status.defaultConfiguration") : name

        isSwitching = true
        statusMessage = appText("status.applying", languageSetting: appLanguage, displayName)

        Task { @MainActor in
            let result = await NetworkAutomation.apply(profile: profile, serviceName: serviceName)
            isSwitching = false
            statusMessage = result.success
                ? appText("status.applied", languageSetting: appLanguage, displayName)
                : appText("status.applyFailed", languageSetting: appLanguage, result.message)
            if result.success {
                refreshCurrentNetworkInfo()
            }
        }
    }

    // 加载配置文件的函数
    func loadProfiles() {
        profiles = NetworkAutomation.storedProfiles()
        selectedProfileID = profiles.first?.id
    }

    // 保存配置文件的函数
    func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles),
              let encodedProfiles = String(data: data, encoding: .utf8) else {
            return
        }

        storedProfiles = encodedProfiles
    }

    // 加载网络服务列表的函数
    func loadNetworkServices() {
        isLoadingServices = true

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            process.arguments = ["-listallnetworkservices"]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let output = NetworkAutomation.readText(from: outputPipe)
                let error = NetworkAutomation.readText(from: errorPipe)
                let services = parseNetworkServices(output)

                DispatchQueue.main.async {
                    networkServices = services
                    isLoadingServices = false

                    if !visibleNetworkServices.contains(where: { $0.name == serviceName }) {
                        serviceName = visibleNetworkServices.first?.name ?? serviceName
                    }

                    if process.terminationStatus != 0 {
                        statusMessage = error.isEmpty ? text("status.loadServicesFailed") : error
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isLoadingServices = false
                    statusMessage = appText("status.loadServicesFailedDetail", languageSetting: appLanguage, error.localizedDescription)
                }
            }
        }
    }

    // 解析 networksetup -listallnetworkservices 命令输出的函数，提取网络服务名称和禁用状态，构建 NetworkService 对象列表供界面显示和选择
    func parseNetworkServices(_ output: String) -> [NetworkService] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                !line.isEmpty && !line.hasPrefix("An asterisk")
            }
            .map { line in
                let isDisabled = line.hasPrefix("*")
                let name = isDisabled
                    ? String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                    : line

                return NetworkService(name: name, isDisabled: isDisabled)
            }
            .filter { !$0.name.isEmpty }
    }

    // 生成下一个默认配置文件名称的函数，确保新添加的配置文件有一个合理的默认名称，提升用户体验
    func nextProfileName() -> String {
        appText("configuration.nextName", languageSetting: appLanguage, profiles.count + 1)
    }

    // 刷新当前网络信息的函数
    func refreshCurrentNetworkInfo() {
        let service = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !service.isEmpty else {
            currentNetworkInfo = NetworkInfoResult(ipAddress: "", subnetMask: "", router: "", dnsServers: [])
            return
        }

        isLoadingInfo = true

        DispatchQueue.global(qos: .userInitiated).async {
            let info = NetworkAutomation.getCurrentNetworkInfo(serviceName: service)

            DispatchQueue.main.async {
                currentNetworkInfo = info
                isLoadingInfo = false
            }
        }
    }
}

// 配置文件编辑界面
struct NetworkProfileEditor: View {
    let title: String
    @Binding var profile: NetworkProfile
    let languageSetting: String
    let onCancel: () -> Void
    let onSave: () -> Void

    // 编辑界面布局
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(20)

            Divider()

            Form {
                TextField(text("editor.name"), text: $profile.name)
                TextField(text("editor.ip"), text: $profile.ipAddress)
                TextField(text("editor.subnet"), text: $profile.subnetMask)
                TextField(text("editor.router"), text: $profile.router)
                TextField(text("editor.dns"), text: $profile.dnsServers)
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            HStack {
                Spacer()

                Button(text("action.cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(text("action.save")) {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460)
    }

    func text(_ key: String) -> String {
        appText(key, languageSetting: languageSetting)
    }
}

// 视图扩展，添加玻璃面板效果，提升界面美观度和层次感
private extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    ContentView()
}
