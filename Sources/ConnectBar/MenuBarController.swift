import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: NSPanel
    private var eventMonitor: Any?

    init(model: AppModel) {
        self.model = model
        let hosting = NSHostingView(rootView: MenuBarView().environment(model))
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: MenuBarView.size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        super.init()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        updateIcon()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }
    }

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        guard let button = statusItem.button, let window = button.window else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = window.screen?.visibleFrame ?? .zero
        let x = min(anchor.midX - MenuBarView.size.width / 2, visible.maxX - MenuBarView.size.width - 8)
        panel.setFrameTopLeftPoint(NSPoint(x: max(visible.minX + 8, x), y: anchor.minY - 4))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 1
        }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func close() {
        panel.orderOut(nil)
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
    }

    private func updateIcon() {
        let symbol: String
        switch model.worstSeverity {
        case .critical: symbol = "exclamationmark.triangle.fill"
        case .warning: symbol = "exclamationmark.circle.fill"
        case .active: symbol = "arrow.triangle.2.circlepath"
        case .info: symbol = "checkmark.circle"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ConnectBar")
        statusItem.button?.title = model.attentionCount > 0 ? " \(model.attentionCount)" : ""
    }
}
