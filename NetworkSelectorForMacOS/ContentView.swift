//
//  ContentView.swift
//  NetworkSelectorForMacOS
//
//  Created by 司晓龙 on 2026/5/13.
//

import SwiftUI

struct ContentView: View {
    @State private var statusMessage = ""
    @State private var isSwitching = false

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Network Switcher")

            Button("Switch to DHCP") {
                switchToDHCP()
            }
            .disabled(isSwitching)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    func switchToDHCP() {
        isSwitching = true
        statusMessage = "Switching Wi-Fi to DHCP..."

        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            do shell script "/usr/sbin/networksetup -setdhcp Wi-Fi" with administrator privileges
            """

            let process = Process()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                DispatchQueue.main.async {
                    isSwitching = false
                    statusMessage = process.terminationStatus == 0
                        ? "Wi-Fi is now using DHCP."
                        : "Failed: \(errorMessage ?? "networksetup exited with code \(process.terminationStatus)")"
                }
            } catch {
                DispatchQueue.main.async {
                    isSwitching = false
                    statusMessage = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }

}

#Preview {
    ContentView()
}
