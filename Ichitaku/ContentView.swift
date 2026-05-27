import CoreLocation
import SwiftUI

// MARK: - Design Tokens（和紙・活版印刷テーマ）

private extension Color {
    /// 和紙の地色
    static let wasiBackground   = Color(red: 0.961, green: 0.941, blue: 0.910)
    /// カード面
    static let wasiSurface      = Color(red: 1.000, green: 0.992, blue: 0.973)
    /// 罫線・区切り
    static let wasiBorder       = Color(red: 0.784, green: 0.749, blue: 0.690)
    /// 墨色テキスト
    static let wasiInk          = Color(red: 0.165, green: 0.125, blue: 0.094)
    /// 薄墨
    static let wasiInkLight     = Color(red: 0.165, green: 0.125, blue: 0.094).opacity(0.50)
    /// 焦げ茶アクセント
    static let wasiAccent       = Color(red: 0.545, green: 0.392, blue: 0.251)
    /// アクセント薄め（タグ背景など）
    static let wasiAccentLight  = Color(red: 0.941, green: 0.894, blue: 0.816)
    /// 朱色（決定・強調）
    static let wasiVermilion    = Color(red: 0.722, green: 0.196, blue: 0.118)
}

private extension Font {
    /// 見出し：セリフ体
    static func wasiDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// 本文
    static func wasiBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var viewModel = ShopRouletteViewModel()
    @State private var locationService = LocationService()
    private let stationResolver = StationResolver()

    @State private var selectedTransport: TransportOption = .walk
    @State private var selectedUsage: UsageType = .dinner
    @State private var selectedScene: UseScene = .none
    @State private var selectedBusinessStatus: BusinessStatus = .openNow
    @State private var selectedIzakayaFilter: IzakayaFilter = .all
    @State private var selectedBudget: BudgetOption = .noLimit
    @State private var peopleCount: Int = 2
    @State private var keyword: String = ""
    @State private var stationKeyword: String = ""
    @State private var stationCoordinate: CLLocationCoordinate2D? = nil
    @State private var walkMaxMinutes: Int = 15
    @State private var carMaxMinutes: Int = 30
    @State private var lastCondition: ShopSearchCondition?
    @State private var showingResult: Bool = false
    @State private var formErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wasiBackground.ignoresSafeArea()
                // 和紙の微細なテクスチャ感を出す薄いオーバーレイ
                Rectangle()
                    .fill(Color.wasiInk.opacity(0.018))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // ── ロゴヘッダー ──
                        WasiHeaderView()

                        // ── 現在地メッセージ ──
                        if let locationMessage = locationMessageForCurrentTransport {
                            WasiNoticeView(message: locationMessage, icon: "location.fill")
                        }

