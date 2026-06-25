import AppKit

private let stateDirectory = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/BackpackAwake")
private let stateFile = stateDirectory.appendingPathComponent("state")
private let caffeinatePIDFile = stateDirectory.appendingPathComponent("caffeinate.pid")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: "Status: Checking", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Turn On", action: #selector(toggle), keyEquivalent: "")
    private var enabled = false
    private var caffeinateProcess: Process?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "BackpackAwake"
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        setStatusIcon(symbolName: "backpack", fallbackSymbolName: "power.circle", tooltip: "Backpack Awake: Checking")

        toggleItem.target = self
        menu.addItem(stateItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self

        statusItem.menu = menu
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let status = self.readDesiredState()
            DispatchQueue.main.async {
                self.enabled = status
                self.syncCaffeinateProcess()
                self.render()
            }
        }
    }

    @objc private func toggle() {
        let targetEnabled = !enabled
        toggleItem.isEnabled = false
        stateItem.title = "Status: Updating"
        setStatusIcon(symbolName: "backpack", fallbackSymbolName: "power.circle", tooltip: "Backpack Awake: Updating")

        DispatchQueue.global(qos: .userInitiated).async {
            self.writeDesiredState(targetEnabled)
            DispatchQueue.main.async {
                self.enabled = targetEnabled
                self.toggleItem.isEnabled = true
                self.syncCaffeinateProcess()
                self.render()
            }
        }
    }

    private func render() {
        if enabled {
            setStatusIcon(symbolName: "backpack.fill", fallbackSymbolName: "power.circle.fill", tooltip: "Backpack Awake: On")
            stateItem.title = "Status: On"
            toggleItem.title = "Turn Off"
        } else {
            setStatusIcon(symbolName: "backpack", fallbackSymbolName: "power.circle", tooltip: "Backpack Awake: Off")
            stateItem.title = "Status: Off"
            toggleItem.title = "Turn On"
        }
    }

    private func syncCaffeinateProcess() {
        if enabled {
            if caffeinateProcess?.isRunning == true {
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-im"]

            do {
                try process.run()
                caffeinateProcess = process
                writeCaffeinatePID(process.processIdentifier)
            } catch {
                caffeinateProcess = nil
            }
        } else {
            if caffeinateProcess?.isRunning == true {
                caffeinateProcess?.terminate()
            }
            caffeinateProcess = nil
            removeCaffeinatePID()
        }
    }

    private func readDesiredState() -> Bool {
        if let value = try? String(contentsOf: stateFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            return value == "on"
        }

        return false
    }

    private func writeDesiredState(_ enabled: Bool) {
        do {
            try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            try (enabled ? "on\n" : "off\n").write(to: stateFile, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }

    private func writeCaffeinatePID(_ pid: Int32) {
        do {
            try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            try "\(pid)\n".write(to: caffeinatePIDFile, atomically: true, encoding: .utf8)
        } catch {
            return
        }
    }

    private func removeCaffeinatePID() {
        try? FileManager.default.removeItem(at: caffeinatePIDFile)
    }

    private func setStatusIcon(symbolName: String, fallbackSymbolName: String, tooltip: String) {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
            ?? NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: tooltip)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = tooltip
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
