import CoreLocation
import SwiftUI

/// 一択検索の起点となるトップ画面です。
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
    @State private var lastCondition: ShopSearchCondition?
    @State private var showingResult: Bool = false
    @State private var formErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.96, blue: 0.97), Color(red: 0.92, green: 0.93, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(spacing: 6) {
                            Text("イチタク")
                                .font(.system(size: 38, weight: .bold, design: .serif))
                                .foregroundStyle(Color.black.opacity(0.88))
                                .tracking(1.2)

                            Text("条件を絞って、候補は1店舗だけ。迷う時間を、楽しむ時間へ。")
                                .font(.subheadline)
                                .foregroundStyle(Color.black.opacity(0.58))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

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
                            isLoading: viewModel.isLoading,
                            onSearch: performSearch,
                            onReset: resetSearchConditions,
                            onFormEdit: clearFormError
                        )

                        if let locationMessage = locationMessageForCurrentTransport {
                            Text(locationMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.black.opacity(0.62))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let condition = lastCondition {
                            SearchChipsView(chips: condition.summaryChips)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let formErrorMessage {
                            Text(formErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.red.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        NavigationLink(isActive: $showingResult) {
                            SearchResultView(
                                viewModel: viewModel,
                                selectedTransport: selectedTransport,
                                currentLatitude: locationService.latitude,
                                currentLongitude: locationService.longitude
                            )
                        } label: {
                            EmptyView()
                        }
                        .hidden()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }
            }
            .task {
                locationService.startUpdatingLocation()
            }
            .navigationBarHidden(true)
            .onChange(of: selectedTransport) { _, _ in clearFormError() }
            .onChange(of: selectedUsage) { _, _ in clearFormError() }
            .onChange(of: selectedScene) { _, _ in clearFormError() }
            .onChange(of: selectedBusinessStatus) { _, _ in clearFormError() }
            .onChange(of: selectedIzakayaFilter) { _, _ in clearFormError() }
            .onChange(of: selectedBudget) { _, _ in clearFormError() }
            .onChange(of: peopleCount) { _, _ in clearFormError() }
            .onChange(of: keyword) { _, _ in clearFormError() }
            .onChange(of: stationKeyword) { _, _ in clearFormError() }
        }
    }

    /// 現在の移動手段に応じた現在地メッセージです。
    private var locationMessageForCurrentTransport: String? {
        if selectedTransport == .walk || selectedTransport == .car {
            return locationService.locationStatusMessage
        }
        return nil
    }

    /// 検索条件を組み立てて検索します。
    private func performSearch() {
        if selectedTransport == .train && stationKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formErrorMessage = "電車・駅を使うときは駅名を入れてください。"
            return
        }

        let needsLocation = selectedTransport == .walk || selectedTransport == .car
        let hasLocation = locationService.latitude != nil && locationService.longitude != nil
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
                stationLongitude: nil
            )

            if selectedTransport == .train {
                if let coord = stationCoordinate {
                    condition.stationLatitude = coord.latitude
                    condition.stationLongitude = coord.longitude
                } else {
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
                    guard let resolved else {
                        formErrorMessage = "駅「\(stationKeyword)」の位置を特定できませんでした。候補から選ぶか、駅名を正確に入力してください。"
                        return
                    }
                    condition.stationLatitude = resolved.latitude
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
    }

    private func resetSearchConditions() {
        selectedTransport = .walk
        selectedUsage = .dinner
        selectedScene = .none
        selectedBusinessStatus = .openNow
        selectedIzakayaFilter = .all
        selectedBudget = .noLimit
        peopleCount = 2
        keyword = ""
        stationKeyword = ""
        stationCoordinate = nil
        lastCondition = nil
        formErrorMessage = nil
    }
}

