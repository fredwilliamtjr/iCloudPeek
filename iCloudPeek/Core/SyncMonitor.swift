import Foundation

final class SyncMonitor {
    private let store: SyncStore
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.smartfull.icloudpeek.scan", qos: .utility)
    private var lastSamples: [String: (percent: Double, bytes: Int64, time: Date)] = [:]
    private var firstSeen: [String: Date] = [:]

    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .fileSizeKey,
        .localizedNameKey,
        .isUbiquitousItemKey,
        .ubiquitousItemIsUploadingKey,
        .ubiquitousItemIsDownloadingKey,
        .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemUploadingErrorKey,
        .ubiquitousItemDownloadingErrorKey
    ]

    private let metadataKeys: [String] = [
        NSMetadataUbiquitousItemPercentUploadedKey,
        NSMetadataUbiquitousItemPercentDownloadedKey
    ]

    init(store: SyncStore) {
        self.store = store
    }

    func start() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent("Library/Mobile Documents"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents")
        ]
        NSLog("[iCloudPeek] SyncMonitor start — roots: \(roots.map(\.path))")

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.2, repeating: .seconds(3))
        timer.setEventHandler { [weak self] in
            self?.scan(roots: roots)
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func scan(roots: [URL]) {
        let fm = FileManager.default
        let now = Date()
        let home = fm.homeDirectoryForCurrentUser.path
        var items: [SyncItem] = []
        var seen: Set<String> = []
        var scanned = 0
        var ubiquitousCount = 0
        var uploadingCount = 0
        var downloadingCount = 0
        var errorCount = 0
        var notDownloadedCount = 0

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants],
                errorHandler: { url, error in
                    NSLog("[iCloudPeek ENUM ERR] \(url.path): \(error.localizedDescription)")
                    return true
                }
            ) else { continue }

        for case let url as URL in enumerator {
            let canonical = (try? url.resourceValues(forKeys: [.canonicalPathKey]))?.canonicalPath ?? url.path
            if !seen.insert(canonical).inserted { continue }
            scanned += 1
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }
            if values.isDirectory == true { continue }

            guard values.isUbiquitousItem == true else { continue }
            ubiquitousCount += 1

            let isUploading = values.ubiquitousItemIsUploading ?? false
            let isDownloading = values.ubiquitousItemIsDownloading ?? false
            let downloadingStatus = values.ubiquitousItemDownloadingStatus
            let upError = values.ubiquitousItemUploadingError
            let downError = values.ubiquitousItemDownloadingError

            if isUploading { uploadingCount += 1 }
            if isDownloading { downloadingCount += 1 }
            if upError != nil || downError != nil { errorCount += 1 }
            if downloadingStatus == .notDownloaded { notDownloadedCount += 1 }

            if !isUploading && !isDownloading && upError == nil && downError == nil {
                continue
            }

            let size = Int64(values.fileSize ?? 0)
            let displayName = values.localizedName ?? stripIcloudExtension(url.lastPathComponent)
            let id = url.path
            let folder = url.deletingLastPathComponent().path.replacingOccurrences(of: home, with: "~")

            let percentUp: Double = 0
            let percentDown: Double = 0

            let state: SyncItem.State
            var speed: Double?

            if isUploading {
                state = .uploading(percent: percentUp)
                speed = computeSpeed(id: id, percent: percentUp, totalBytes: size, now: now)
            } else if isDownloading {
                state = .downloading(percent: percentDown)
                speed = computeSpeed(id: id, percent: percentDown, totalBytes: size, now: now)
            } else if let err = upError ?? downError {
                state = .error(err.localizedDescription)
            } else if downloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
                continue
            } else {
                continue
            }

            let seenAt: Date
            if let existing = firstSeen[id] {
                seenAt = existing
            } else {
                seenAt = now
                firstSeen[id] = now
            }

            items.append(SyncItem(
                id: id,
                url: url,
                displayName: displayName,
                folder: folder,
                size: size,
                state: state,
                updatedAt: now,
                firstSeenAt: seenAt,
                speedBytesPerSecond: speed
            ))
        }
        }

        let activeIds = Set(items.map(\.id))
        firstSeen = firstSeen.filter { activeIds.contains($0.key) }

        let snapshot = items
        let scannedFinal = scanned
        NSLog("[iCloudPeek] scan — total=\(scannedFinal) ubiquitous=\(ubiquitousCount) uploading=\(uploadingCount) downloading=\(downloadingCount) errors=\(errorCount) notDownloaded=\(notDownloadedCount) → reportando \(snapshot.count)")

        DispatchQueue.main.async {
            self.store.apply(items: snapshot, totalScanned: scannedFinal)
        }
    }

    private func stripIcloudExtension(_ name: String) -> String {
        if name.hasSuffix(".icloud") && name.hasPrefix(".") {
            let start = name.index(after: name.startIndex)
            let end = name.index(name.endIndex, offsetBy: -".icloud".count)
            return String(name[start..<end])
        }
        return name
    }

    private func computeSpeed(id: String, percent: Double, totalBytes: Int64, now: Date) -> Double? {
        let transferred = Int64(Double(totalBytes) * percent / 100.0)
        defer { lastSamples[id] = (percent, transferred, now) }
        guard let prev = lastSamples[id] else { return nil }
        let dt = now.timeIntervalSince(prev.time)
        guard dt > 0.2 else { return nil }
        let delta = Double(transferred - prev.bytes)
        guard delta > 0 else { return nil }
        return delta / dt
    }
}
