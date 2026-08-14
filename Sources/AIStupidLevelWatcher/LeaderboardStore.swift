import Combine
import Foundation

enum WatcherError: LocalizedError {
    case httpStatus(Int)
    case invalidResponse
    case emptyPayload
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case let .httpStatus(code):
            return "HTTP \(code)"
        case .invalidResponse:
            return "invalid JSON response"
        case .emptyPayload:
            return "the endpoint returned no model rows"
        case let .unavailable(message):
            return message
        }
    }
}

enum DashboardAPI {
    private static let host = URL(string: "https://aistupidlevel.info")!

    static func fetchScores(for view: ScoreView) async throws -> (scores: [ModelScore], sourceUpdatedAt: String?) {
        do {
            let (data, metadata) = try await requestCached(view: view)
            return (data, metadata)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // The page itself uses this endpoint as its fallback when its
            // cache is unavailable. Keep the fallback narrow and public.
            return try await requestScores(view: view)
        }
    }

    private static func requestCached(view: ScoreView) async throws -> ([ModelScore], String?) {
        var components = URLComponents(
            url: host.appendingPathComponent("dashboard/cached"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "period", value: "latest"),
            URLQueryItem(name: "sortBy", value: view.rawValue),
            URLQueryItem(name: "analyticsPeriod", value: "latest")
        ]

        let data = try await get(components.url!)
        let envelope: CachedEnvelope
        do {
            envelope = try JSONDecoder().decode(CachedEnvelope.self, from: data)
        } catch {
            throw WatcherError.invalidResponse
        }

        guard envelope.success == true,
              let scores = envelope.data?.modelScores,
              !scores.isEmpty else {
            throw WatcherError.emptyPayload
        }
        return (scores, envelope.meta?.cachedAt)
    }

    private static func requestScores(view: ScoreView) async throws -> ([ModelScore], String?) {
        var components = URLComponents(
            url: host.appendingPathComponent("dashboard/scores"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "period", value: "latest"),
            URLQueryItem(name: "sortBy", value: view.rawValue)
        ]

        let data = try await get(components.url!)
        let envelope: ScoreEnvelope
        do {
            envelope = try JSONDecoder().decode(ScoreEnvelope.self, from: data)
        } catch {
            throw WatcherError.invalidResponse
        }

        guard envelope.success == true, let scores = envelope.data, !scores.isEmpty else {
            throw WatcherError.emptyPayload
        }
        return (scores, scores.compactMap(\.lastUpdated).first)
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AIStupidLevelMenuBarWatcher/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatcherError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WatcherError.httpStatus(httpResponse.statusCode)
        }
        return data
    }
}

@MainActor
final class LeaderboardStore: ObservableObject {
    static let refreshInterval: TimeInterval = 30 * 60

    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSuccessfulFetch: Date?

    private let onSnapshotChanged: (DashboardSnapshot?) -> Void
    private var refreshTimer: Timer?

    init(onSnapshotChanged: @escaping (DashboardSnapshot?) -> Void = { _ in }) {
        self.onSnapshotChanged = onSnapshotChanged
        onSnapshotChanged(nil)
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var statusBarTitle: String {
        if let best = snapshot?.bestValue, let value = best.valueScore {
            return "AI V \(format(value))"
        }
        guard let best = snapshot?.bestCombined, let score = best.combined else {
            return isRefreshing ? "AI …" : "AI —"
        }
        return "AI \(format(score))"
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let results = try await withThrowingTaskGroup(
                of: (ScoreView, [ModelScore], String?).self,
                returning: [(ScoreView, [ModelScore], String?)] .self
            ) { group in
                for view in ScoreView.allCases {
                    group.addTask {
                        let result = try await DashboardAPI.fetchScores(for: view)
                        return (view, result.scores, result.sourceUpdatedAt)
                    }
                }

                var collected: [(ScoreView, [ModelScore], String?)] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }

            let scoresByView = Dictionary(uniqueKeysWithValues: results.map { ($0.0, $0.1) })
            guard let newSnapshot = DashboardSnapshotBuilder.make(
                scoresByView: scoresByView,
                fetchedAt: Date(),
                // Use the row's lastUpdated value for the benchmark batch. The
                // cache timestamp only says when the API served the response.
                sourceUpdatedAt: nil
            ) else {
                throw WatcherError.emptyPayload
            }

            snapshot = newSnapshot
            onSnapshotChanged(newSnapshot)
            lastSuccessfulFetch = newSnapshot.fetchedAt
            lastError = nil
        } catch is CancellationError {
            // Keep the last successful snapshot when a refresh is cancelled.
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f", value)
    }
}