/// 検索条件の入力エリアです。
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
    let isLoading: Bool
    let onSearch: () -> Void
    let onReset: () -> Void
    let onFormEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("検索条件")
                .font(.headline)
                .foregroundStyle(Color.black.opacity(0.85))

            TextField("食べたいもの（例: 焼肉）", text: $keyword)
                .textFieldStyle(.roundedBorder)

            if selectedTransport == .train {
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

            Stepper("人数: \(peopleCount)人", value: $peopleCount, in: 1...20)

            Picker("用途", selection: $selectedUsage) {
                ForEach(UsageType.allCases) { usage in
                    Text(usage.label).tag(usage)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("予算帯")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.78))

                Text("選択中: \(selectedBudget.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BudgetOption.allCases) { option in
                            Button {
                                selectedBudget = option
                            } label: {
                                Text(option.shortLabel)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedBudget == option
                                        ? Color.black.opacity(0.82)
                                        : Color.white
                                    )
                                    .foregroundStyle(selectedBudget == option ? .white : Color.black.opacity(0.72))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Picker("利用シーン", selection: $selectedScene) {
                ForEach(UseScene.allCases) { scene in
                    Text(scene.label).tag(scene)
                }
            }
            .pickerStyle(.segmented)

            Picker("営業状態", selection: $selectedBusinessStatus) {
                ForEach(BusinessStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            .pickerStyle(.segmented)

            Picker("業態", selection: $selectedIzakayaFilter) {
                ForEach(IzakayaFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("移動手段", selection: $selectedTransport) {
                ForEach(TransportOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedTransport.searchHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onSearch()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("この条件で検索")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.black.opacity(0.82))
            .disabled(isLoading)

            Button("全部クリア") {
                onReset()
            }
            .buttonStyle(.bordered)
            .tint(.black)
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

/// 検索条件チップを表示するビューです。
struct SearchChipsView: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Text(chip)
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

/// 検索結果を表示する画面です。
struct SearchResultView: View {
    @Bindable var viewModel: ShopRouletteViewModel
    let selectedTransport: TransportOption
    let currentLatitude: Double?
    let currentLongitude: Double?
    @State private var decidedShop: Shop?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.96, blue: 0.97), Color(red: 0.92, green: 0.93, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tonight's Hideout")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.85))

                    if let shop = viewModel.currentShop {
                        ShopCardView(shop: shop)

                        HStack(spacing: 8) {
                            InfoBadge(title: shop.budget.name ?? "予算情報なし")
                            if let accessText = estimatedAccessText(for: shop) {
                                InfoBadge(title: accessText)
                            } else {
                                InfoBadge(title: shop.mobileAccess ?? "アクセス情報なし")
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            DetailRow(title: "ジャンル", value: shop.genre?.name ?? "情報なし")
                            DetailRow(
                                title: "アクセス",
                                value: estimatedAccessText(for: shop) ?? (shop.mobileAccess ?? "情報なし")
                            )
                            DetailRow(title: "住所", value: shop.address ?? "情報なし")
                            DetailRow(title: "営業時間", value: shop.open ?? "情報なし")
                            DetailRow(title: "予算帯", value: shop.budget.name ?? (shop.budget.average ?? "情報なし"))
                            DetailRow(title: "駅", value: shop.stationName ?? "情報なし")
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)

                        if let text = shop.shopCatch, !text.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("お店のひとこと")
                                    .font(.headline)
                                    .foregroundStyle(Color.black.opacity(0.85))
                                Text(text)
                                    .foregroundStyle(Color.black.opacity(0.70))
                            }
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                        }

                        if let detailURL = shop.hotPepperURL {
                            Link(destination: detailURL) {
                                Text("ホットペッパーで詳細を見る")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .foregroundStyle(Color.black.opacity(0.80))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    guard let shop = viewModel.currentShop else { return }
                    decidedShop = shop
                } label: {
                    Text("ここに決定！")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.black.opacity(0.82))
                .disabled(viewModel.currentShop == nil)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)

                Button {
                    viewModel.rerollShop()
                } label: {
                    Text("リロール（残り\(viewModel.remainingRerollCount)回）")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.black)
                .disabled(!viewModel.canReroll)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $decidedShop) { shop in
            DecisionCelebrationView(shop: shop)
        }
        .navigationTitle("検索結果")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 現在地からの徒歩/車の目安時間を作成します。
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
                  let shopLng = shop.lng else {
                return nil
            }

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

/// 店舗を大きく見せるカードUIです。
struct ShopCardView: View {
    let shop: Shop

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: shop.largePhotoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(shop.name)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .fontWeight(.bold)

            HStack(spacing: 8) {
                FeatureTag(title: "個室", isOn: shop.privateRoom == "あり")
                FeatureTag(title: "食べ放題", isOn: shop.freeFood == "あり")
                FeatureTag(title: "深夜", isOn: shop.midnight == "1")
                FeatureTag(title: "駐車場", isOn: shop.parking == "あり")
            }
        }
        .padding(14)
        .background(Color(red: 0.95, green: 0.90, blue: 0.84))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

/// 明細行の表示です。
struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.55))
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.82))
        }
    }
}

/// 目立たせたい店舗情報のバッジです。
struct InfoBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.72))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

/// 決定後の演出画面です。
struct DecisionCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    let shop: Shop

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.82, green: 0.38, blue: 0.19), Color(red: 0.52, green: 0.19, blue: 0.11)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)

                    Text("今夜のお店はここ！")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(shop.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    if let mapURL = shop.mapAppURL {
                        Link(destination: mapURL) {
                            Text("地図アプリで開く")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .foregroundStyle(Color(red: 0.52, green: 0.19, blue: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button("画面に戻る") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

/// 利用シーン用のタグ表示です。
struct FeatureTag: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? Color.green.opacity(0.22) : Color.gray.opacity(0.2))
            .foregroundStyle(isOn ? .green : .secondary)
            .clipShape(Capsule())
    }
}

enum TransportOption: String, CaseIterable, Identifiable {
    case walk
    case car
    case train

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk:
            return "徒歩"
        case .car:
            return "車"
        case .train:
            return "電車・駅"
        }
    }

    var searchHint: String {
        switch self {
        case .walk:
            return "現在地から徒歩15分以内のお店を表示します。"
        case .car:
            return "現在地から車30分以内のお店を表示します。"
        case .train:
            return "選択した駅の周辺からお店を探します。"
        }
    }
}

#Preview {
    ContentView()
}
