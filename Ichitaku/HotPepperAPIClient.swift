import Foundation

/// 検索条件をまとめて扱うデータです。
struct ShopSearchCondition {
    var genre: GenreOption = .all
    var keyword: String = ""
    var stationKeyword: String = ""
    var budgetCode: String = ""
    var requiresFreeFood: Bool = false
    var requiresFreeDrink: Bool = false
    var requiresPrivateRoom: Bool = false
    var requiresParking: Bool = false
    var requiresOpenNow: Bool = false
    var requiresMidnight: Bool = false
    var requiresPet: Bool = false
    var transport: TransportOption = .walk
    var latitude: Double?
    var longitude: Double?
    var stationLatitude: Double?
    var stationLongitude: Double?
    var walkMaxMinutes: Int = 15
    var carMaxMinutes: Int = 30
    var trainMaxMinutes: Int = 10

    /// APIに渡すキーワードを組み立てます。
    var composedKeyword: String {
        var words: [String] = []

        if !keyword.isEmpty {
            words.append(keyword)
        }

        if transport == .train, !stationKeyword.isEmpty {
            let normalizedStation = stationKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedStation.isEmpty, !words.contains(normalizedStation) {
                words.append(normalizedStation)
            }
        }

        return words.joined(separator: " ")
    }

    /// 検索条件を短く表示するための文言です。
    var summaryChips: [String] {
        var chips: [String] = ["移動: \(transport.label)"]
        if transport == .walk {
            chips.append("徒歩\(walkMaxMinutes)分以内")
        } else if transport == .car {
            chips.append("車\(carMaxMinutes)分以内")
        } else if transport == .train {
            chips.append("駅から徒歩\(trainMaxMinutes)分以内")
        }

        if transport == .train && !stationKeyword.isEmpty {
            chips.append("駅周辺: \(stationKeyword)")
        }

        if !budgetCode.isEmpty {
            chips.append("予算: \(BudgetOption(code: budgetCode)?.label ?? budgetCode)")
        }
        if !keyword.isEmpty {
            chips.append("キーワード: \(keyword)")
        }
        if requiresFreeFood { chips.append("食べ放題") }
        if requiresFreeDrink { chips.append("飲み放題") }
        if requiresPrivateRoom { chips.append("個室") }
        if requiresParking { chips.append("駐車場") }
        if requiresOpenNow { chips.append("営業中") }
        if requiresMidnight { chips.append("夜間営業") }
        if requiresPet { chips.append("ペット可") }

        return chips
    }
}

enum GenreOption: String, CaseIterable, Identifiable {
    case all = ""
    case g001 = "G001"
    case g002 = "G002"
    case g003 = "G003"
    case g004 = "G004"
    case g005 = "G005"
    case g006 = "G006"
    case g007 = "G007"
    case g008 = "G008"
    case g009 = "G009"
    case g010 = "G010"
    case g011 = "G011"
    case g012 = "G012"
    case g013 = "G013"

    var id: String { rawValue }
    var code: String { rawValue }

    var label: String {
        switch self {
        case .all: return "指定なし"
        case .g001: return "居酒屋"
        case .g002: return "ダイニングバー・バル"
        case .g003: return "創作料理"
        case .g004: return "和食"
        case .g005: return "洋食"
        case .g006: return "イタリアン・フレンチ"
        case .g007: return "中華"
        case .g008: return "焼肉・ホルモン"
        case .g009: return "アジア・エスニック料理"
        case .g010: return "各国料理"
        case .g011: return "カラオケ・パーティ"
        case .g012: return "バー・カクテル"
        case .g013: return "ラーメン"
        }
    }
}

/// 営業状態の絞り込みです。
enum BusinessStatus: String, CaseIterable, Identifiable {
    case openNow
    case anyTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openNow: return "営業中"
        case .anyTime: return "指定なし"
        }
    }
}

/// 居酒屋系をどのように扱うかの絞り込みです。
enum IzakayaFilter: String, CaseIterable, Identifiable {
    case all
    case izakayaOnly
    case nonIzakayaOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "指定なし"
        case .izakayaOnly: return "居酒屋"
        case .nonIzakayaOnly: return "居酒屋以外"
        }
    }
}

enum UseScene: String, CaseIterable, Identifiable {
    case none
    case allYouCanEat
    case privateRoom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "指定なし"
        case .allYouCanEat: return "食べ放題"
        case .privateRoom: return "個室あり"
        }
    }
}

/// 利用用途の選択肢です。
enum UsageType: String, CaseIterable, Identifiable {
    case lunch
    case dinner
    case cafe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lunch: return "ランチ"
        case .dinner: return "ディナー"
        case .cafe: return "カフェ"
        }
    }
}

