import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Key {
        static let wrapEnabled = "wrapEnabled"
        static let wrapWhileDragging = "wrapWhileDragging"
    }

    /// ⌃⌥⌘ + arrow jumps to the adjacent display; ⌃⌥⌘ + Space opens the pie menu.
    private static let hotKeyModifiers = controlKey | optionKey | cmdKey

    private let defaults = UserDefaults.standard
    private let wrapper = EdgeWrapper()
    private let pie = PieMenu()
    private var statusItem: NSStatusItem!
    private var failedHotKeys: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: [Key.wrapEnabled: true, Key.wrapWhileDragging: false])
        wrapper.isEnabled = defaults.bool(forKey: Key.wrapEnabled)
        wrapper.wrapsWhileDragging = defaults.bool(forKey: Key.wrapWhileDragging)
        wrapper.start()

        pie.onOpenChange = { [weak self] open in self?.wrapper.isSuspended = open }

        for direction in Direction.allCases {
            let ok = HotKeys.shared.register(keyCode: direction.keyCode, modifiers: Self.hotKeyModifiers) { [weak self] in
                self?.jump(direction)
            }
            if ok == nil { failedHotKeys.append("⌃⌥⌘\(direction.arrow)") }
        }
        if HotKeys.shared.register(keyCode: kVK_Space, modifiers: Self.hotKeyModifiers, handler: { [weak self] in self?.pie.toggle() }) == nil {
            failedHotKeys.append("⌃⌥⌘Space")
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.left.and.right.square", accessibilityDescription: "Semou")
        rebuildMenu()
    }

    private func jump(_ direction: Direction) {
        pie.close()
        let displays = Displays.all()
        guard let source = Displays.display(at: Displays.cursorLocation, in: displays),
              let target = Displays.neighbor(of: source, direction, in: displays) else { return }
        Displays.warp(to: target.center)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let wrap = NSMenuItem(title: "Wrap Cursor at Screen Edges", action: #selector(toggleWrap), keyEquivalent: "")
        wrap.state = wrapper.isEnabled ? .on : .off
        menu.addItem(wrap)

        let drag = NSMenuItem(title: "Wrap While Dragging", action: #selector(toggleDragWrap), keyEquivalent: "")
        drag.state = wrapper.wrapsWhileDragging ? .on : .off
        menu.addItem(drag)

        menu.addItem(.separator())
        for (title, direction) in [("Jump Left", Direction.left), ("Jump Right", .right), ("Jump Up", .up), ("Jump Down", .down)] {
            let item = NSMenuItem(title: title, action: #selector(jumpFromMenu(_:)), keyEquivalent: "")
            item.representedObject = direction
            item.keyEquivalentModifierMask = [.control, .option, .command]
            item.keyEquivalent = String(Character(UnicodeScalar(arrowKeyEquivalent(direction))!))
            menu.addItem(item)
        }
        let pieItem = NSMenuItem(title: "Show Pie Menu", action: #selector(showPie), keyEquivalent: " ")
        pieItem.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(pieItem)

        if !failedHotKeys.isEmpty {
            let warning = NSMenuItem(title: "In use by another app: \(failedHotKeys.joined(separator: ", "))", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "Quit Semou", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
        statusItem.menu = menu
    }

    private func arrowKeyEquivalent(_ direction: Direction) -> Int {
        switch direction {
        case .left: return NSLeftArrowFunctionKey
        case .right: return NSRightArrowFunctionKey
        case .up: return NSUpArrowFunctionKey
        case .down: return NSDownArrowFunctionKey
        }
    }

    @objc private func toggleWrap() {
        wrapper.isEnabled.toggle()
        defaults.set(wrapper.isEnabled, forKey: Key.wrapEnabled)
        rebuildMenu()
    }

    @objc private func toggleDragWrap() {
        wrapper.wrapsWhileDragging.toggle()
        defaults.set(wrapper.wrapsWhileDragging, forKey: Key.wrapWhileDragging)
        rebuildMenu()
    }

    @objc private func jumpFromMenu(_ sender: NSMenuItem) {
        guard let direction = sender.representedObject as? Direction else { return }
        jump(direction)
    }

    @objc private func showPie() {
        // Let the status menu finish closing before the panel appears.
        DispatchQueue.main.async { self.pie.open() }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = "\(error.localizedDescription)\n\nMove Semou.app to /Applications and try again."
            alert.runModal()
        }
        rebuildMenu()
    }
}
