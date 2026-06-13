import Foundation

/// ホットペッパーAPIの店舗情報を扱うデータモデルです。
struct Shop: Codable, Identifiable {
    let id: String
    let name: String
    let logoImage: String?
    let budget: Budget
    let genre: Genre?
    let shopCatch: String?
    let mobileAccess: String?
    let open: String?
    let midnight: String?
    let privateRoom: String?
    let freeFood: String?
    let freeDrink: String?
    let parking: String?
    let pet: String?
    let address: String?
    let stationName: String?
    let lat: Double?
    let lng: Double?
    let photo: Photo?
    let urls: ShopURLs?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logoImage = "logo_image"
        case budget
        case genre
        case shopCatch = "catch"
        case mobileAccess = "mobile_access"
        case open
        case midnight
        case privateRoom = "private_room"
        case freeFood = "free_food"
        case freeDrink = "free_drink"
        case parking
        case pet
        case address
        case stationName = "station_name"
        case lat
        case lng
        case photo
        case urls
    }

    init(
        id: String,
        name: String,
        logoImage: String?,
        budget: Budget,
        genre: Genre?,
        shopCatch: String?,
        mobileAccess: String?,
        open: String?,
        midnight: String?,
        privateRoom: String?,
        freeFood: String?,
        freeDrink: String?,
        parking: String?,
        pet: String?,
        address: String?,
        stationName: String?,
        lat: Double?,
        lng: Double?,
        photo: Photo?,
        urls: ShopURLs?
    ) {
        self.id = id
        self.name = name
        self.logoImage = logoImage
        self.budget = budget
        self.genre = genre
        self.shopCatch = shopCatch
        self.mobileAccess = mobileAccess
        self.open = open
        self.midnight = midnight
        self.privateRoom = privateRoom
        self.freeFood = freeFood
        self.freeDrink = freeDrink
        self.parking = parking
        self.pet = pet
        self.address = address
        self.stationName = stationName
        self.lat = lat
        self.lng = lng
        self.photo = photo
        self.urls = urls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        logoImage = try container.decodeIfPresent(String.self, forKey: .logoImage)
        budget = try container.decodeIfPresent(Budget.self, forKey: .budget) ?? Budget(code: nil, name: nil, average: nil)
        genre = try container.decodeIfPresent(Genre.self, forKey: .genre)
        shopCatch = try container.decodeIfPresent(String.self, forKey: .shopCatch)
        mobileAccess = try container.decodeIfPresent(String.self, forKey: .mobileAccess)
        open = try container.decodeIfPresent(String.self, forKey: .open)
        midnight = try container.decodeIfPresent(String.self, forKey: .midnight)
        privateRoom = try container.decodeIfPresent(String.self, forKey: .privateRoom)
        freeFood = try container.decodeIfPresent(String.self, forKey: .freeFood)
        freeDrink = try container.decodeIfPresent(String.self, forKey: .freeDrink)
        parking = try container.decodeIfPresent(String.self, forKey: .parking)
        pet = try container.decodeIfPresent(String.self, forKey: .pet)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        stationName = try container.decodeIfPresent(String.self, forKey: .stationName)
        lat = Shop.decodeDoubleIfPresent(from: container, key: .lat)
        lng = Shop.decodeDoubleIfPresent(from: container, key: .lng)
        photo = try container.decodeIfPresent(Photo.self, forKey: .photo)
        urls = try container.decodeIfPresent(ShopURLs.self, forKey: .urls)
    }

    private static func decodeDoubleIfPresent(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decode(String.self, forKey: key) {
            return Double(text)
        }
        return nil
    }

    /// 画面表示で使う大きい店舗写真URLです。
    var largePhotoURL: URL? {
        let rawURL = photo?.pc.large ?? photo?.pc.medium
        guard let rawURL else { return nil }
        return URL(string: rawURL)
    }

    /// 画面表示で使うロゴ画像URLです。
    var logoURL: URL? {
        guard let logoImage else { return nil }
        return URL(string: logoImage)
    }

    /// 外部マップへ遷移するためのURLです。
    var mapAppURL: URL? {
        let query = [name, address].compactMap { $0 }.joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        if let lat, let lng, let encoded {
            return URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(encoded)")
        }
        if let encoded {
            return URL(string: "http://maps.apple.com/?q=\(encoded)")
        }
        if let lat, let lng {
            return URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)")
        }
        return nil
    }

    /// ホットペッパーの店舗詳細ページURLです。
    var hotPepperURL: URL? {
        guard let text = urls?.pc, !text.isEmpty else { return nil }
        return URL(string: text)
    }

    /// 現在時刻で営業中かどうかを簡易判定します。
    func isLikelyOpenNow(at date: Date = Date()) -> Bool {
        guard let openText = open, !openText.isEmpty else { return true }
        if openText.contains("24時間") { return true }

        let pattern = #"(\d{1,2}):(\d{2})\s*-\s*(翌)?(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return true }
        let calendar = Calendar.current
        let weekSymbols = ["日", "月", "火", "水", "木", "金", "土"]
        let todayIndex = calendar.component(.weekday, from: date) - 1
        let todaySymbol = weekSymbols[max(0, min(todayIndex, 6))]
        let nowHour = calendar.component(.hour, from: date)
        let nowMinute = calendar.component(.minute, from: date)
        let nowTotal = nowHour * 60 + nowMinute

        let segments = openText
            .components(separatedBy: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var foundApplicableSegment = false
        var foundParsableHours = false

        for segment in segments {
            if !segmentAppliesToday(segment, todaySymbol: todaySymbol, weekSymbols: weekSymbols) { continue }
            foundApplicableSegment = true
            let nsText = segment as NSString
            let matches = regex.matches(in: segment, range: NSRange(location: 0, length: nsText.length))
            if matches.isEmpty { continue }
            foundParsableHours = true

            for match in matches {
                guard match.numberOfRanges >= 6 else { continue }
                let startHour = Int(nsText.substring(with: match.range(at: 1))) ?? 0
                let startMinute = Int(nsText.substring(with: match.range(at: 2))) ?? 0
                let hasNextDay = match.range(at: 3).location != NSNotFound
                let endHourRaw = Int(nsText.substring(with: match.range(at: 4))) ?? 0
                let endMinute = Int(nsText.substring(with: match.range(at: 5))) ?? 0

                let startTotal = startHour * 60 + startMinute
                var endTotal = endHourRaw * 60 + endMinute

                if hasNextDay || endTotal < startTotal {
                    endTotal += 24 * 60
                }

                let nowCandidates = [nowTotal, nowTotal + 24 * 60]
                if nowCandidates.contains(where: { $0 >= startTotal && $0 <= endTotal }) {
                    return true
                }
            }
        }

        // 今日の営業時間表記を読めない店は落としすぎないよう通す
        if !foundApplicableSegment || !foundParsableHours {
            return true
        }

        return false
    }

    private func segmentAppliesToday(_ segment: String, todaySymbol: String, weekSymbols: [String]) -> Bool {
        guard let colonIndex = segment.firstIndex(of: ":") else { return true }
        let dayPart = segment[..<colonIndex].trimmingCharacters(in: .whitespaces)
        if dayPart.isEmpty { return true }
        if dayPart.contains("毎日") || dayPart.contains("全日") { return true }
        if dayPart.contains("祝前日") { return true }

        if dayPart.contains("-") {
            let parts = dayPart.components(separatedBy: "-")
            if parts.count == 2 {
                let start = String(parts[0].suffix(1))
                let end = String(parts[1].prefix(1))
                if let s = weekSymbols.firstIndex(of: start), let e = weekSymbols.firstIndex(of: end), let t = weekSymbols.firstIndex(of: todaySymbol) {
                    if s <= e { return t >= s && t <= e }
                    return t >= s || t <= e
                }
            }
        }

        return dayPart.contains(todaySymbol)
    }

    /// アクセス文から駅近かどうかを簡易判定します。
    func isNearStation(maxMinutes: Int = 5) -> Bool {
        guard let mobileAccess, !mobileAccess.isEmpty else { return false }
        guard mobileAccess.contains("徒歩") else { return false }

        let pattern = #"徒歩\s*(\d+)\s*分"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let nsText = mobileAccess as NSString
        let matches = regex.matches(in: mobileAccess, range: NSRange(location: 0, length: nsText.length))
        for match in matches where match.numberOfRanges >= 2 {
            let value = nsText.substring(with: match.range(at: 1))
            if let minutes = Int(value), minutes <= maxMinutes {
                return true
            }
        }
        return false
    }

    /// デザイン確認用のモックデータです。
    static let mockShops: [Shop] = [
        Shop(
            id: "J001000001",
            name: "炭火ビストロ 夜風",
            logoImage: "https://images.unsplash.com/photo-1559339352-11d035aa65de?w=200",
            budget: Budget(code: "B004", name: "3001～4000円", average: "ディナー平均 3500円"),
            genre: Genre(name: "居酒屋"),
            shopCatch: "終電までゆったり過ごせる炭火ビストロ",
            mobileAccess: "渋谷駅 徒歩4分",
            open: "月-木: 17:00-23:30 / 金土: 17:00-翌2:00",
            midnight: "1",
            privateRoom: "あり",
            freeFood: "なし",
            freeDrink: "あり",
            parking: "なし",
            pet: "不可",
            address: "東京都渋谷区道玄坂2-10-12",
            stationName: "渋谷",
            lat: 35.658034,
            lng: 139.701636,
            photo: Photo(pc: PhotoPC(large: "https://images.unsplash.com/photo-1552566626-52f8b828add9?w=1200", medium: nil)),
            urls: nil
        ),
        Shop(
            id: "J001000002",
            name: "キーマ研究所スタンド",
            logoImage: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=200",
            budget: Budget(code: "B008", name: "2001～3000円", average: "ディナー平均 2600円"),
            genre: Genre(name: "ダイニングバー"),
            shopCatch: "スパイス料理とクラフトドリンク",
            mobileAccess: "新橋駅 徒歩3分",
            open: "毎日: 11:30-23:00",
            midnight: "0",
            privateRoom: "なし",
            freeFood: "あり",
            freeDrink: "あり",
            parking: "あり",
            pet: "可",
            address: "東京都港区新橋1-8-3",
            stationName: "新橋",
            lat: 35.665498,
            lng: 139.75964,
            photo: Photo(pc: PhotoPC(large: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200", medium: nil)),
            urls: nil
        ),
        Shop(
            id: "J001000003",
            name: "終電レスキュー酒場",
            logoImage: "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=200",
            budget: Budget(code: "B004", name: "3001～4000円", average: "ディナー平均 3800円"),
            genre: Genre(name: "創作料理"),
            shopCatch: "深夜3時まで営業の2次会向け酒場",
            mobileAccess: "新宿駅 徒歩6分",
            open: "毎日: 18:00-翌3:00",
            midnight: "1",
            privateRoom: "あり",
            freeFood: "あり",
            freeDrink: "あり",
            parking: "なし",
            pet: "不可",
            address: "東京都新宿区歌舞伎町1-5-7",
            stationName: "新宿",
            lat: 35.69384,
            lng: 139.703549,
            photo: Photo(pc: PhotoPC(large: "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200", medium: nil)),
            urls: nil
        ),
        Shop(
            id: "J001000004",
            name: "駅前グリル航路",
            logoImage: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=200",
            budget: Budget(code: "B005", name: "4001～5000円", average: "ディナー平均 4200円"),
            genre: Genre(name: "イタリアン・フレンチ"),
            shopCatch: "肉料理メインの大人向けグリル",
            mobileAccess: "東京駅 徒歩2分",
            open: "月-土: 17:30-24:00",
            midnight: "0",
            privateRoom: "あり",
            freeFood: "なし",
            freeDrink: "なし",
            parking: "あり",
            pet: "可",
            address: "東京都千代田区丸の内1-9-1",
            stationName: "東京",
            lat: 35.681236,
            lng: 139.767125,
            photo: Photo(pc: PhotoPC(large: "https://images.unsplash.com/photo-1424847651672-bf20a4b0982b?w=1200", medium: nil)),
            urls: nil
        )
    ]
}

/// 予算情報を扱うデータモデルです。
struct Budget: Codable {
    let code: String?
    let name: String?
    let average: String?
}

/// ジャンル情報を扱うデータモデルです。
struct Genre: Codable {
    let name: String?
}

/// 写真情報を扱うデータモデルです。
struct Photo: Codable {
    let pc: PhotoPC
}

/// PC向け写真URLを扱うデータモデルです。
struct PhotoPC: Codable {
    let large: String?
    let medium: String?

    enum CodingKeys: String, CodingKey {
        case large = "l"
        case medium = "m"
    }
}

/// ホットペッパー詳細ページURLを扱うデータモデルです。
struct ShopURLs: Codable {
    let pc: String?
}

/// ホットペッパーAPIレスポンス全体を受けるデータモデルです。
struct HotPepperResponse: Codable {
    let results: HotPepperResults
}

/// APIレスポンス内の検索結果情報を受けるデータモデルです。
struct HotPepperResults: Codable {
    let available: Int?
    let returned: String?
    let start: Int?
    let shop: [Shop]

    enum CodingKeys: String, CodingKey {
        case available
        case returned
        case start
        case shop
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decodeIfPresent(Int.self, forKey: .available)
        returned = try container.decodeIfPresent(String.self, forKey: .returned)
        if let intStart = try? container.decode(Int.self, forKey: .start) {
            start = intStart
        } else if let stringStart = try? container.decode(String.self, forKey: .start) {
            start = Int(stringStart)
        } else {
            start = nil
        }
        shop = try container.decodeIfPresent([Shop].self, forKey: .shop) ?? []
    }
}
