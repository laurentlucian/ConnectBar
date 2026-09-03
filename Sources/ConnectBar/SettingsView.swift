import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Binding var showing: Bool

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        sectionTitle("APPS")
                        Spacer()
                        Button(model.selectedAppIDs == Set(model.apps.map(\.id)) ? "None" : "All") {
                            model.toggleAllApps()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .disabled(model.apps.isEmpty)
                    }
                    if model.apps.isEmpty { Text("Apps appear after connecting asc.").foregroundStyle(.secondary) }
                    ForEach(model.apps) { app in
                        Toggle(isOn: Binding(
                            get: { model.selectedAppIDs.contains(app.id) },
                            set: { enabled in
                                if enabled { model.selectedAppIDs.insert(app.id) }
                                else { model.selectedAppIDs.remove(app.id) }
                            }
                        )) { VStack(alignment: .leading) { Text(app.name); if let bundleID = app.bundleID { Text(bundleID).font(.caption).foregroundStyle(.secondary) } } }
                    }
                }.font(.system(size: 13))
                section("BEHAVIOR") {
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { _ in model.toggleLogin() }))
                    Toggle("Notifications", isOn: Binding(get: { model.notificationsEnabled }, set: { enabled in enabled ? model.requestNotifications() : (model.notificationsEnabled = false) }))
                    Toggle("Mock data", isOn: $model.mockMode)
                }
                section("CONNECTION") {
                    Text("ConnectBar uses the credentials already stored by asc. Keys never enter this app.")
                        .foregroundStyle(.secondary)
                    Button("Refresh") { model.refresh() }
                }
            }.padding(14)
        }
        Divider()
        HStack {
            Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            Spacer()
            Button("Done") { showing = false }.keyboardShortcut(.defaultAction)
        }.padding(12)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle(title)
            content()
        }.font(.system(size: 13))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .medium)).tracking(0.8).foregroundStyle(.secondary)
    }
}
