import SwiftUI
import AppKit

struct LivePopoverView: View {
    @EnvironmentObject private var store: SyncStore
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @State private var tick: Int = 0

    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !store.active.isEmpty {
                        section("Em andamento") {
                            ForEach(store.active) { item in
                                LiveItemRow(item: item)
                            }
                        }
                    }
                    if !store.pending.isEmpty {
                        section("Pendentes") {
                            ForEach(store.pending) { item in
                                LiveItemRow(item: item)
                            }
                        }
                    }
                    if !store.recentlyFinished.isEmpty {
                        section("Concluídos recentemente") {
                            ForEach(store.recentlyFinished.prefix(10)) { item in
                                LiveItemRow(item: item)
                            }
                        }
                    }
                    if store.active.isEmpty && store.pending.isEmpty && store.recentlyFinished.isEmpty {
                        emptyState
                    }
                }
                .padding(14)
            }
            Divider()
            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 400, height: 520)
        .onReceive(refreshTimer) { _ in tick &+= 1 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("iCloudPeek")
                    .font(.headline)
                Spacer()
                Text("\(store.totalObserved) arquivos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(store.totalInFlight > 0 ? store.summary : "Tudo sincronizado")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Iniciar com o Mac", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            Spacer()
            Button("iCloud Drive") { openICloudDrive() }
                .buttonStyle(.borderless)
            Button("Sair") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .font(.caption)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("✓")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Tudo sincronizado")
                .font(.headline)
            Text("Nada entrando ou saindo do iCloud no momento.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func openICloudDrive() {
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            NSWorkspace.shared.open(url)
        } else {
            let fallback = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            NSWorkspace.shared.open(fallback)
        }
    }
}

struct LiveItemRow: View {
    let item: SyncItem

    var body: some View {
        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }) {
            HStack(alignment: .top, spacing: 10) {
                Text(glyph)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(glyphColor)
                    .frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 4) {
                        Text(item.stateLabel)
                        Text("·")
                        Text(size)
                        Text("·")
                        Text("há \(elapsed)")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    Text(item.folder)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var glyph: String {
        switch item.state {
        case .uploading: return "↑"
        case .downloading: return "↓"
        case .pending: return "⋯"
        case .current: return "✓"
        case .error: return "!"
        case .notDownloaded: return "○"
        }
    }

    private var glyphColor: Color {
        switch item.state {
        case .uploading: return .blue
        case .downloading: return .indigo
        case .pending: return .orange
        case .current: return .green
        case .error: return .red
        case .notDownloaded: return .secondary
        }
    }

    private var size: String {
        ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)
    }

    private var elapsed: String {
        let seconds = Int(Date().timeIntervalSince(item.firstSeenAt))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)min" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours)h" : "\(hours)h\(rem)"
    }
}
