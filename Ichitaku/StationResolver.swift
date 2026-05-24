import CoreLocation
import Foundation

/// 駅名から座標を引くためのヘルパーです。
struct StationResolver {
    /// 駅名を座標に解決します。
    func resolve(stationName: String, near currentLocation: CLLocation?) async -> CLLocationCoordinate2D? {
        let trimmed = stationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let query = trimmed.hasSuffix("駅") ? trimmed : "\(trimmed)駅"

        do {
            let placemarks = try await geocodeWithTimeout(query: query, timeoutSeconds: 4)
            let locations = placemarks.compactMap { $0.location }
            guard !locations.isEmpty else { return nil }

            if let currentLocation {
                let nearest = locations.min { a, b in
                    a.distance(from: currentLocation) < b.distance(from: currentLocation)
                }
                return nearest?.coordinate
            }

            return locations.first?.coordinate
        } catch {
            return nil
        }
    }

    /// ジオコーディングが長引くときに待ちすぎないためのタイムアウト付き実行です。
    private func geocodeWithTimeout(query: String, timeoutSeconds: UInt64) async throws -> [CLPlacemark] {
        try await withThrowingTaskGroup(of: [CLPlacemark].self) { group in
            group.addTask {
                let geocoder = CLGeocoder()
                return try await geocoder.geocodeAddressString(query)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                throw CancellationError()
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return first
        }
    }
}
