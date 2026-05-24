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
            return "位置情報を許可すると、徒歩・車検索の精度が上がります。"
        case .restricted, .denied:
            return "位置情報がオフのため、徒歩・車検索は現在地なしで実行します。設定アプリから許可できます。"
        case .authorizedAlways, .authorizedWhenInUse:
            if latitude == nil || longitude == nil {
                return "現在地を取得中です。少し待ってから検索すると近くのお店が出やすくなります。"
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
