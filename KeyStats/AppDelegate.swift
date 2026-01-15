import Cocoa
import TelemetryDeck

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var menuBarController: MenuBarController?
    private var permissionCheckTimer: Timer?
    private var permissionCheckCount = 0
    private let maxPermissionChecks = 150 // 5分钟后停止（2秒间隔 × 150次）
    private let launchAtLoginPromptedKey = "launchAtLoginPrompted"
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 初始化 TelemetryDeck
        var config = TelemetryDeck.Config(appID: "24F911EE-3D21-4EE7-9E7D-5F9FA485B66E")
        #if DEBUG
        config.testMode = false  // Debug 构建也发送正式数据
        #endif
        TelemetryDeck.initialize(config: config)
        TelemetryDeck.signal("appLaunched")

        // 初始化菜单栏控制器
        menuBarController = MenuBarController()
        applyAppIcon()

        // 检查并请求辅助功能权限
        checkAndRequestPermission()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // 停止输入监听
        InputMonitor.shared.stopMonitoring()
        permissionCheckTimer?.invalidate()
        StatsManager.shared.flushPendingSave()
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - 权限检查
    
    private func checkAndRequestPermission() {
        if InputMonitor.shared.hasAccessibilityPermission() {
            // 已有权限，直接开始监听
            InputMonitor.shared.startMonitoring()
            promptLaunchAtLoginIfNeeded()
        } else {
            // 请求权限并显示提示
            showPermissionAlert()
            
            // 定期检查权限状态（最多5分钟）
            permissionCheckCount = 0
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                self.permissionCheckCount += 1

                // 检查是否获得权限
                if InputMonitor.shared.hasAccessibilityPermission() {
                    timer.invalidate()
                    self.permissionCheckTimer = nil
                    InputMonitor.shared.startMonitoring()
                    self.promptLaunchAtLoginIfNeeded()
                    TelemetryDeck.signal("permissionGranted", parameters: ["permission": "accessibility"])
                    print("权限已授予，开始监听")
                    return
                }

                // 检查是否超时（5分钟）
                if self.permissionCheckCount >= self.maxPermissionChecks {
                    timer.invalidate()
                    self.permissionCheckTimer = nil
                    print("权限检查超时（5分钟），请手动在系统设置中授予辅助功能权限后重启应用")
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("permission.title", comment: "")
        // 使用 Assets 中的 AppIcon
        if let appIcon = NSImage(named: "AppIcon") {
            alert.icon = makeRoundedAlertIcon(from: appIcon)
        }
        alert.informativeText = NSLocalizedString("permission.message", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("permission.openSettings", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("permission.later", comment: ""))

        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
            _ = InputMonitor.shared.checkAccessibilityPermission()
        }
    }

    private func promptLaunchAtLoginIfNeeded() {
        guard InputMonitor.shared.hasAccessibilityPermission() else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: launchAtLoginPromptedKey) else { return }
        defaults.set(true, forKey: launchAtLoginPromptedKey)

        if LaunchAtLoginManager.shared.isEnabled {
            return
        }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("launchAtLogin.prompt.title", comment: "")
        alert.informativeText = NSLocalizedString("launchAtLogin.prompt.message", comment: "")
        alert.alertStyle = .informational
        alert.addButton(withTitle: NSLocalizedString("launchAtLogin.prompt.enable", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("launchAtLogin.prompt.later", comment: ""))

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try LaunchAtLoginManager.shared.setEnabled(true)
            } catch {
                showLaunchAtLoginError()
            }
        }
    }

    private func showLaunchAtLoginError() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("launchAtLogin.error.title", comment: "")
        alert.informativeText = NSLocalizedString("launchAtLogin.error.message", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("button.ok", comment: ""))
        alert.runModal()
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func makeRoundedAlertIcon(from image: NSImage) -> NSImage {
        let targetSize: CGFloat = 64
        let rect = NSRect(x: 0, y: 0, width: targetSize, height: targetSize)
        let icon = NSImage(size: rect.size)
        icon.lockFocus()
        let radius = targetSize * 0.22
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.addClip()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        icon.unlockFocus()
        return icon
    }

    private func applyAppIcon() {
        guard let appIcon = NSImage(named: "AppIcon") else {
            return
        }
        NSApp.applicationIconImage = appIcon
    }
}