                        // ── 検索フォーム ──
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
                            stationCoordinate: $stationCoordinate,
                            walkMaxMinutes: $walkMaxMinutes,
                            carMaxMinutes: $carMaxMinutes,
                            isLoading: viewModel.isLoading,
                            onSearch: performSearch,
                            onReset: resetSearchConditions,
                            onFormEdit: clearFormError
                        )

                        // ── 直前の検索条件チップ ──
                        if let condition = lastCondition {
                            SearchChipsView(chips: condition.summaryChips)
                        }

                        // ── エラー表示 ──
                        if let msg = viewModel.errorMessage {
                            WasiNoticeView(message: msg, icon: "exclamationmark.circle", isError: true)
                        }
                        if let msg = formErrorMessage {
                            WasiNoticeView(message: msg, icon: "exclamationmark.circle", isError: true)
                        }

                        NavigationLink(isActive: $showingResult) {
                            SearchResultView(
                                viewModel: viewModel,
                                selectedTransport: selectedTransport,
                                currentLatitude: locationService.latitude,
                                currentLongitude: locationService.longitude
                            )
                        } label: { EmptyView() }
                        .hidden()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .task { locationService.startUpdatingLocation() }
            .navigationBarHidden(true)
            .onChange(of: selectedTransport)      { _, _ in clearFormError() }
            .onChange(of: selectedUsage)          { _, _ in clearFormError() }
            .onChange(of: selectedScene)          { _, _ in clearFormError() }
            .onChange(of: selectedBusinessStatus) { _, _ in clearFormError() }
            .onChange(of: selectedIzakayaFilter)  { _, _ in clearFormError() }
            .onChange(of: selectedBudget)         { _, _ in clearFormError() }
            .onChange(of: peopleCount)            { _, _ in clearFormError() }
            .onChange(of: keyword)                { _, _ in clearFormError() }
            .onChange(of: stationKeyword)         { _, _ in clearFormError() }
            .onChange(of: walkMaxMinutes)         { _, _ in clearFormError() }
            .onChange(of: carMaxMinutes)          { _, _ in clearFormError() }
        }
    }

    private var locationMessageForCurrentTransport: String? {
        if selectedTransport == .walk || selectedTransport == .car {
            return locationService.locationStatusMessage
        }
        return nil
    }

    private func performSearch() {
        if selectedTransport == .train && stationKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formErrorMessage = "電車・駅を使うときは駅名を入れてください。"
            return
        }
        let needsLocation = selectedTransport == .walk || selectedTransport == .car
        let hasLocation   = locationService.latitude != nil && locationService.longitude != nil
        if needsLocation && !hasLocation {
            formErrorMessage = "現在地がまだ取れていません。数秒待ってもう一度検索してください。"
            locationService.startUpdatingLocation()
            return
        }
        Task {
            formErrorMessage = nil
            var condition = ShopSearchCondition(
                keyword: keyword,
                stationKeyword: stationKeyword,
                budgetCode: selectedBudget.code,
                peopleCount: peopleCount,
                usage: selectedUsage,
                scene: selectedScene,
                businessStatus: selectedBusinessStatus,
                izakayaFilter: selectedIzakayaFilter,
                transport: selectedTransport,
                latitude: locationService.latitude,
                longitude: locationService.longitude,
                stationLatitude: nil,
                stationLongitude: nil,
                walkMaxMinutes: walkMaxMinutes,
                carMaxMinutes: carMaxMinutes
            )
            if selectedTransport == .train {
                if let coord = stationCoordinate {
                    condition.stationLatitude  = coord.latitude
                    condition.stationLongitude = coord.longitude
                } else {
                    let currentLocation: CLLocation?
                    if let lat = locationService.latitude, let lng = locationService.longitude {
                        currentLocation = CLLocation(latitude: lat, longitude: lng)
                    } else {
                        currentLocation = nil
                    }
                    let resolved = await stationResolver.resolve(stationName: stationKeyword, near: currentLocation)
                    guard let resolved else {
                        formErrorMessage = "駅「\(stationKeyword)」の位置を特定できませんでした。候補から選ぶか、駅名を正確に入力してください。"
                        return
                    }
                    condition.stationLatitude  = resolved.latitude
                    condition.stationLongitude = resolved.longitude
                }
            }
            lastCondition = condition
            await viewModel.searchShops(condition: condition)
            showingResult = viewModel.currentShop != nil
        }
    }

    private func clearFormError() {
        formErrorMessage = nil
        viewModel.clearError()
    }

    private func resetSearchConditions() {
        selectedTransport       = .walk
        selectedUsage           = .dinner
        selectedScene           = .none
        selectedBusinessStatus  = .openNow
        selectedIzakayaFilter   = .all
        selectedBudget          = .noLimit
        peopleCount             = 2
        keyword                 = ""
        stationKeyword          = ""
        stationCoordinate       = nil
        walkMaxMinutes          = 15
        carMaxMinutes           = 30
        lastCondition           = nil
        formErrorMessage        = nil
        viewModel.clearError()
    }
}

// MARK: - WasiHeaderView（ロゴ）

struct WasiHeaderView: View {
    var body: some View {
        VStack(spacing: 0) {
            // 上部の装飾罫線
            HStack(spacing: 0) {
                Rectangle().fill(Color.wasiBorder).frame(height: 1)
                Text("◆").font(.system(size: 9)).foregroundStyle(Color.wasiAccent).padding(.horizontal, 8)
                Rectangle().fill(Color.wasiBorder).frame(height: 1)
            }
            .padding(.bottom, 14)

            Text("一択")
                .font(.wasiDisplay(48, weight: .bold))
                .foregroundStyle(Color.wasiInk)
                .tracking(8)

            Text("ICHITAKU")
                .font(.wasiBody(11, weight: .medium))
                .foregroundStyle(Color.wasiAccent)
                .tracking(5)
                .padding(.top, 4)

            Text("条件を絞って、候補は一軒だけ。")
                .font(.wasiBody(13))
                .foregroundStyle(Color.wasiInkLight)
                .tracking(1)
                .padding(.top, 8)

            // 下部の装飾罫線
            HStack(spacing: 0) {
                Rectangle().fill(Color.wasiBorder).frame(height: 1)
                Text("◆").font(.system(size: 9)).foregroundStyle(Color.wasiAccent).padding(.horizontal, 8)
                Rectangle().fill(Color.wasiBorder).frame(height: 1)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - WasiNoticeView（お知らせ・エラー）

struct WasiNoticeView: View {
    let message: String
    let icon: String
    var isError: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isError ? Color.wasiVermilion : Color.wasiAccent)
                .padding(.top, 1)
            Text(message)
                .font(.wasiBody(13))
                .foregroundStyle(isError ? Color.wasiVermilion : Color.wasiInkLight)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wasiSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isError ? Color.wasiVermilion.opacity(0.4) : Color.wasiBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - WasiSectionLabel（セクション見出し）

struct WasiSectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.wasiAccent).frame(width: 2, height: 13)
            Text(title)
                .font(.wasiBody(12, weight: .medium))
                .foregroundStyle(Color.wasiAccent)
                .tracking(1)
        }
    }
}

