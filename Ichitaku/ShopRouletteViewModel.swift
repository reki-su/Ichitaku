import CoreLocation
import Foundation
import Observation

/// 一択表示とリロール回数管理を行うViewModelです。
@Observable
@MainActor
final class ShopRouletteViewModel {
    private let apiClient = HotPepperAPIClient()

    private(set) var shops: [Shop]
    private(set) var currentIndex: Int = 0
    private(set) var rerollCount: Int = 0
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    let maxRerollCount: Int

    init(shops: [Shop] = [], maxRerollCount: Int = 3) {
        self.shops = shops
        self.maxRerollCount = maxRerollCount
    }

    /// 現在表示対象の店舗を返します。
    var currentShop: Shop? {
        guard shops.indices.contains(currentIndex) else { return nil }
        return shops[currentIndex]
    }

    /// リロール可能回数の残りを返します。
    var remainingRerollCount: Int {
        max(maxRerollCount - rerollCount, 0)
    }

    /// 現在リロール可能かどうかを返します。
    var canReroll: Bool {
        remainingRerollCount > 0 && shops.indices.contains(currentIndex + 1)
    }

    /// 検索条件で店舗を取得し、一択用に並び替えて準備します。
    func searchShops(condition: ShopSearchCondition) async {
        isLoading = true
        errorMessage = nil

        do {
            if let prepared = try await fetchWithFallback(condition: condition) {
                applyPreparedShops(prepared)
            } else {
                shops = []
                currentIndex = 0
                rerollCount = 0
                errorMessage = "条件に合うお店が見つかりませんでした。条件をゆるめて再検索してください。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 追加通信なしで次の店舗へ切り替えます。
    func rerollShop() {
        guard canReroll else { return }
        currentIndex += 1
        rerollCount += 1
    }

    /// 画面側の入力変更時に表示エラーを消します。
    func clearError() {
        errorMessage = nil
    }

    /// 条件を段階的にゆるめながら店舗候補を取得します。
    private func fetchWithFallback(condition: ShopSearchCondition) async throws -> [Shop]? {
        var attempts: [ShopSearchCondition] = [condition]
        attempts.append(relaxedCondition(base: condition, removeOptionFilters: true))

        // 位置条件を外すフォールバックは駅検索時のみ許可する。
        if condition.transport == .train {
            attempts.append(conditionForTrain(base: condition, keepOnlyStationKeyword: true))
            attempts.append(conditionForTrain(base: condition, keepOnlyMainKeyword: true))
        } else if condition.transport == .car {
            // 車検索は最後に位置条件を外して広域検索を試す。
            attempts.append(relaxedCondition(base: condition, removeLocation: true, removeOptionFilters: true))
        } else if condition.transport == .walk {
            // 徒歩検索も最終的には位置条件を外して救済する。
            attempts.append(relaxedCondition(base: condition, removeLocation: true, removeOptionFilters: true))
        }

        for attempt in attempts {
            let fetched = try await apiClient.fetchShops(condition: attempt)
            if fetched.isEmpty { continue }

            let strictlyBudgeted = applyBudgetFilterIfNeeded(fetched, budgetCode: condition.budgetCode)
            if strictlyBudgeted.isEmpty { continue }

            let optionFiltered = applyOptionFilters(strictlyBudgeted, condition: condition)
            if optionFiltered.isEmpty { continue }

            let timeFiltered = applyTravelTimeFilter(optionFiltered, condition: attempt)
            if timeFiltered.isEmpty { continue }

            let keywordFiltered = filterByKeywordIfNeeded(timeFiltered, keyword: condition.keyword)
            if keywordFiltered.isEmpty { continue }

            let withPhoto = keywordFiltered.filter { $0.largePhotoURL != nil }
            let source = withPhoto.isEmpty ? keywordFiltered : withPhoto
            let deBiased = reduceIzakayaBiasIfNeeded(source, condition: condition)
            return prioritizeByKeyword(deBiased, keyword: condition.keyword)
        }

        return nil
    }

    /// 条件の一部を外したフォールバック条件を作ります。
    private func relaxedCondition(
        base: ShopSearchCondition,
        removeLocation: Bool = false,
        removeOptionFilters: Bool = false
    ) -> ShopSearchCondition {
        var copy = base
        if removeLocation {
            copy.latitude = nil
            copy.longitude = nil
        }
        if removeOptionFilters {
            copy.requiresFreeFood = false
            copy.requiresFreeDrink = false
            copy.requiresPrivateRoom = false
            copy.requiresParking = false
            copy.requiresOpenNow = false
            copy.requiresMidnight = false
            copy.requiresPet = false
        }
        return copy
    }

    /// 電車検索のフォールバック条件を作ります。
    private func conditionForTrain(
        base: ShopSearchCondition,
        keepOnlyStationKeyword: Bool = false,
        keepOnlyMainKeyword: Bool = false
    ) -> ShopSearchCondition {
        var copy = base
        copy.requiresFreeFood = false
        copy.requiresFreeDrink = false
        copy.requiresPrivateRoom = false
        copy.requiresParking = false
        copy.requiresOpenNow = false
        copy.requiresMidnight = false
        copy.requiresPet = false
        // 電車検索では位置情報を使わないため、念のためnilに統一。
        copy.latitude = nil
        copy.longitude = nil

        if keepOnlyStationKeyword {
            copy.keyword = ""
        }
        if keepOnlyMainKeyword {
            copy.stationKeyword = ""
        }

        return copy
    }

    /// 取得済み店舗を画面表示用に反映します。
    private func applyPreparedShops(_ prepared: [Shop]) {
        shops = prepared
        currentIndex = 0
        rerollCount = 0
    }

    /// 予算コードが指定されている場合、同じ予算コードのみを残します。
    private func applyBudgetFilterIfNeeded(_ shops: [Shop], budgetCode: String) -> [Shop] {
        guard !budgetCode.isEmpty else { return shops }
        guard let selected = BudgetOption(code: budgetCode),
              let maxYen = selected.maxYen else {
            return shops
        }

        return shops.filter { shop in
            // averageがあれば優先して判定。
            if let avg = parseAverageYen(shop.budget.average) {
                return avg <= maxYen
            }

            // averageがなければnameの上限で判定。
            if let upper = parseBudgetUpperYen(shop.budget.name) {
                return upper <= maxYen
            }

            // どちらも取れない場合は落としすぎ防止のため通す。
            return true
        }
    }

    /// オンオフ条件の絞り込みを適用します。
    private func applyOptionFilters(_ shops: [Shop], condition: ShopSearchCondition) -> [Shop] {
        shops.filter { shop in
            if condition.requiresFreeFood && shop.freeFood != "あり" { return false }
            if condition.requiresFreeDrink && shop.freeDrink != "あり" { return false }
            if condition.requiresPrivateRoom && shop.privateRoom != "あり" { return false }
            if condition.requiresParking && shop.parking != "あり" { return false }
            if condition.requiresMidnight && shop.midnight != "1" { return false }
            if condition.requiresPet && shop.pet != "可" && shop.pet != "あり" { return false }
            if condition.requiresOpenNow && !shop.isLikelyOpenNow() { return false }
            return true
        }
    }

    /// 「ディナー平均 3500円」などから数字だけ取り出します。
    private func parseAverageYen(_ text: String?) -> Int? {
        guard let text else { return nil }
        let digits = text.filter { $0.isNumber }
        return Int(digits)
    }

    /// 「2001～3000円」から上限を取り出します。
    private func parseBudgetUpperYen(_ text: String?) -> Int? {
        guard let text else { return nil }
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        for separator in ["～", "〜", "-", "－", "—", "–"] where cleaned.contains(separator) {
            let parts = cleaned.components(separatedBy: separator)
            if parts.count == 2 {
                let rightDigits = parts[1].filter { $0.isNumber }
                if let upper = Int(rightDigits), !rightDigits.isEmpty {
                    return upper
                }
            }
        }
        return nil
    }

    /// 入力キーワードに近い店舗を先頭に寄せます。同点はランダムに並べます。
    private func prioritizeByKeyword(_ shops: [Shop], keyword: String) -> [Shop] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return shops.shuffled() }

        let loweredKeyword = trimmed.lowercased()
        let grouped = Dictionary(grouping: shops) { shop in
            relevanceScore(for: shop, keyword: loweredKeyword)
        }

        let sortedScores = grouped.keys.sorted(by: >)
        var result: [Shop] = []
        for score in sortedScores {
            let items = grouped[score] ?? []
            result.append(contentsOf: items.shuffled())
        }
        return result
    }

    /// キーワード非一致の店舗を除外します。
    private func filterByKeywordIfNeeded(_ shops: [Shop], keyword: String) -> [Shop] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return shops }

