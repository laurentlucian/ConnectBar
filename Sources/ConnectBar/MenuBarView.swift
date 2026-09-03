import SwiftUI

struct MenuBarView: View {
    static let size = CGSize(width: 360, height: 520)
    @Environment(AppModel.self) private var model
    @State private var settings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if settings { SettingsView(showing: $settings) }
            else { content }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings ? "Settings" : "ConnectBar").font(.system(size: 13, weight: .semibold))
                if !settings, let lastRefresh = model.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !settings {
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise").rotationEffect(model.isRefreshing ? .degrees(360) : .zero)
                }.buttonStyle(.plain).disabled(model.isRefreshing)
            }
            Button { settings.toggle() } label: {
                Image(systemName: settings ? "xmark" : "gearshape")
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder private var content: some View {
        switch model.connection {
        case .loading where model.signals.isEmpty:
            stateView("Checking App Store Connect", icon: "arrow.triangle.2.circlepath")
        case .missingCLI:
            stateView("Install asc", detail: "brew install asc", icon: "terminal")
        case .unauthenticated:
            stateView("Connect asc", detail: "Run asc auth login", icon: "key")
        case .failed(let message) where model.signals.isEmpty:
            stateView("Couldn’t refresh", detail: message, icon: "exclamationmark.triangle")
        default:
            if model.signals.isEmpty {
                stateView("All clear", detail: "No active builds, submissions, or reviews", icon: "checkmark.circle")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.signals) { SignalRow(signal: $0) }
                    }.padding(10)
                }
                Divider()
                footer
            }
        }
    }

    private func stateView(_ title: String, detail: String? = nil, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).textSelection(.enabled) }
            if case .failed = model.connection { Button("Retry") { model.refresh() } }
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("App Store Connect") { model.openASC() }.buttonStyle(.plain)
            Spacer()
            if model.attentionCount > 0 {
                Button("Mark all seen") { model.markAllSeen() }.buttonStyle(.plain)
            } else {
                Text("All caught up").foregroundStyle(.secondary)
            }
        }.font(.caption).padding(12)
    }
}

private struct SignalRow: View {
    @Environment(AppModel.self) private var model
    let signal: Signal
    var color: Color {
        switch signal.severity { case .critical: .red; case .warning: .orange; case .active: .blue; case .info: .secondary }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(signal.appName).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if let date = signal.occurredAt { Text(date, style: .relative).font(.caption2).foregroundStyle(.tertiary) }
                    if signal.isAttention && !model.seenSignalIDs.contains(signal.id) {
                        Button { model.markSeen(signal) } label: { Image(systemName: "checkmark") }
                            .buttonStyle(.plain).help("Mark seen")
                    }
                }
                Text(signal.title).font(.system(size: 13, weight: .medium))
                if let detail = signal.detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
        }
        .opacity(model.seenSignalIDs.contains(signal.id) ? 0.62 : 1)
        .padding(11).background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