/// 予算帯の選択肢です。
enum BudgetOption: String, CaseIterable, Identifiable {
    case noLimit = ""
    case b001 = "B001"
    case b002 = "B002"
    case b003 = "B003"
    case b008 = "B008"
    case b004 = "B004"
    case b005 = "B005"
    case b006 = "B006"
    case b007 = "B007"
    case b009 = "B009"
    case b010 = "B010"
    case b011 = "B011"
    case b012 = "B012"
    case b013 = "B013"
    case b014 = "B014"
    case b015 = "B015"

    var id: String { rawValue }
    var code: String { rawValue }

    init?(code: String) {
        self.init(rawValue: code)
    }

    var label: String {
        switch self {
        case .noLimit: return "指定なし"
        case .b001: return "〜1000円"
        case .b002: return "〜1500円"
        case .b003: return "〜2000円"
        case .b008: return "〜3000円"
        case .b004: return "〜4000円"
        case .b005: return "〜5000円"
        case .b006: return "〜7000円"
        case .b007: return "〜10000円"
        case .b009: return "〜15000円"
        case .b010: return "〜20000円"
        case .b011: return "〜30000円"
        case .b012: return "30001円以上"
        case .b013: return "ランチ 〜500円"
        case .b014: return "ランチ 〜1000円"
        case .b015: return "ランチ 〜1500円"
        }
    }

    /// 検索UIで短く見せる表示名です。
    var shortLabel: String {
        switch self {
        case .noLimit: return "指定なし"
        case .b001: return "〜1,000"
        case .b002: return "〜1,500"
        case .b003: return "〜2,000"
        case .b008: return "〜3,000"
        case .b004: return "〜4,000"
        case .b005: return "〜5,000"
        case .b006: return "〜7,000"
        case .b007: return "〜10,000"
        case .b009: return "〜15,000"
        case .b010: return "〜20,000"
        case .b011: return "〜30,000"
        case .b012: return "30,001〜"
        case .b013: return "ランチ 〜500"
        case .b014: return "ランチ 〜1,000"
        case .b015: return "ランチ 〜1,500"
        }
    }

    /// 「〜◯円」選択の上限値です。指定なしはnilです。
    var maxYen: Int? {
        switch self {
        case .noLimit: return nil
        case .b001: return 1000
        case .b002: return 1500
        case .b003: return 2000
        case .b008: return 3000
        case .b004: return 4000
        case .b005: return 5000
        case .b006: return 7000
        case .b007: return 10000
        case .b009: return 15000
        case .b010: return 20000
        case .b011: return 30000
        case .b012: return nil
        case .b013: return 500
        case .b014: return 1000
        case .b015: return 1500
        }
    }
}

struct HotPepperAPIClient {
    private let baseURL = "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/"
    private let maxRangeMeters: Double = 3000

