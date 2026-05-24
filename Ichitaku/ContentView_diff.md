// =============================================================
// ContentView.swift の変更箇所まとめ
// =============================================================
// 変更は3か所です。追加行に ★ コメントを付けています。

// ─────────────────────────────────────────
// 【変更1】ContentView の @State に1行追加
// ─────────────────────────────────────────

// 既存
@State private var stationKeyword: String = ""

// ★ 追加（この行を stationKeyword のすぐ下に追加）
@State private var stationCoordinate: CLLocationCoordinate2D? = nil


// ─────────────────────────────────────────
// 【変更2】SearchConditionView の呼び出しに引数を追加
// ─────────────────────────────────────────

// 既存
SearchConditionView(
    selectedTransport: $selectedTransport,
    selectedUsage: $selectedUsage,
    selectedScene: $selectedScene,
    selectedBusinessStatus: $selectedBusinessStatus,
    selectedIzakayaFilter: $selectedIzakayaFilter,
    selectedBudget: $selectedBudget,
    peopleCount: $peopleCount,
    keyword: $keyword,
    stationKeyword: $stationKeyword,
    isLoading: viewModel.isLoading,
    onSearch: performSearch
)

// ★ stationKeyword の次に stationCoordinate を追加
SearchConditionView(
    selectedTransport: $selectedTransport,
    selectedUsage: $selectedUsage,
    selectedScene: $selectedScene,
    selectedBusinessStatus: $selectedBusinessStatus,
    selectedIzakayaFilter: $selectedIzakayaFilter,
    selectedBudget: $selectedBudget,
    peopleCount: $peopleCount,
    keyword: $keyword,
    stationKeyword: $stationKeyword,
    stationCoordinate: $stationCoordinate,  // ★ 追加
    isLoading: viewModel.isLoading,
    onSearch: performSearch
)


// ─────────────────────────────────────────
// 【変更3】performSearch() の電車処理を差し替え
// ─────────────────────────────────────────

// 既存（削除）
if selectedTransport == .train {
    let currentLocation: CLLocation?
    if let lat = locationService.latitude, let lng = locationService.longitude {
        currentLocation = CLLocation(latitude: lat, longitude: lng)
    } else {
        currentLocation = nil
    }

    let stationCoordinate = await stationResolver.resolve(
        stationName: stationKeyword,
        near: currentLocation
    )
    condition.stationLatitude = stationCoordinate?.latitude
    condition.stationLongitude = stationCoordinate?.longitude
}

// ★ 差し替え後
if selectedTransport == .train {
    if let coord = stationCoordinate {
        // サジェストで選択済みの座標をそのまま使う（精度が高い）
        condition.stationLatitude = coord.latitude
        condition.stationLongitude = coord.longitude
    } else {
        // 手入力のままの場合のみジオコーディングにフォールバック
        let currentLocation: CLLocation?
        if let lat = locationService.latitude, let lng = locationService.longitude {
            currentLocation = CLLocation(latitude: lat, longitude: lng)
        } else {
            currentLocation = nil
        }
        let resolved = await stationResolver.resolve(
            stationName: stationKeyword,
            near: currentLocation
        )
        if resolved == nil {
            formErrorMessage = "駅「\(stationKeyword)」の位置を特定できませんでした。候補から選ぶか、駅名を正確に入力してください。"
            isLoading = false
            return
        }
        condition.stationLatitude = resolved?.latitude
        condition.stationLongitude = resolved?.longitude
    }
}


// ─────────────────────────────────────────
// 【変更4】SearchConditionView の定義に @Binding を追加
// ─────────────────────────────────────────

// 既存
struct SearchConditionView: View {
    @Binding var selectedTransport: TransportOption
    // ... 略 ...
    @Binding var stationKeyword: String
    let isLoading: Bool
    let onSearch: () -> Void

// ★ stationKeyword の下に1行追加
    @Binding var stationCoordinate: CLLocationCoordinate2D?  // ★ 追加


// ─────────────────────────────────────────
// 【変更5】SearchConditionView 内の駅名 TextField を差し替え
// ─────────────────────────────────────────

// 既存（削除）
if selectedTransport == .train {
    TextField("駅名（例: 渋谷）", text: $stationKeyword)
        .textFieldStyle(.roundedBorder)
}

// ★ 差し替え後
if selectedTransport == .train {
    StationSearchField(stationKeyword: $stationKeyword) { name, coordinate in
        stationKeyword = name
        stationCoordinate = coordinate  // 選択時に座標を確定保存
    }
    .onChange(of: stationKeyword) { _, _ in
        // テキストが手動編集されたら保存済み座標をリセット
        stationCoordinate = nil
    }
}
