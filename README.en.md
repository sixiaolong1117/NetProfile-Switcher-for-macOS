# Network Switcher

[简体中文](README.md)

Network Switcher is a macOS network configuration switcher for quickly switching between multiple preset configurations.

## Features

- Save multiple static IP preset configurations.
- Quickly switch between preset configurations and DHCP.
- Select different network services, such as `Wi-Fi` and `Ethernet`.
- Configure IP address, subnet mask, router, and DNS servers.
- Use macOS Shortcuts to switch network configurations in automation workflows.

## Use Cases

- Switch between different network environments, such as office, home, and lab networks.
- Move back and forth between DHCP and fixed IP settings.
- Save common static IP configurations for debugging routers, switches, and embedded devices.
- Use Shortcuts conditions to switch configurations automatically.

## Installation

Download the latest `.dmg` installer from GitHub Releases, open it, and drag the app into `Applications`.

On first launch, macOS may ask you to confirm opening an app downloaded from the internet.

## Usage

1. Open the app.
2. Select a network service in the top-right corner, such as `Wi-Fi`.
3. Click `+` in the configuration list to add a configuration.
4. Fill in the name, IP address, subnet mask, router, and DNS servers.
5. Select a configuration and click `Apply`.
6. Click `DHCP` at the bottom to switch the current network service back to DHCP.

Switching network settings uses macOS `networksetup`, so administrator confirmation may be required.

## Shortcuts

The app provides two Shortcuts actions:

- `Apply Network Configuration`: switches a network service to a saved static IP configuration.
- `Switch Network Service to DHCP`: switches a network service back to DHCP and clears custom DNS servers.

Search for the app name or action name in macOS Shortcuts, then combine it with conditions, menus, time, location, or other automation rules.

## Development

Requirements:

- macOS 26 or later
- Xcode 26 or later

Build:

```bash
xcodebuild build \
  -project NetworkSelectorForMacOS.xcodeproj \
  -scheme NetworkSelectorForMacOS \
  -configuration Debug \
  -destination "platform=macOS"
```

## Release

This project includes GitHub Actions:

- Branch push: runs a Debug build check.
- Tag push: syncs `MARKETING_VERSION` to the tag version, runs a build check, builds the Release app, creates a `.dmg`, and uploads it to the matching GitHub Release.

Release example:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Supported tag formats:

- `1.2.3`
- `v1.2.3`

## Permissions

The app modifies macOS network settings through `/usr/sbin/networksetup`. Because these are system network settings, switching configurations may require administrator permission.

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
