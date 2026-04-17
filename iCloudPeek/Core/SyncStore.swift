import Foundation
import Combine

final class SyncStore: ObservableObject {
    static let shared = SyncStore()

    @Published private(set) var active: [SyncItem] = []
    @Published private(set) var pending: [SyncItem] = []
    @Published private(set) var recentlyFinished: [SyncItem] = []
    @Published private(set) var totalObserved: Int = 0
    @Published var folderFilter: String? = nil

    var onQueueEmptied: (() -> Void)?

    private var knownFinished: Set<String> = []
    private var hadActiveLastTick = false
    private let maxHistory = 50

    init() {}

    func apply(items: [SyncItem], totalScanned: Int = 0) {
        let filtered: [SyncItem]
        if let filter = folderFilter, !filter.isEmpty {
            filtered = items.filter { $0.folder.localizedCaseInsensitiveContains(filter) }
        } else {
            filtered = items
        }

        let nowActive = filtered.filter(\.isActive).sorted { $0.displayName < $1.displayName }
        let nowPending = filtered.filter(\.isPending).sorted { $0.displayName < $1.displayName }

        let newlyFinished = filtered.filter { item in
            guard item.isFinished else { return false }
            return !knownFinished.contains(item.id)
        }
        newlyFinished.forEach { knownFinished.insert($0.id) }

        if !newlyFinished.isEmpty {
            let combined = newlyFinished + recentlyFinished
            recentlyFinished = Array(combined.prefix(maxHistory))
        }

        active = nowActive
        pending = nowPending
        totalObserved = totalScanned

        let hasWork = !nowActive.isEmpty || !nowPending.isEmpty
        if hadActiveLastTick && !hasWork {
            onQueueEmptied?()
        }
        hadActiveLastTick = hasWork
    }

    var summary: String {
        let uploading = active.filter {
            if case .uploading = $0.state { return true }
            return false
        }.count
        let downloading = active.filter {
            if case .downloading = $0.state { return true }
            return false
        }.count
        return "\(uploading) subindo · \(downloading) baixando · \(pending.count) aguardando"
    }

    var totalInFlight: Int {
        active.count + pending.count
    }

    var aggregateActivity: AggregateState {
        if active.contains(where: { if case .uploading = $0.state { return true } else { return false } }) {
            return .uploading
        }
        if active.contains(where: { if case .downloading = $0.state { return true } else { return false } }) {
            return .downloading
        }
        return .idle
    }

    enum AggregateState {
        case idle, uploading, downloading
    }
}
