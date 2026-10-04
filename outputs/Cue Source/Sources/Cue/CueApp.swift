import SwiftUI
import AppKit
import Carbon

@main
struct CueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private var hotkey: EventHotKeyRef?
    private var hotkeyHandler: EventHandlerRef?
    private let session = Session()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = CuePanel(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 390),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "Cue"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 780, height: 300)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.contentView = CueHostingView(rootView: ContentView(model: session, hide: { [weak self] in self?.panel.orderOut(nil) }))
        panel.center()
        panel.setFrameAutosaveName("CueHorizontalPanel")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Cue")
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Cue", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(withTitle: "Start / Stop Listening", action: #selector(toggleAudio), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Cue", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        registerShortcut()
        showPanel()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.orderOut(nil); return false }
    @objc func togglePanel() { if panel.isVisible { panel.orderOut(nil) } else { showPanel() } }
    private func showPanel() { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
    @objc func toggleAudio() { session.toggleListening() }
    @objc func quit() { NSApp.terminate(nil) }

    private func registerShortcut() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let app = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            Task { @MainActor in app.togglePanel() }
            return noErr
        }, 1, &event, pointer, &hotkeyHandler)
        let id = EventHotKeyID(signature: 0x43554531, id: 1)
        let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey | shiftKey), id, GetApplicationEventTarget(), 0, &hotkey)
        if result != noErr { session.error = "⌘⇧Space is already in use. You can show or hide Cue from its menu bar icon." }
    }
}

@MainActor
private final class CuePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class CueHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
