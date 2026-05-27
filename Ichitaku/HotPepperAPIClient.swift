import Foundation

/// 検索条件をまとめて扱うデータです。
struct ShopSearchCondition {
    var keyword: String = ""
    var stationKeyword: String = ""
    var budgetCode: String = ""
    var peopleCount: Int = 2
    var usage: UsageType = .dinner
    var scene: UseScene = .none
    var businessStatus: BusinessStatus = .openNow
    var izakayaFilter: IzakayaFilter = .all
    var transport: TransportOption = .walk
    var latitude: Double?
    var longitude: Double?
    var stationLatitude: Double?
    var stationLongitude: Double?
    var walkMaxMinutes: Int = 15
    var carMaxMinutes: Int = 30

    /// APIに渡すキーワードを組み立てます。
    var composedKeyword: String {
        var words: [String] = []

        if !keyword.isEmpty {
            words.append(keyword)
        }

        return words.joined(separator: " ")
    }

    /// 検索条件を短く表示するための文言です。
    var summaryChips: [String] {
        var chips: [String] = ["人数: \(peopleCount)人", "移動: \(transport.label)"]
        if transport == .walk {
            chips.append("徒歩\(walkMaxMinutes)分以内")
        } else if transport == .car {
            chips.append("車\(carMaxMinutes)分以内")
        }

        if transport == .train && !stationKeyword.isEmpty {
            chips.append("駅周辺: \(stationKeyword)")
        }

        if !budgetCode.isEmpty {
            chips.append("予算: \(BudgetOption(code: budgetCode)?.label ?? budgetCode)")
        }
        chips.append("用途: \(usage.label)")

        if !keyword.isEmpty {
            chips.append("キーワード: \(keyword)")
        }

        if scene != .none {
            chips.append("シーン: \(scene.label)")
        }
        chips.append("営業: \(businessStatus.label)")
        chips.append("業態: \(izakayaFilter.label)")

        return chips
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

    /// 店舗を検索します。
    func fetchShops(condition: ShopSearchCondition) async throws -> [Shop] {
        let apiKey = ProcessInfo.processInfo.environment["HOTPEPPER_API_KEY"] ?? ""
        guard !apiKey.isEmpty else {
            throw HotPepperAPIError.missingAPIKey
        }

        var components = URLComponents(string: baseURL)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "count", value: "100")
        ]

        if !condition.composedKeyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: condition.composedKeyword))
        }

        switch condition.transport {
        case .walk:
            queryItems.append(URLQueryItem(name: "range", value: "3"))
        case .car:
            queryItems.append(URLQueryItem(name: "range", value: "5"))
        case .train:
            // 駅検索は少し広めに取る（API仕様上の最大レンジ）。
            queryItems.append(URLQueryItem(name: "range", value: "5"))
            break
        }

        switch condition.transport {
        case .walk, .car:
            if let lat = condition.latitude, let lng = condition.longitude {
                queryItems.append(URLQueryItem(name: "lat", value: String(lat)))
                queryItems.append(URLQueryItem(name: "lng", value: String(lng)))
            }
        case .train:
            if let lat = condition.stationLatitude, let lng = condition.stationLongitude {
                queryItems.append(URLQueryItem(name: "lat", value: String(lat)))
                queryItems.append(URLQueryItem(name: "lng", value: String(lng)))
            }
        }

        switch condition.scene {
        case .none:
            break
        case .allYouCanEat:
            queryItems.append(URLQueryItem(name: "free_food", value: "1"))
        case .privateRoom:
            queryItems.append(URLQueryItem(name: "private_room", value: "1"))
        }

        if condition.usage == .lunch {
            queryItems.append(URLQueryItem(name: "lunch", value: "1"))
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
            return "APIキーが見つかりません。XcodeのSchemeのEnvironment VariablesにHOTPEPPER_API_KEYを設定してください。"
        case .invalidURL:
            return "検索URLの組み立てに失敗しました。"
        case .badResponse:
            return "サーバーから正しい応答が返りませんでした。"
        case .decodeFailed(let detail):
            return "受け取ったデータの読み込みに失敗しました。\(detail)"
        }
    }
}
