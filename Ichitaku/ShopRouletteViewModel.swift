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
        attempts.append(relaxedCondition(base: condition, removeScene: true))
        attempts.append(relaxedCondition(base: condition, removeScene: true, removeBusinessStatus: true))
        attempts.append(relaxedCondition(base: condition, removeScene: true, removeBusinessStatus: true, removeIzakayaFilter: true))

        // 位置条件を外すフォールバックは駅検索時のみ許可する。
        if condition.transport == .train {
            attempts.append(conditionForTrain(base: condition, keepOnlyStationKeyword: true))
            attempts.append(conditionForTrain(base: condition, keepOnlyMainKeyword: true))
        } else if condition.transport == .car {
            // 車検索は最後に位置条件を外して広域検索を試す。
            attempts.append(relaxedCondition(base: condition, removeScene: true, removeLocation: true, removeBusinessStatus: true, removeIzakayaFilter: true))
        } else if condition.transport == .walk {
            // 徒歩検索も最終的には位置条件を外して救済する。
            attempts.append(relaxedCondition(base: condition, removeScene: true, removeLocation: true, removeBusinessStatus: true, removeIzakayaFilter: true))
        }

        for attempt in attempts {
            let fetched = try await apiClient.fetchShops(condition: attempt)
            if fetched.isEmpty { continue }

            let strictlyBudgeted = applyBudgetFilterIfNeeded(fetched, budgetCode: condition.budgetCode)
            if strictlyBudgeted.isEmpty { continue }

            let openFiltered: [Shop]
            if condition.businessStatus == .openNow {
                openFiltered = strictlyBudgeted.filter { $0.isLikelyOpenNow() }
            } else {
                openFiltered = strictlyBudgeted
            }
            if openFiltered.isEmpty { continue }

            let genreFiltered = applyIzakayaFilter(openFiltered, filter: condition.izakayaFilter)
            if genreFiltered.isEmpty { continue }

            let timeFiltered = applyTravelTimeFilter(genreFiltered, condition: attempt)
            if timeFiltered.isEmpty { continue }

            let withPhoto = timeFiltered.filter { $0.largePhotoURL != nil }
            let source = withPhoto.isEmpty ? timeFiltered : withPhoto
            return prioritizeByKeyword(source, keyword: condition.keyword)
        }

        return nil
    }

    /// 条件の一部を外したフォールバック条件を作ります。
    private func relaxedCondition(
        base: ShopSearchCondition,
        removeScene: Bool = false,
        removeLocation: Bool = false,
        removeBusinessStatus: Bool = false,
        removeIzakayaFilter: Bool = false
    ) -> ShopSearchCondition {
        var copy = base
        if removeScene {
            copy.scene = .none
        }
        if removeBusinessStatus {
            copy.businessStatus = .anyTime
        }
        if removeIzakayaFilter {
            copy.izakayaFilter = .all
        }
        if removeLocation {
            copy.latitude = nil
            copy.longitude = nil
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
        copy.scene = .none
        copy.businessStatus = .anyTime
        copy.izakayaFilter = .all
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

    /// 居酒屋絞り込みを適用します。
    private func applyIzakayaFilter(_ shops: [Shop], filter: IzakayaFilter) -> [Shop] {
        switch filter {
        case .all:
            return shops
        case .izakayaOnly:
            return shops.filter { ($0.genre?.name ?? "").contains("居酒屋") }
        case .nonIzakayaOnly:
            return shops.filter { !($0.genre?.name ?? "").contains("居酒屋") }
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
                return minutes <= 15
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
                return minutes <= 30
            }
        case .train:
            return shops
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
