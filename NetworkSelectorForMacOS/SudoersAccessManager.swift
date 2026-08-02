//
//  SudoersAccessManager.swift
//  NetProfile Switcher
//

import Foundation

struct SudoersAccessResult {
    let success: Bool
    let message: String
}

enum SudoersAccessManager {
    private static let directoryPath = "/Library/NetProfileSwitcher"
    private static let wrapperPath = "/Library/NetProfileSwitcher/networksetup-wrapper"
    private static let sudoersPath = "/etc/sudoers.d/netprofile-switcher"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: wrapperPath)
            && FileManager.default.fileExists(atPath: sudoersPath)
    }

    static func execute(_ commands: [[String]]) async -> SudoersAccessResult? {
        guard isInstalled else {
            return nil
        }

        for arguments in commands {
            let result = await runProcess("/usr/bin/sudo", arguments: ["-n", wrapperPath] + arguments)
            guard result.success else {
                return result
            }
        }
        return SudoersAccessResult(success: true, message: "")
    }

    static func install() async -> SudoersAccessResult {
        guard let username = validatedUsername() else {
            return SudoersAccessResult(success: false, message: "Unable to determine the current user.")
        }

        let wrapper = Data(wrapperScript.utf8).base64EncodedString()
        let sudoers = Data("\(username) ALL=(root) NOPASSWD: \(wrapperPath)\n".utf8).base64EncodedString()
        let command = """
        set -e
        umask 077
        /usr/bin/install -d -o root -g wheel -m 755 '\(directoryPath)'
        wrapper_temp=$(/usr/bin/mktemp '\(directoryPath)/.networksetup-wrapper.XXXXXX')
        sudoers_temp=$(/usr/bin/mktemp '/etc/sudoers.d/.netprofile-switcher.XXXXXX')
        trap '/bin/rm -f "$wrapper_temp" "$sudoers_temp"' EXIT
        /usr/bin/printf '%s' '\(wrapper)' | /usr/bin/base64 -D > "$wrapper_temp"
        /usr/bin/printf '%s' '\(sudoers)' | /usr/bin/base64 -D > "$sudoers_temp"
        /usr/sbin/visudo -cf "$sudoers_temp"
        /usr/bin/install -o root -g wheel -m 755 "$wrapper_temp" '\(wrapperPath)'
        /usr/bin/install -o root -g wheel -m 440 "$sudoers_temp" '\(sudoersPath)'
        """
        return await runElevated(command)
    }

    static func remove() async -> SudoersAccessResult {
        let command = """
        set -e
        /bin/rm -f '\(sudoersPath)' '\(wrapperPath)'
        /bin/rmdir '\(directoryPath)' 2>/dev/null || true
        """
        return await runElevated(command)
    }

    private static let wrapperScript = """
    #!/bin/sh
    set -eu

    [ "$#" -ge 1 ] || exit 64
    command="$1"
    shift

    case "$command" in
        -setmanual)
            [ "$#" -eq 4 ] || exit 64
            ;;
        -setdhcp)
            [ "$#" -eq 1 ] || exit 64
            ;;
        -setdnsservers)
            [ "$#" -ge 2 ] || exit 64
            ;;
        *)
            exit 64
            ;;
    esac

    for argument in "$@"; do
        [ -n "$argument" ] || exit 64
    done

    exec /usr/sbin/networksetup "$command" "$@"
    """

    private static func validatedUsername() -> String? {
        let username = NSUserName()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return !username.isEmpty && username.unicodeScalars.allSatisfy(allowed.contains) ? username : nil
    }

    private static func runElevated(_ command: String) async -> SudoersAccessResult {
        let script = """
        on run argv
            do shell script (item 1 of argv) with administrator privileges
        end run
        """
        return await runProcess("/usr/bin/osascript", arguments: ["-e", script, command])
    }

    private static func runProcess(_ executable: String, arguments: [String]) async -> SudoersAccessResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let output = readText(from: outputPipe)
                    let error = readText(from: errorPipe)
                    continuation.resume(returning: SudoersAccessResult(
                        success: process.terminationStatus == 0,
                        message: error.isEmpty ? output : error
                    ))
                } catch {
                    continuation.resume(returning: SudoersAccessResult(success: false, message: error.localizedDescription))
                }
            }
        }
    }

    private static func readText(from pipe: Pipe) -> String {
        String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