    /// 審査版や本番版でも読めるように、Bundle設定と開発用環境変数の両方からAPIキーを探します。
    private var apiKey: String? {
        if let bundledKey = Bundle.main.object(forInfoDictionaryKey: "HOTPEPPER_API_KEY") as? String {
            let trimmed = bundledKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let legacyBundledKey = Bundle.main.object(forInfoDictionaryKey: "HotPepperAPIKey") as? String {
            let trimmed = legacyBundledKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let environmentKey = ProcessInfo.processInfo.environment["HOTPEPPER_API_KEY"] ?? ""
        let trimmedEnvironmentKey = environmentKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedEnvironmentKey.isEmpty ? nil : trimmedEnvironmentKey
    }

    /// 店舗を検索します。
    func fetchShops(condition: ShopSearchCondition) async throws -> [Shop] {
        guard let apiKey else {
            throw HotPepperAPIError.missingAPIKey
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "count", value: "100")
        ]

        if !condition.composedKeyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: condition.composedKeyword))
        }
        if !condition.genre.code.isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: condition.genre.code))
        }

        // APIの最大レンジ(3km)で取得し、必要なら複数地点検索で範囲を広げる。
        queryItems.append(URLQueryItem(name: "range", value: "5"))

        if condition.requiresFreeFood {
            queryItems.append(URLQueryItem(name: "free_food", value: "1"))
        }
        if condition.requiresFreeDrink {
            queryItems.append(URLQueryItem(name: "free_drink", value: "1"))
        }
        if condition.requiresPrivateRoom {
            queryItems.append(URLQueryItem(name: "private_room", value: "1"))
        }
        if condition.requiresParking {
            queryItems.append(URLQueryItem(name: "parking", value: "1"))
        }
        if condition.requiresPet {
            queryItems.append(URLQueryItem(name: "pet", value: "1"))
        }

        switch condition.transport {
        case .train:
            guard let lat = condition.stationLatitude, let lng = condition.stationLongitude else {
                return try await fetchOnce(baseQueryItems: queryItems, latitude: nil, longitude: nil)
            }
            return try await fetchOnce(baseQueryItems: queryItems, latitude: lat, longitude: lng)
        case .walk, .car:
            guard let lat = condition.latitude, let lng = condition.longitude else {
                return try await fetchOnce(baseQueryItems: queryItems, latitude: nil, longitude: nil)
            }
            return try await fetchExpandedArea(baseQueryItems: queryItems, condition: condition, centerLat: lat, centerLng: lng)
        }
    }

    /// 店舗IDを指定して1件取得します。
    func fetchShop(id: String) async throws -> Shop? {
        guard let apiKey else {
            throw HotPepperAPIError.missingAPIKey
        }

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "count", value: "1")
        ]

        guard let url = components?.url else {
            throw HotPepperAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HotPepperAPIError.badResponse
        }

        do {
            let decoded = try JSONDecoder().decode(HotPepperResponse.self, from: data)
            return decoded.results.shop.first
        } catch let error as DecodingError {
            throw HotPepperAPIError.decodeFailed(describingDecodingError(error))
        } catch {
            throw error
        }
    }

    private func fetchExpandedArea(
        baseQueryItems: [URLQueryItem],
        condition: ShopSearchCondition,
        centerLat: Double,
        centerLng: Double
    ) async throws -> [Shop] {
        let desiredRadius = desiredRadiusMeters(for: condition)
        if desiredRadius <= maxRangeMeters {
            return try await fetchOnce(baseQueryItems: baseQueryItems, latitude: centerLat, longitude: centerLng)
        }

        var points: [(Double, Double)] = [(centerLat, centerLng)]
        points.append(contentsOf: ringPoints(centerLat: centerLat, centerLng: centerLng, radiusMeters: 2500, count: 8))
        if desiredRadius > 7000 {
            points.append(contentsOf: ringPoints(centerLat: centerLat, centerLng: centerLng, radiusMeters: 5000, count: 16))
        }

        var uniqueByID: [String: Shop] = [:]
        for (lat, lng) in points {
            let shops = try await fetchOnce(baseQueryItems: baseQueryItems, latitude: lat, longitude: lng)
            for shop in shops {
                uniqueByID[shop.id] = shop
            }
        }
        return Array(uniqueByID.values)
    }

    private func desiredRadiusMeters(for condition: ShopSearchCondition) -> Double {
        switch condition.transport {
        case .walk:
            return Double(max(condition.walkMaxMinutes, 1)) * 80.0
        case .car:
            return Double(max(condition.carMaxMinutes, 1)) * 500.0
        case .train:
            return maxRangeMeters
        }
    }

    private func ringPoints(centerLat: Double, centerLng: Double, radiusMeters: Double, count: Int) -> [(Double, Double)] {
        guard count > 0 else { return [] }
        let metersPerLat = 111_320.0
        let metersPerLng = 111_320.0 * cos(centerLat * .pi / 180.0)
        return (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * (2.0 * .pi)
            let dLat = (radiusMeters * sin(angle)) / metersPerLat
            let dLng = (radiusMeters * cos(angle)) / max(metersPerLng, 1.0)
            return (centerLat + dLat, centerLng + dLng)
        }
    }

    private func fetchOnce(
        baseQueryItems: [URLQueryItem],
        latitude: Double?,
        longitude: Double?
    ) async throws -> [Shop] {
        var components = URLComponents(string: baseURL)
        var queryItems = baseQueryItems
        if let latitude, let longitude {
            queryItems.append(URLQueryItem(name: "lat", value: String(latitude)))
            queryItems.append(URLQueryItem(name: "lng", value: String(longitude)))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw HotPepperAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HotPepperAPIError.badResponse
        }

        do {
            let decoded = try JSONDecoder().decode(HotPepperResponse.self, from: data)
            return decoded.results.shop
        } catch let error as DecodingError {
            throw HotPepperAPIError.decodeFailed(describingDecodingError(error))
        } catch {
            throw error
        }
    }

    /// 読み込みエラーの内容を短く整形します。
    private func describingDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "不足キー: \(key.stringValue) / \(context.debugDescription)"
        case .typeMismatch(_, let context):
            return "型不一致: \(context.debugDescription)"
        case .valueNotFound(_, let context):
            return "値不足: \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "データ破損: \(context.debugDescription)"
        @unknown default:
            return "不明な読み込みエラー"
        }
    }
}

enum HotPepperAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case badResponse
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが見つかりません。開発中はSchemeのEnvironment Variables、本番版はTargetのInfoでHOTPEPPER_API_KEYを設定してください。"
        case .invalidURL:
            return "検索URLの組み立てに失敗しました。"
        case .badResponse:
            return "サーバーから正しい応答が返りませんでした。"
        case .decodeFailed(let detail):
            return "受け取ったデータの読み込みに失敗しました。\(detail)"
        }
    }
}
