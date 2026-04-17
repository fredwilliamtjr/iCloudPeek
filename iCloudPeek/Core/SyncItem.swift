import Foundation

struct SyncItem: Identifiable, Equatable {
    enum State: Equatable {
        case uploading(percent: Double)
        case downloading(percent: Double)
        case pending
        case current
        case notDownloaded
        case error(String)
    }

    let id: String
    let url: URL
    let displayName: String
    let folder: String
    let size: Int64
    let state: State
    let updatedAt: Date
    let firstSeenAt: Date
    let speedBytesPerSecond: Double?

    var isActive: Bool {
        switch state {
        case .uploading, .downloading: return true
        default: return false
        }
    }

    var isPending: Bool {
        if case .pending = state { return true }
        return false
    }

    var isFinished: Bool {
        if case .current = state { return true }
        return false
    }

    var percent: Double? {
        switch state {
        case .uploading(let p), .downloading(let p): return p
        default: return nil
        }
    }

    var stateLabel: String {
        switch state {
        case .uploading(let p): return p > 0 ? String(format: "Subindo %.0f%%", p) : "Subindo"
        case .downloading(let p): return p > 0 ? String(format: "Baixando %.0f%%", p) : "Baixando"
        case .pending: return "Aguardando"
        case .current: return "Sincronizado"
        case .notDownloaded: return "Não baixado"
        case .error(let msg): return "Erro: \(msg)"
        }
    }
}
