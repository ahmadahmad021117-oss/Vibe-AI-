import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkStatus {
    static let shared = NetworkStatus()

    private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.vibe.network-status")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}

extension Error {
    /// Short, user-facing copy. Prefers a LocalizedError's curated description,
    /// then maps known URLError codes to plain-English copy, then falls back to
    /// a generic message when the OS-supplied string is empty or too technical.
    var friendlyMessage: String {
        if let local = self as? LocalizedError,
           let desc = local.errorDescription,
           !desc.isEmpty {
            return desc
        }

        let urlError = (self as? URLError) ?? (self as NSError).underlyingURLError
        if let code = urlError?.code {
            switch code {
            case .notConnectedToInternet:
                return "You're offline. Reconnect and try again."
            case .timedOut:
                return "That took too long. Check your connection and try again."
            case .networkConnectionLost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .cannotFindHost:
                return "Couldn't reach the server. Try again in a moment."
            case .cancelled:
                return "Request cancelled."
            default:
                return "Network error. Try again."
            }
        }

        let desc = self.localizedDescription
        if desc.isEmpty || desc.count > 140 {
            return "Something went wrong. Try again."
        }
        return desc
    }
}

private extension NSError {
    /// Best-effort unwrap of an NSUnderlyingErrorKey chain into a URLError.
    var underlyingURLError: URLError? {
        var current: NSError? = self
        for _ in 0..<3 {
            guard let err = current else { return nil }
            if let url = err as? URLError { return url }
            current = err.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }
}

/// Retry a transient-failure-prone async op with exponential backoff. Only
/// retries on idempotent URLError codes (timeouts, lost connections, DNS) —
/// callers must guarantee the operation is safe to repeat (reads, not writes).
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: Duration = .milliseconds(400),
    _ op: () async throws -> T
) async throws -> T {
    var attempt = 0
    var delay = initialDelay
    while true {
        do {
            return try await op()
        } catch {
            attempt += 1
            guard attempt < maxAttempts, isRetryable(error) else { throw error }
            try? await Task.sleep(for: delay)
            delay *= 2
        }
    }
}

private func isRetryable(_ error: Error) -> Bool {
    let url = (error as? URLError) ?? (error as NSError).underlyingURLError
    guard let code = url?.code else { return false }
    switch code {
    case .timedOut,
         .networkConnectionLost,
         .cannotConnectToHost,
         .dnsLookupFailed,
         .cannotFindHost:
        return true
    default:
        return false
    }
}