// MARK: - WasiSegmentPicker（セグメント選択）

struct WasiSegmentPicker<T: CaseIterable & Identifiable & Hashable>: View where T.AllCases: RandomAccessCollection {
    let label: String
    @Binding var selection: T
    let labelFor: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WasiSectionLabel(title: label)
            HStack(spacing: 0) {
                ForEach(Array(T.allCases.enumerated()), id: \.offset) { index, option in
                    let isSelected = selection == option
                    Button {
                        selection = option
                    } label: {
                        Text(labelFor(option))
                            .font(.wasiBody(13, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? Color.wasiSurface : Color.wasiInk.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.wasiInk : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if index < T.allCases.count - 1 {
                        Rectangle().fill(Color.wasiBorder).frame(width: 0.5)
                    }
                }
            }
            .background(Color.wasiSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.wasiBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - SearchConditionView（検索フォーム）

struct SearchConditionView: View {
    @Binding var selectedTransport: TransportOption
    @Binding var selectedUsage: UsageType
    @Binding var selectedScene: UseScene
    @Binding var selectedBusinessStatus: BusinessStatus
    @Binding var selectedIzakayaFilter: IzakayaFilter
    @Binding var selectedBudget: BudgetOption
    @Binding var peopleCount: Int
    @Binding var keyword: String
    @Binding var stationKeyword: String
    @Binding var stationCoordinate: CLLocationCoordinate2D?
    @Binding var walkMaxMinutes: Int
    @Binding var carMaxMinutes: Int
    let isLoading: Bool
    let onSearch: () -> Void
    let onReset: () -> Void
    let onFormEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // キーワード
            VStack(alignment: .leading, spacing: 6) {
                WasiSectionLabel(title: "キーワード")
                TextField("食べたいもの（例：焼肉、イタリアン）", text: $keyword)
                    .font(.wasiBody(14))
                    .foregroundStyle(Color.wasiInk)
                    .padding(10)
                    .background(Color.wasiSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.wasiBorder, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // 駅名（電車モード時）
            if selectedTransport == .train {
                VStack(alignment: .leading, spacing: 6) {
                    WasiSectionLabel(title: "駅名")
                    StationSearchField(
                        stationKeyword: $stationKeyword,
                        onSelect: { name, coordinate in
                            stationKeyword = name
                            stationCoordinate = coordinate
                        },
                        onManualEdit: {
                            stationCoordinate = nil
                            onFormEdit()
                        }
                    )
                }
            }

            // 人数
            VStack(alignment: .leading, spacing: 6) {
                WasiSectionLabel(title: "人数")
                HStack {
                    Button {
                        if peopleCount > 1 { peopleCount -= 1 }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.wasiInk)
                            .frame(width: 36, height: 36)
                            .background(Color.wasiSurface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Text("\(peopleCount)人")
                        .font(.wasiDisplay(16))
                        .foregroundStyle(Color.wasiInk)
                        .frame(minWidth: 52)
                        .multilineTextAlignment(.center)

                    Button {
                        if peopleCount < 20 { peopleCount += 1 }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.wasiInk)
                            .frame(width: 36, height: 36)
                            .background(Color.wasiSurface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 用途
            WasiSegmentPicker(label: "用途", selection: $selectedUsage) { $0.label }

            // 予算帯
            VStack(alignment: .leading, spacing: 6) {
                WasiSectionLabel(title: "予算帯")
                Text("選択中：\(selectedBudget.label)")
                    .font(.wasiBody(12))
                    .foregroundStyle(Color.wasiAccent)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(BudgetOption.allCases) { option in
                            let isSelected = selectedBudget == option
                            Button {
                                selectedBudget = option
                            } label: {
                                Text(option.shortLabel)
                                    .font(.wasiBody(12, weight: isSelected ? .medium : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.wasiInk : Color.wasiSurface)
                                    .foregroundStyle(isSelected ? Color.wasiSurface : Color.wasiInk.opacity(0.75))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(isSelected ? Color.wasiInk : Color.wasiBorder, lineWidth: 0.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // 利用シーン
            WasiSegmentPicker(label: "シーン", selection: $selectedScene) { $0.label }

            // 営業状態
            WasiSegmentPicker(label: "営業状態", selection: $selectedBusinessStatus) { $0.label }

            // 業態
            WasiSegmentPicker(label: "業態", selection: $selectedIzakayaFilter) { $0.label }

            // 移動手段
            WasiSegmentPicker(label: "移動手段", selection: $selectedTransport) { $0.label }

            // 徒歩・車の時間設定
            if selectedTransport == .walk || selectedTransport == .car {
                let binding  = selectedTransport == .walk ? $walkMaxMinutes : $carMaxMinutes
                let maxRange = selectedTransport == .walk ? 120 : 180
                let unitLabel = selectedTransport == .walk ? "徒歩" : "車"
                let value    = selectedTransport == .walk ? walkMaxMinutes : carMaxMinutes

                VStack(alignment: .leading, spacing: 6) {
                    WasiSectionLabel(title: "\(unitLabel)の時間")
                    HStack {
                        Slider(value: Binding(
                            get: { Double(value) },
                            set: { binding.wrappedValue = Int($0) }
                        ), in: 1...Double(maxRange), step: 1)
                        .tint(Color.wasiAccent)
                        Text("\(value)分以内")
                            .font(.wasiBody(13))
                            .foregroundStyle(Color.wasiInk)
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                }
            }

            Text(selectedTransport.searchHint(walkMinutes: walkMaxMinutes, carMinutes: carMaxMinutes))
                .font(.wasiBody(12))
                .foregroundStyle(Color.wasiInkLight)

            // 区切り線
            HStack(spacing: 0) {
                Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
                Text("◆").font(.system(size: 8)).foregroundStyle(Color.wasiBorder).padding(.horizontal, 8)
                Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
            }
            .padding(.vertical, 4)

            // 検索ボタン
            Button {
                onSearch()
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(Color.wasiSurface)
                    } else {
                        HStack(spacing: 8) {
                            Text("この条件で検索")
                                .font(.wasiBody(15, weight: .medium))
                                .tracking(1)
                            Text("→")
                                .font(.wasiBody(15))
                        }
                        .foregroundStyle(Color.wasiSurface)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.wasiInk)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            // リセットボタン
            Button {
                onReset()
            } label: {
                Text("条件をリセット")
                    .font(.wasiBody(13))
                    .foregroundStyle(Color.wasiInk.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.wasiBorder, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(18)
        .background(Color.wasiSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.wasiBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - SearchChipsView（検索条件チップ）

struct SearchChipsView: View {
    let chips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("前回の検索条件")
                .font(.wasiBody(11))
                .foregroundStyle(Color.wasiInkLight)
                .tracking(0.5)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.wasiBody(12))
                            .foregroundStyle(Color.wasiAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.wasiAccentLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.wasiAccent.opacity(0.35), lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }
}

// MARK: - SearchResultView（検索結果画面）

struct SearchResultView: View {
    @Bindable var viewModel: ShopRouletteViewModel
    let selectedTransport: TransportOption
    let currentLatitude: Double?
    let currentLongitude: Double?
    @State private var decidedShop: Shop?

    var body: some View {
        ZStack {
            Color.wasiBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // セクション見出し
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tonight's Pick")
                            .font(.wasiBody(11, weight: .medium))
                            .foregroundStyle(Color.wasiAccent)
                            .tracking(3)
                        Text("今夜の一軒")
                            .font(.wasiDisplay(26))
                            .foregroundStyle(Color.wasiInk)
                    }

                    if let shop = viewModel.currentShop {
                        ShopCardView(shop: shop)

                        // バッジ行
                        HStack(spacing: 8) {
                            WasiInfoBadge(title: shop.budget.name ?? "予算情報なし")
                            if let accessText = estimatedAccessText(for: shop) {
                                WasiInfoBadge(title: accessText)
                            } else if let access = shop.mobileAccess {
                                WasiInfoBadge(title: access)
                            }
                        }

                        // 詳細情報
                        VStack(alignment: .leading, spacing: 0) {
                            WasiDetailRow(title: "ジャンル",   value: shop.genre?.name ?? "情報なし")
                            WasiDetailRow(title: "アクセス",   value: estimatedAccessText(for: shop) ?? (shop.mobileAccess ?? "情報なし"))
                            WasiDetailRow(title: "住所",       value: shop.address ?? "情報なし")
                            WasiDetailRow(title: "営業時間",   value: shop.open ?? "情報なし")
                            WasiDetailRow(title: "予算帯",     value: shop.budget.name ?? (shop.budget.average ?? "情報なし"))
                            WasiDetailRow(title: "最寄り駅",   value: shop.stationName ?? "情報なし", isLast: true)
                        }
                        .background(Color.wasiSurface)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        // キャッチコピー
                        if let text = shop.shopCatch, !text.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("お店のひとこと")
                                    .font(.wasiBody(11, weight: .medium))
                                    .foregroundStyle(Color.wasiAccent)
                                    .tracking(1)
                                Text("「\(text)」")
                                    .font(.wasiDisplay(14))
                                    .foregroundStyle(Color.wasiInk.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.wasiAccentLight)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiAccent.opacity(0.3), lineWidth: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        // ホットペッパーリンク
                        if let detailURL = shop.hotPepperURL {
                            Link(destination: detailURL) {
                                HStack {
                                    Text("ホットペッパーで詳細を見る")
                                        .font(.wasiBody(13))
                                        .foregroundStyle(Color.wasiAccent)
                                    Spacer()
                                    Text("→")
                                        .foregroundStyle(Color.wasiAccent)
                                }
                                .padding(12)
                                .background(Color.wasiSurface)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 130)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
                HStack(spacing: 10) {
                    // ここに決定ボタン
                    Button {
                        guard let shop = viewModel.currentShop else { return }
                        decidedShop = shop
                    } label: {
                        Text("ここに決定")
                            .font(.wasiBody(15, weight: .medium))
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.wasiVermilion)
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentShop == nil)

                    // リロールボタン
                    Button {
                        viewModel.rerollShop()
                    } label: {
                        VStack(spacing: 2) {
                            Text("別の一軒")
                                .font(.wasiBody(13, weight: .medium))
                            Text("残り\(viewModel.remainingRerollCount)回")
                                .font(.wasiBody(10))
                                .foregroundStyle(Color.wasiInkLight)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.wasiSurface)
                        .foregroundStyle(Color.wasiInk)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canReroll)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.wasiBackground)
            }
        }
        .sheet(item: $decidedShop) { shop in
            DecisionCelebrationView(shop: shop)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.wasiBackground, for: .navigationBar)
    }

    private func estimatedAccessText(for shop: Shop) -> String? {
        switch selectedTransport {
        case .train:
            if let mobileAccess = shop.mobileAccess, !mobileAccess.isEmpty {
                return mobileAccess
                    .replacingOccurrences(of: "電車", with: "")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        case .walk, .car:
            guard let userLat = currentLatitude,
                  let userLng = currentLongitude,
                  let shopLat = shop.lat,
                  let shopLng = shop.lng else { return nil }
            let userLocation = CLLocation(latitude: userLat, longitude: userLng)
            let shopLocation = CLLocation(latitude: shopLat, longitude: shopLng)
            let distanceMeter = userLocation.distance(from: shopLocation)
            if selectedTransport == .walk {
                let walkMinutes = max(Int((distanceMeter / 80.0).rounded()), 1)
                return "徒歩\(walkMinutes)分"
            } else {
                let carMinutes = max(Int((distanceMeter / 500.0).rounded()), 1)
                return "車\(carMinutes)分"
            }
        }
    }
}

// MARK: - ShopCardView（店舗カード）

struct ShopCardView: View {
    let shop: Shop

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 写真
            AsyncImage(url: shop.largePhotoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack {
                        Color.wasiAccentLight
                        ProgressView().tint(Color.wasiAccent)
                    }
                case .failure:
                    ZStack {
                        Color.wasiAccentLight
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(Color.wasiAccent.opacity(0.4))
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                Text(shop.name)
                    .font(.wasiDisplay(22))
                    .foregroundStyle(Color.wasiInk)

                // フィーチャータグ行
                HStack(spacing: 6) {
                    WasiFeatureTag(title: "個室",     isOn: shop.privateRoom == "あり")
                    WasiFeatureTag(title: "食べ放題", isOn: shop.freeFood == "あり")
                    WasiFeatureTag(title: "深夜",     isOn: shop.midnight == "1")
                    WasiFeatureTag(title: "駐車場",   isOn: shop.parking == "あり")
                }
            }
            .padding(14)
        }
        .background(Color.wasiSurface)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - WasiDetailRow（明細行）

struct WasiDetailRow: View {
    let title: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text(title)
                    .font(.wasiBody(11))
                    .foregroundStyle(Color.wasiAccent)
                    .frame(width: 70, alignment: .leading)
                    .padding(.vertical, 10)
                Text(value)
                    .font(.wasiBody(13))
                    .foregroundStyle(Color.wasiInk.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)

            if !isLast {
                Rectangle()
                    .fill(Color.wasiBorder)
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
            }
        }
    }
}

// MARK: - WasiInfoBadge（バッジ）

struct WasiInfoBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.wasiBody(12))
            .foregroundStyle(Color.wasiInk.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.wasiSurface)
            .overlay(Capsule().stroke(Color.wasiBorder, lineWidth: 0.5))
            .clipShape(Capsule())
    }
}

// MARK: - WasiFeatureTag（フィーチャータグ）

struct WasiFeatureTag: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(.wasiBody(11, weight: isOn ? .medium : .regular))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isOn ? Color.wasiAccentLight : Color.clear)
            .foregroundStyle(isOn ? Color.wasiAccent : Color.wasiInk.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isOn ? Color.wasiAccent.opacity(0.5) : Color.wasiBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - DecisionCelebrationView（決定演出画面）

struct DecisionCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let shop: Shop

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wasiInk.ignoresSafeArea()

                // 背景の装飾
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.wasiAccent.opacity(0.3)).frame(height: 0.5)
                        Text("◆").font(.system(size: 8)).foregroundStyle(Color.wasiAccent.opacity(0.3)).padding(.horizontal, 8)
                        Rectangle().fill(Color.wasiAccent.opacity(0.3)).frame(height: 0.5)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }

                VStack(spacing: 0) {
                    Spacer()

                    // 上部装飾
                    Text("◆ ◆ ◆")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.wasiAccent.opacity(0.6))
                        .tracking(8)
                        .padding(.bottom, 24)

                    Text("今宵の一軒")
                        .font(.wasiBody(12, weight: .medium))
                        .foregroundStyle(Color.wasiAccent)
                        .tracking(4)
                        .padding(.bottom, 12)

                    Text(shop.name)
                        .font(.wasiDisplay(28))
                        .foregroundStyle(Color(red: 0.961, green: 0.941, blue: 0.910))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if let genre = shop.genre?.name {
                        Text(genre)
                            .font(.wasiBody(13))
                            .foregroundStyle(Color.wasiAccent.opacity(0.8))
                            .padding(.top, 8)
                    }

                    // 区切り線
                    HStack(spacing: 0) {
                        Rectangle().fill(Color.wasiAccent.opacity(0.4)).frame(height: 0.5)
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 28)

                    // ボタン群
                    VStack(spacing: 10) {
                        if let mapURL = shop.mapAppURL {
                            Link(destination: mapURL) {
                                HStack {
                                    Spacer()
                                    Text("地図アプリで開く")
                                        .font(.wasiBody(14, weight: .medium))
                                        .tracking(0.5)
                                    Text("→")
                                    Spacer()
                                }
                                .foregroundStyle(Color.wasiInk)
                                .padding(.vertical, 13)
                                .background(Color(red: 0.961, green: 0.941, blue: 0.910))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .padding(.horizontal, 32)
                        }

                        Button("画面に戻る") { dismiss() }
                            .font(.wasiBody(13))
                            .foregroundStyle(Color(red: 0.961, green: 0.941, blue: 0.910).opacity(0.6))
                            .padding(.top, 4)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .font(.wasiBody(13))
                        .foregroundStyle(Color.wasiAccent.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - TransportOption

enum TransportOption: String, CaseIterable, Identifiable {
    case walk, car, train

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk:  return "徒歩"
        case .car:   return "車"
        case .train: return "電車・駅"
        }
    }

    func searchHint(walkMinutes: Int, carMinutes: Int) -> String {
        switch self {
        case .walk:  return "現在地から徒歩\(max(walkMinutes, 1))分以内のお店を表示します。"
        case .car:   return "現在地から車\(max(carMinutes, 1))分以内のお店を表示します。"
        case .train: return "選択した駅の周辺からお店を探します。"
        }
    }
}

#Preview {
    ContentView()
}
