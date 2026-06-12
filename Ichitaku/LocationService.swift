import CoreLocation
import Foundation
import Observation

/// 現在地を取得して検索に使うサービスです。
@Observable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    /// 現在地の利用可否メッセージです。
    var locationStatusMessage: String? {
        switch authorizationStatus {
        case .notDetermined:
            return "位置情報を許可すると、徒歩・車検索が使えます。許可しなくても電車・駅検索は使えます。"
        case .restricted, .denied:
            return "位置情報がオフのため、徒歩・車検索は使えません。設定アプリから許可すると使えます。"
        case .authorizedAlways, .authorizedWhenInUse:
            if !hasResolvedLocation {
                return "現在地を取得中です。取得できると徒歩・車検索が使えます。"
            }
            if !isLocationInJapan {
                return "現在地が日本外のため、徒歩・車検索は使えません。電車・駅検索を使ってください。"
            }
            return nil
        @unknown default:
            return "位置情報の状態を確認できませんでした。"
        }
    }

    /// 位置情報の利用許可をリクエストします。
    func requestPermissionIfNeeded() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    var isAuthorizedForLocation: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasResolvedLocation: Bool {
        latitude != nil && longitude != nil
    }

    var canUseNearbySearch: Bool {
        isAuthorizedForLocation && hasResolvedLocation && isLocationInJapan
    }

    private var isLocationInJapan: Bool {
        guard let latitude, let longitude else { return false }
        return (20.0...46.5).contains(latitude) && (122.0...154.5).contains(longitude)
    }

    /// 現在地の更新を開始します。
    func startUpdatingLocation() {
        requestPermissionIfNeeded()

        let canUseLocation = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        guard canUseLocation else { return }

        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        latitude = nil
        longitude = nil
    }
}
