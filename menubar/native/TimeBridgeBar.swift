// TimeBridge Bar — a tiny native macOS menu bar app. No dependencies.
// Build with ./build.sh (uses Apple's own Swift compiler).
//
// The dropdown is an NSPopover, not an NSMenu: popovers are real key windows,
// so the editable date/time fields, buttons, and zone pickers all receive
// events normally. NSMenu custom views cannot take keyboard focus.
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var lastPopoverClose = Date.distantPast
    private var fromZoneID = defaultFromZoneID
    private var toZoneID = defaultToZoneID

    func applicationDidFinishLaunching(_ note: Notification) {
        fromZoneID = UserDefaults.standard.string(forKey: fromDefaultsKey) ?? defaultFromZoneID
        toZoneID = UserDefaults.standard.string(forKey: toDefaultsKey) ?? defaultToZoneID

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        refreshTitle()

        popover.behavior = .transient // click outside to dismiss
        popover.animates = false
        popover.delegate = self

        // Dropdown menus inside the popover must not dismiss it: suspend the
        // transient behavior while a menu is up (popUp blocks until closed).
        presentMenuGuard = { [weak self] menu, anchor in
            guard let self else { return }
            self.popover.behavior = .applicationDefined
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height + 4), in: anchor)
            self.popover.behavior = .transient
        }

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshTitle()
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshTitle() {
        let fromZone = timeZoneFor(id: fromZoneID)
        let toZone = timeZoneFor(id: toZoneID)
        let from = zoneChoice(for: fromZoneID)
        let to = zoneChoice(for: toZoneID)
        statusItem.button?.title = "\(from.code) \(compactTime(fromZone)) → \(to.code) \(compactTime(toZone))"
    }

    private func saveZoneChoices() {
        UserDefaults.standard.set(fromZoneID, forKey: fromDefaultsKey)
        UserDefaults.standard.set(toZoneID, forKey: toDefaultsKey)
    }

    /* ---------- Popover ---------- */

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // A transient popover already closes on the status-item click itself;
        // don't immediately reopen from the same click.
        if Date().timeIntervalSince(lastPopoverClose) < 0.25 { return }
        guard let button = statusItem.button else { return }
        popover.contentViewController = makeContentController()
        NSApp.activate(ignoringOtherApps: true) // lets the text fields take keys
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        lastPopoverClose = Date()
        popover.contentViewController = nil // rebuilt fresh on next open
    }

    private func makeContentController() -> NSViewController {
        let vc = NSViewController()
        vc.view = makeTimeBridgeView()
        return vc
    }

    // Rebuild the content in place (e.g. after a zone change) without closing.
    private func refreshPopoverContent() {
        refreshTitle()
        guard popover.isShown else { return }
        popover.contentViewController = makeContentController()
    }

    private func makeTimeBridgeView() -> TimeBridgeMenuView {
        let now = Date()
        let fromZone = timeZoneFor(id: fromZoneID)
        let toZone = timeZoneFor(id: toZoneID)
        let from = zoneChoice(for: fromZoneID)
        let to = zoneChoice(for: toZoneID)

        let root = TimeBridgeMenuView(
            from: from,
            to: to,
            fromZone: fromZone,
            toZone: toZone,
            date: now,
            canOpenApp: !appURL.isEmpty
        )
        root.onSwap = { [weak self] in self?.swapZones() }
        root.onPickFrom = { [weak self] button in
            self?.showZoneMenu(from: button, selectingFromZone: true)
        }
        root.onPickTo = { [weak self] button in
            self?.showZoneMenu(from: button, selectingFromZone: false)
        }
        root.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        return root
    }

    /* ---------- Zone picker ---------- */

    private func showZoneMenu(from button: NSButton, selectingFromZone: Bool) {
        let picker = NSMenu()
        for choice in zoneChoices {
            let row = NSMenuItem(
                title: "\(choice.icon) \(choice.label)",
                action: selectingFromZone ? #selector(selectFromZone(_:)) : #selector(selectToZone(_:)),
                keyEquivalent: ""
            )
            row.target = self
            row.representedObject = choice.id
            row.state = choice.id == (selectingFromZone ? fromZoneID : toZoneID) ? .on : .off
            picker.addItem(row)
        }
        presentDropdownMenu(picker, from: button)
    }

    @objc private func selectFromZone(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String {
            fromZoneID = id
            saveZoneChoices()
            refreshPopoverContent()
        }
    }

    @objc private func selectToZone(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String {
            toZoneID = id
            saveZoneChoices()
            refreshPopoverContent()
        }
    }

    @objc private func swapZones() {
        swap(&fromZoneID, &toZoneID)
        saveZoneChoices()
        refreshPopoverContent()
    }
}

@main
struct TimeBridgeBarApp {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}