        let tokens = trimmed
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return shops }

        return shops.filter { shop in
            let haystack = [
                shop.name,
                shop.shopCatch ?? "",
                shop.genre?.name ?? "",
                shop.address ?? "",
                shop.mobileAccess ?? ""
            ]
            .joined(separator: " ")
            .lowercased()

            // 入力した全トークンがどこかに含まれる店だけ残す（AND条件）。
            return tokens.allSatisfy { haystack.contains($0) }
        }
    }

    private func relevanceScore(for shop: Shop, keyword: String) -> Int {
        var score = 0
        let targets = [
            shop.name.lowercased(),
            (shop.shopCatch ?? "").lowercased(),
            (shop.genre?.name ?? "").lowercased()
        ]
        for target in targets {
            if target == keyword { score += 5 }
            if target.contains(keyword) { score += 3 }
        }
        return score
    }

    /// キーワード検索時に居酒屋へ偏りすぎるのを抑えます。
    private func reduceIzakayaBiasIfNeeded(_ shops: [Shop], condition: ShopSearchCondition) -> [Shop] {
        let trimmedKeyword = condition.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return shops }
        guard condition.genre == .all else { return shops } // ジャンル指定時はそのまま尊重

        let loweredKeyword = trimmedKeyword.lowercased()
        let izakayaHintWords = ["居酒屋", "飲み", "酒", "bar", "バー"]
        let userWantsIzakaya = izakayaHintWords.contains { loweredKeyword.contains($0) }
        if userWantsIzakaya { return shops }

        let nonIzakaya = shops.filter { !($0.genre?.name ?? "").contains("居酒屋") }
        let izakaya = shops.filter { ($0.genre?.name ?? "").contains("居酒屋") }

        // 非居酒屋が十分あるなら非居酒屋のみ採用（料理キーワード優先）
        if nonIzakaya.count >= 4 {
            return nonIzakaya
        }
        // 非居酒屋が少ないときは居酒屋も混ぜるが、最大2件に抑える
        return nonIzakaya + Array(izakaya.prefix(2))
    }

    /// 移動手段ごとの所要時間で絞り込みます。
    private func applyTravelTimeFilter(_ shops: [Shop], condition: ShopSearchCondition) -> [Shop] {
        switch condition.transport {
        case .walk:
            guard let lat = condition.latitude, let lng = condition.longitude else { return shops }
            return shops.filter { shop in
                guard let shopLat = shop.lat, let shopLng = shop.lng else { return false }
                let minutes = travelMinutes(
                    fromLat: lat, fromLng: lng,
                    toLat: shopLat, toLng: shopLng,
                    speedMetersPerMinute: 80
                )
                return minutes <= max(condition.walkMaxMinutes, 1)
            }
        case .car:
            guard let lat = condition.latitude, let lng = condition.longitude else { return shops }
            return shops.filter { shop in
                guard let shopLat = shop.lat, let shopLng = shop.lng else { return false }
                let minutes = travelMinutes(
                    fromLat: lat, fromLng: lng,
                    toLat: shopLat, toLng: shopLng,
                    speedMetersPerMinute: 500
                )
                return minutes <= max(condition.carMaxMinutes, 1)
            }
        case .train:
            guard let lat = condition.stationLatitude, let lng = condition.stationLongitude else { return shops }
            return shops.filter { shop in
                guard let shopLat = shop.lat, let shopLng = shop.lng else { return false }
                let minutes = travelMinutes(
                    fromLat: lat, fromLng: lng,
                    toLat: shopLat, toLng: shopLng,
                    speedMetersPerMinute: 80
                )
                return minutes <= max(condition.trainMaxMinutes, 1)
            }
        }
    }

    private func travelMinutes(
        fromLat: Double,
        fromLng: Double,
        toLat: Double,
        toLng: Double,
        speedMetersPerMinute: Double
    ) -> Int {
        let from = CLLocation(latitude: fromLat, longitude: fromLng)
        let to = CLLocation(latitude: toLat, longitude: toLng)
        let distance = from.distance(from: to)
        return max(Int((distance / speedMetersPerMinute).rounded()), 1)
    }

}
