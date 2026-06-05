import CoreLocation
import MapKit
import Observation
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
    /// 見出し：やわらかめの標準書体
    static func wasiDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
    }
    /// 本文
    static func wasiBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var viewModel = ShopRouletteViewModel()
    @State private var locationService = LocationService()
    @State private var historyStore = SearchHistoryStore()
    private let stationResolver = StationResolver()

    @State private var selectedTransport: TransportOption = .walk
    @State private var selectedBudget: BudgetOption = .noLimit
    @State private var requiresFreeFood: Bool = false
    @State private var requiresFreeDrink: Bool = false
    @State private var requiresPrivateRoom: Bool = false
    @State private var requiresParking: Bool = false
    @State private var requiresOpenNow: Bool = false
    @State private var requiresMidnight: Bool = false
    @State private var requiresPet: Bool = false
    @State private var keyword: String = ""
    @State private var stationKeyword: String = ""
    @State private var stationCoordinate: CLLocationCoordinate2D? = nil
    @State private var walkMaxMinutes: Int = 15
    @State private var carMaxMinutes: Int = 30
    @State private var trainMaxMinutes: Int = 10
    @State private var lastCondition: ShopSearchCondition?
    @State private var showingResult: Bool = false
    @State private var formErrorMessage: String?
    @State private var showFirstScreen: Bool = true
    @State private var formVersion: Int = 0
    @State private var currentWizardStep: SearchWizardStep = .keyword
    @State private var wizardStepDirection: SearchWizardDirection = .forward

    var body: some View {
        NavigationStack {
            ZStack {
                Color.wasiBackground.ignoresSafeArea()
                // 和紙の微細なテクスチャ感を出す薄いオーバーレイ
                Rectangle()
                    .fill(Color.wasiInk.opacity(0.018))
                    .ignoresSafeArea()

                if showFirstScreen {
                    FirstScreenView()
                    .transition(.opacity)
                } else {
                    GeometryReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // ── 現在地メッセージ ──
                                if let locationMessage = locationMessageForCurrentTransport {
                                    WasiNoticeView(message: locationMessage, icon: "location.fill")
                                }

                                // ── 検索フォーム ──
                                SearchConditionView(
                                    selectedTransport: $selectedTransport,
                                    selectedBudget: $selectedBudget,
                                    requiresFreeFood: $requiresFreeFood,
                                    requiresFreeDrink: $requiresFreeDrink,
                                    requiresPrivateRoom: $requiresPrivateRoom,
                                    requiresParking: $requiresParking,
                                    requiresOpenNow: $requiresOpenNow,
                                    requiresMidnight: $requiresMidnight,
                                    requiresPet: $requiresPet,
                                    keyword: $keyword,
                                    currentStep: $currentWizardStep,
                                    stepDirection: $wizardStepDirection,
                                    stationKeyword: $stationKeyword,
                                    stationCoordinate: $stationCoordinate,
                                    walkMaxMinutes: $walkMaxMinutes,
                                    carMaxMinutes: $carMaxMinutes,
                                    trainMaxMinutes: $trainMaxMinutes,
                                    onFormEdit: clearFormError
                                )
                                .id(formVersion)

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
                                        historyStore: historyStore,
                                        selectedTransport: selectedTransport,
                                        currentLatitude: locationService.latitude,
                                        currentLongitude: locationService.longitude
                                    )
                                } label: { EmptyView() }
                                .hidden()
                            }
                            .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 12, 0), alignment: .top)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .padding(.bottom, 110)
                        }
                    }
                }
            }
            .task { locationService.startUpdatingLocation() }
            .task {
                guard showFirstScreen else { return }
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                withAnimation(.easeInOut(duration: 0.28)) {
                    showFirstScreen = false
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showFirstScreen {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("リセット") {
                            resetSearchConditions()
                        }
                        .foregroundStyle(Color.wasiAccent)
                        .disabled(viewModel.isLoading)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            HistoryListView(historyStore: historyStore)
                        } label: {
                            Text("履歴")
                                .foregroundStyle(Color.wasiAccent)
                        }
                    }
                }
            }
            .toolbarBackground(Color.wasiBackground, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if !showFirstScreen && !showingResult {
                    wizardBottomBar
                }
            }
            .onChange(of: selectedTransport)      { _, _ in clearFormError() }
            .onChange(of: selectedBudget)         { _, _ in clearFormError() }
            .onChange(of: requiresFreeFood)       { _, _ in clearFormError() }
            .onChange(of: requiresFreeDrink)      { _, _ in clearFormError() }
            .onChange(of: requiresPrivateRoom)    { _, _ in clearFormError() }
            .onChange(of: requiresParking)        { _, _ in clearFormError() }
            .onChange(of: requiresOpenNow)        { _, _ in clearFormError() }
            .onChange(of: requiresMidnight)       { _, _ in clearFormError() }
            .onChange(of: requiresPet)            { _, _ in clearFormError() }
            .onChange(of: keyword)                { _, _ in clearFormError() }
            .onChange(of: stationKeyword)         { _, _ in clearFormError() }
            .onChange(of: walkMaxMinutes)         { _, _ in clearFormError() }
            .onChange(of: carMaxMinutes)          { _, _ in clearFormError() }
            .onChange(of: trainMaxMinutes)        { _, _ in clearFormError() }
        }
    }

    private var locationMessageForCurrentTransport: String? {
        if selectedTransport == .walk || selectedTransport == .car {
            return locationService.locationStatusMessage
        }
        return nil
    }

    private var wizardSteps: [SearchWizardStep] {
        SearchWizardStep.allCases
    }

    private var isFirstWizardStep: Bool {
        currentWizardStep == wizardSteps.first
    }

    private var isLastWizardStep: Bool {
        currentWizardStep == wizardSteps.last
    }

    private var wizardBottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
            HStack(spacing: 10) {
                Button {
                    goPreviousWizardStep()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("戻る")
                            .tracking(0.4)
                    }
                    .font(.wasiBody(14, weight: .medium))
                    .foregroundStyle(isFirstWizardStep ? Color.wasiInkLight : Color.wasiInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.wasiAccentLight.opacity(isFirstWizardStep ? 0.15 : 0.28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.wasiBorder, lineWidth: 0.7)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(isFirstWizardStep || viewModel.isLoading)

                Button {
                    if isLastWizardStep {
                        performSearch()
                    } else {
                        goNextWizardStep()
                    }
                } label: {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(Color.wasiSurface)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: isLastWizardStep ? "cart.fill" : "arrow.right")
                                    .font(.wasiBody(14, weight: .medium))
                                Text(isLastWizardStep ? "注文" : "次へ")
                                    .font(.wasiBody(15, weight: .medium))
                                    .tracking(1)
                            }
                            .foregroundStyle(Color.wasiSurface)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.wasiInk)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Color.wasiBackground)
        }
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
                genre: .all,
                keyword: keyword,
                stationKeyword: stationKeyword,
                budgetCode: selectedBudget.code,
                requiresFreeFood: requiresFreeFood,
                requiresFreeDrink: requiresFreeDrink,
                requiresPrivateRoom: requiresPrivateRoom,
                requiresParking: requiresParking,
                requiresOpenNow: requiresOpenNow,
                requiresMidnight: requiresMidnight,
                requiresPet: requiresPet,
                transport: selectedTransport,
                latitude: locationService.latitude,
                longitude: locationService.longitude,
                stationLatitude: nil,
                stationLongitude: nil,
                walkMaxMinutes: walkMaxMinutes,
                carMaxMinutes: carMaxMinutes,
                trainMaxMinutes: trainMaxMinutes
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

    private func goPreviousWizardStep() {
        guard let index = wizardSteps.firstIndex(of: currentWizardStep), index > 0 else { return }
        wizardStepDirection = .backward
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            currentWizardStep = wizardSteps[index - 1]
        }
    }

    private func goNextWizardStep() {
        guard let index = wizardSteps.firstIndex(of: currentWizardStep), index < wizardSteps.count - 1 else { return }
        wizardStepDirection = .forward
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
            currentWizardStep = wizardSteps[index + 1]
        }
    }

    private func resetSearchConditions() {
        selectedTransport       = .walk
        selectedBudget          = .noLimit
        requiresFreeFood        = false
        requiresFreeDrink       = false
        requiresPrivateRoom     = false
        requiresParking         = false
        requiresOpenNow         = false
        requiresMidnight        = false
        requiresPet             = false
        keyword                 = ""
        stationKeyword          = ""
        stationCoordinate       = nil
        walkMaxMinutes          = 15
        carMaxMinutes           = 30
        trainMaxMinutes         = 10
        formVersion            += 1
        currentWizardStep       = .keyword
        wizardStepDirection     = .forward
        lastCondition           = nil
        formErrorMessage        = nil
        viewModel.clearError()
    }
}

// MARK: - WasiHeaderView（ロゴ）

struct FirstScreenView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Ichitaku")
                .font(.wasiDisplay(52))
                .foregroundStyle(Color.wasiInk.opacity(0.9))
                .tracking(1.2)

            HStack(spacing: 4) {
                Text("Powered by")
                    .font(.wasiBody(12, weight: .medium))
                    .foregroundStyle(Color.wasiInkLight)
                Link("ホットペッパーグルメ Webサービス", destination: URL(string: "http://webservice.recruit.co.jp/")!)
                    .font(.wasiBody(12, weight: .medium))
                    .foregroundStyle(Color.wasiAccent)
            }
            .padding(.top, 14)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}

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

            Text("Ichitaku")
                .font(.wasiDisplay(48, weight: .bold))
                .foregroundStyle(Color.wasiInk)
                .tracking(1.2)

            Text("ICHITAKU")
                .font(.wasiBody(11, weight: .medium))
                .foregroundStyle(Color.wasiAccent)
                .tracking(5)
                .padding(.top, 4)

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

struct ToggleGridButton: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Image(systemName: symbol)
                    .font(.wasiBody(13, weight: .semibold))
                Text(title)
                    .font(.wasiBody(14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(isOn ? Color.wasiSurface : Color.wasiInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 13)
            .frame(minHeight: 52)
            .background(isOn ? Color.wasiInk : Color.wasiAccentLight.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn ? Color.wasiInk : Color.wasiBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SearchConditionView（検索フォーム）

enum SearchWizardStep: Int, CaseIterable, Identifiable {
    case keyword
    case budget
    case transport
    case options

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .keyword: return "何が食べたい？"
        case .budget: return "予算はどれくらい？"
        case .transport: return "どうやって行く？"
        case .options: return "こだわりはある？"
        }
    }
}

enum SearchWizardDirection {
    case forward
    case backward
}

struct SearchConditionView: View {
    private let suggestedKeywords = [
        "肉", "魚", "寿司", "焼肉", "居酒屋",
        "焼き鳥", "ラーメン", "カフェ", "さっぱり", "ガッツリ"
    ]

    @Binding var selectedTransport: TransportOption
    @Binding var selectedBudget: BudgetOption
    @Binding var requiresFreeFood: Bool
    @Binding var requiresFreeDrink: Bool
    @Binding var requiresPrivateRoom: Bool
    @Binding var requiresParking: Bool
    @Binding var requiresOpenNow: Bool
    @Binding var requiresMidnight: Bool
    @Binding var requiresPet: Bool
    @Binding var keyword: String
    @Binding var currentStep: SearchWizardStep
    @Binding var stepDirection: SearchWizardDirection
    @Binding var stationKeyword: String
    @Binding var stationCoordinate: CLLocationCoordinate2D?
    @Binding var walkMaxMinutes: Int
    @Binding var carMaxMinutes: Int
    @Binding var trainMaxMinutes: Int
    let onFormEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepProgress
            wizardPage
        }
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.88), value: currentStep)
    }

    private var wizardPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            wizardHeader
            currentStepContent
            currentHint

            HStack(spacing: 0) {
                Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
                Text("◆").font(.system(size: 8)).foregroundStyle(Color.wasiBorder).padding(.horizontal, 8)
                Rectangle().fill(Color.wasiBorder).frame(height: 0.5)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(Color.wasiSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wasiBorder, lineWidth: 1.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 8)
                .stroke(Color.wasiBorder.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) { formCornerFlourish().offset(x: 6, y: 6) }
        .overlay(alignment: .topTrailing) { formCornerFlourish().scaleEffect(x: -1, y: 1).offset(x: -6, y: 6) }
        .overlay(alignment: .bottomLeading) { formCornerFlourish().rotationEffect(.degrees(180)).offset(x: 6, y: -6) }
        .overlay(alignment: .bottomTrailing) { formCornerFlourish().rotationEffect(.degrees(180)).scaleEffect(x: -1, y: 1).offset(x: -6, y: -6) }
        .overlay(alignment: stepDirection == .forward ? .trailing : .leading) {
            LinearGradient(
                colors: [
                    Color.wasiInk.opacity(0.08),
                    Color.wasiInk.opacity(0.02),
                    .clear
                ],
                startPoint: stepDirection == .forward ? .trailing : .leading,
                endPoint: stepDirection == .forward ? .leading : .trailing
            )
            .frame(width: 18)
            .allowsHitTesting(false)
        }
        .id(currentStep)
        .transition(stepTransition)
        .rotationEffect(.degrees(stepDirection == .forward ? 0.35 : -0.35), anchor: stepDirection == .forward ? .leading : .trailing)
    }

    private var allSteps: [SearchWizardStep] {
        SearchWizardStep.allCases
    }

    @ViewBuilder
    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: stepSymbol(for: currentStep))
                    .font(.wasiBody(12, weight: .semibold))
                    .foregroundStyle(Color.wasiSurface)
                    .frame(width: 24, height: 24)
                    .background(Color.wasiAccent)
                    .clipShape(Circle())

                Text("検索条件")
                    .font(.wasiBody(11))
                    .foregroundStyle(Color.wasiAccent)
                    .tracking(1.1)
            }

            Text(currentStep.title)
                .font(.wasiDisplay(24, weight: .semibold))
                .foregroundStyle(Color.wasiInk)
        }
    }

    private var stepProgress: some View {
        HStack(spacing: 8) {
            ForEach(allSteps) { step in
                HStack(spacing: 6) {
                    Image(systemName: stepSymbol(for: step))
                        .font(.wasiBody(10, weight: .semibold))
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? Color.wasiSurface : Color.wasiAccent)
                        .frame(width: 20, height: 20)
                        .background(step.rawValue <= currentStep.rawValue ? Color.wasiAccent : Color.wasiAccentLight.opacity(0.75))
                        .clipShape(Circle())

                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.wasiAccent : Color.wasiAccentLight.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
    }

    @ViewBuilder
    private var currentStepContent: some View {
        Group {
            switch currentStep {
            case .keyword:
                keywordStep
            case .budget:
                budgetStep
            case .transport:
                transportStep
            case .options:
                optionsStep
            }
        }
    }

    private var keywordStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            WasiSectionLabel(title: "人気のキーワード")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(suggestedKeywords, id: \.self) { item in
                    let isSelected = keyword == item
                    Button {
                        keyword = item
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: keywordSymbol(for: item))
                                .font(.system(size: 11, weight: .semibold))
                            Text(item)
                                .font(.wasiBody(14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(isSelected ? Color.wasiAccent : Color.wasiAccentLight.opacity(0.32))
                        .foregroundStyle(isSelected ? Color.wasiSurface : Color.wasiInk)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.wasiAccent : Color.wasiBorder, lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("こだわる人だけ文字入力")
                    .font(.wasiBody(11, weight: .medium))
                    .foregroundStyle(Color.wasiInkLight)

                TextField("例：パン、韓国料理、キーマカレー", text: $keyword)
                    .font(.wasiBody(17))
                    .foregroundStyle(Color.wasiInk)
                    .padding(14)
                    .background(Color.wasiSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.wasiBorder, lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var budgetStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            WasiSectionLabel(title: "予算")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(BudgetOption.allCases) { option in
                    let isSelected = selectedBudget == option
                    Button {
                        selectedBudget = option
                    } label: {
                        Text(option.shortLabel)
                            .font(.wasiBody(13, weight: isSelected ? .medium : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.wasiInk : Color.wasiAccentLight.opacity(0.30))
                            .foregroundStyle(isSelected ? Color.wasiSurface : Color.wasiInk.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? Color.wasiInk : Color.wasiBorder, lineWidth: 0.7)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var transportStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            WasiSectionLabel(title: "移動手段")
            VStack(spacing: 10) {
                ForEach(TransportOption.allCases) { option in
                    Button {
                        selectedTransport = option
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: transportSymbol(for: option))
                                .font(.wasiBody(18, weight: .medium))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.label)
                                    .font(.wasiBody(15, weight: .medium))
                                Text(transportDescription(for: option))
                                    .font(.wasiBody(12))
                                    .foregroundStyle(selectedTransport == option ? Color.wasiSurface.opacity(0.82) : Color.wasiInkLight)
                            }
                            Spacer()
                            if selectedTransport == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.wasiBody(16))
                            }
                        }
                        .foregroundStyle(selectedTransport == option ? Color.wasiSurface : Color.wasiInk)
                        .padding(14)
                        .background(selectedTransport == option ? Color.wasiInk : Color.wasiAccentLight.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTransport == option ? Color.wasiInk : Color.wasiBorder, lineWidth: 0.8)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .overlay(Color.wasiBorder)
                .padding(.vertical, 2)

            transportDetailSection
        }
    }

    @ViewBuilder
    private var transportDetailSection: some View {
        switch selectedTransport {
        case .walk, .car:
            let binding = selectedTransport == .walk ? $walkMaxMinutes : $carMaxMinutes
            let maxRange = selectedTransport == .walk ? 120 : 60
            let title = selectedTransport == .walk ? "徒歩の時間" : "車の時間"
            let value = selectedTransport == .walk ? walkMaxMinutes : carMaxMinutes

            VStack(alignment: .leading, spacing: 12) {
                WasiSectionLabel(title: title)
                Text("\(value)分以内")
                    .font(.wasiDisplay(28, weight: .semibold))
                    .foregroundStyle(Color.wasiInk)
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { binding.wrappedValue = Int($0) }
                    ),
                    in: 5...Double(maxRange),
                    step: 5
                )
                .tint(Color.wasiAccent)
            }
        case .train:
            VStack(alignment: .leading, spacing: 12) {
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

                WasiSectionLabel(title: "駅から徒歩")
                Text("\(trainMaxMinutes)分以内")
                    .font(.wasiDisplay(28, weight: .semibold))
                    .foregroundStyle(Color.wasiInk)
                Slider(
                    value: Binding(
                        get: { Double(trainMaxMinutes) },
                        set: { trainMaxMinutes = Int($0) }
                    ),
                    in: 5...30,
                    step: 5
                )
                .tint(Color.wasiAccent)
            }
        }
    }

    private var optionsStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            WasiSectionLabel(title: "こだわり条件")
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ToggleGridButton(title: "営業中", symbol: "sun.max", isOn: $requiresOpenNow)
                ToggleGridButton(title: "食べ放題", symbol: "fork.knife.circle", isOn: $requiresFreeFood)
                ToggleGridButton(title: "飲み放題", symbol: "wineglass", isOn: $requiresFreeDrink)
                ToggleGridButton(title: "個室", symbol: "door.left.hand.open", isOn: $requiresPrivateRoom)
                ToggleGridButton(title: "駐車場", symbol: "car.fill", isOn: $requiresParking)
                ToggleGridButton(title: "夜間営業", symbol: "moon.stars", isOn: $requiresMidnight)
                ToggleGridButton(title: "ペット可", symbol: "pawprint", isOn: $requiresPet)
            }
        }
    }

    private var currentHint: some View {
        Group {
            if currentStep == .transport {
                Text(selectedTransport.searchHint(
                    walkMinutes: walkMaxMinutes,
                    carMinutes: carMaxMinutes,
                    trainMinutes: trainMaxMinutes
                ))
                .font(.wasiBody(12))
                .foregroundStyle(Color.wasiInkLight)
            }
        }
    }

    private var stepTransition: AnyTransition {
        let insertionEdge: Edge = stepDirection == .forward ? .trailing : .leading
        let removalEdge: Edge = stepDirection == .forward ? .leading : .trailing

        return .asymmetric(
            insertion: .move(edge: insertionEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: stepDirection == .forward ? .trailing : .leading)),
            removal: .move(edge: removalEdge)
                .combined(with: .opacity)
        )
    }

    private func transportSymbol(for option: TransportOption) -> String {
        switch option {
        case .walk: return "figure.walk"
        case .car: return "car.fill"
        case .train: return "tram.fill"
        }
    }

    private func transportDescription(for option: TransportOption) -> String {
        switch option {
        case .walk: return "今いる場所から歩ける範囲で探します"
        case .car: return "少し広めに探したいときに向いています"
        case .train: return "選んだ駅を起点にお店を探します"
        }
    }

    private func stepSymbol(for step: SearchWizardStep) -> String {
        switch step {
        case .keyword: return "fork.knife"
        case .budget: return "yensign.circle"
        case .transport: return "car.front.waves.up"
        case .options: return "slider.horizontal.3"
        }
    }

    private func keywordSymbol(for item: String) -> String {
        switch item {
        case "肉", "焼肉", "ガッツリ":
            return "flame.fill"
        case "魚", "寿司":
            return "fish.fill"
        case "居酒屋", "焼き鳥":
            return "wineglass.fill"
        case "ラーメン":
            return "takeoutbag.and.cup.and.straw.fill"
        case "カフェ":
            return "cup.and.saucer.fill"
        case "さっぱり":
            return "leaf.fill"
        default:
            return "fork.knife"
        }
    }

    private func formCornerFlourish() -> some View {
        HStack(spacing: 2) {
            Image(systemName: "leaf")
                .font(.system(size: 9, weight: .semibold))
            Image(systemName: "leaf.fill")
                .font(.system(size: 7, weight: .semibold))
        }
        .foregroundStyle(Color.wasiAccent.opacity(0.55))
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
    @Bindable var historyStore: SearchHistoryStore
    let selectedTransport: TransportOption
    let currentLatitude: Double?
    let currentLongitude: Double?
    @State private var autoSavedEntryID: UUID?
    @State private var autoSavedShopID: String?

    var body: some View {
        ZStack {
            Color.wasiBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let shop = viewModel.currentShop {
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 14) {
                                ShopCardView(
                                    shop: shop,
                                    accessText: estimatedAccessText(for: shop)
                                )
                                ShareLink(
                                    item: shareText(for: shop),
                                    subject: Text("イチタクで見つけたお店"),
                                    message: Text("このお店をシェアします")
                                ) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.wasiBody(12, weight: .semibold))
                                        Text("このお店をシェア")
                                            .font(.wasiBody(13, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundStyle(Color.wasiAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.wasiSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.wasiBorder, lineWidth: 0.9)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                if let detailURL = shop.hotPepperURL {
                                    Link(destination: detailURL) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "safari")
                                                .font(.wasiBody(12, weight: .semibold))
                                            Text("ホットペッパーで詳細を見る")
                                                .font(.wasiBody(13, weight: .medium))
                                            Spacer()
                                            Image(systemName: "arrow.up.right")
                                                .font(.wasiBody(12))
                                        }
                                        .foregroundStyle(Color.wasiAccent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.wasiSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.wasiAccent.opacity(0.45), lineWidth: 0.9)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }

                                if let mapURL = shop.mapAppURL {
                                    MapPreviewCard(
                                        shop: shop,
                                        mapURL: mapURL
                                    )
                                }

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
                    // リロールボタン（左）
                    Button {
                        viewModel.rerollShop()
                    } label: {
                        VStack(spacing: 2) {
                            Text("リロール")
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
                .padding(.bottom, 28)
                .background(Color.wasiBackground)
            }
        }
        .task(id: viewModel.currentShop?.id) {
            syncVisibleShopIntoHistory()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.wasiBackground, for: .navigationBar)
    }

    private func syncVisibleShopIntoHistory() {
        guard let shop = viewModel.currentShop else { return }
        guard autoSavedShopID != shop.id else { return }

        if let previousEntryID = autoSavedEntryID {
            historyStore.remove(entryID: previousEntryID)
        }

        let newEntryID = historyStore.add(shop: shop)
        autoSavedEntryID = newEntryID
        autoSavedShopID = shop.id
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

    private func shareText(for shop: Shop) -> String {
        let address = shop.address ?? "住所情報なし"
        let access = estimatedAccessText(for: shop) ?? (shop.mobileAccess ?? "アクセス情報なし")
        let budget = shop.budget.name ?? "予算情報なし"
        let link = shop.hotPepperURL?.absoluteString ?? shop.mapAppURL?.absoluteString ?? ""
        return "イチタクで見つけたお店\n\(shop.name)\n住所: \(address)\nアクセス: \(access)\n予算: \(budget)\n\(link)"
    }

}

struct MapPreviewCard: View {
    let shop: Shop
    let mapURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("地図")
                .font(.wasiBody(11, weight: .medium))
                .foregroundStyle(Color.wasiAccent)
                .tracking(1)

            if let lat = shop.lat, let lng = shop.lng {
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                Link(destination: mapURL) {
                    Map(coordinateRegion: .constant(region), annotationItems: [MapPinPoint(coordinate: region.center)]) { item in
                        MapMarker(coordinate: item.coordinate, tint: .red)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.wasiBorder, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: mapURL) {
                    Text("地図アプリで場所を確認")
                        .font(.wasiBody(13))
                        .foregroundStyle(Color.wasiAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.wasiSurface)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

private struct MapPinPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - ShopCardView（店舗カード）

struct ShopCardView: View {
    let shop: Shop
    let accessText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(shop.name)
                .font(.wasiDisplay(28))
                .foregroundStyle(Color.wasiInk)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            AsyncImage(url: shop.largePhotoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack { Color.wasiAccentLight; ProgressView().tint(Color.wasiAccent) }
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
            .frame(height: 175)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.wasiBorder, lineWidth: 0.8)
            )

            Text("画像提供：ホットペッパー グルメ")
                .font(.wasiBody(10))
                .foregroundStyle(Color.wasiInkLight)

            if let catchCopy = displayableText(shop.shopCatch) {
                menuLine(title: "キャッチコピー", value: catchCopy)
            }
            if let address = displayableText(shop.address) {
                menuLine(title: "住所", value: address)
            }
            if let access = displayableText(accessText ?? shop.mobileAccess) {
                menuLine(title: "アクセス", value: access)
            }
            if let budget = displayableText(shop.budget.name) {
                menuLine(title: "予算", value: budget)
            }
            if let open = displayableText(shop.open) {
                menuLine(title: "営業時間", value: open)
            }

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.wasiAccentLight.opacity(0.26))
                .padding(6)
        )
        .background(Color.wasiSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wasiBorder, lineWidth: 1.2))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 8)
                .stroke(Color.wasiBorder.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.wasiInk.opacity(0.10), radius: 10, x: 0, y: 5)
        .overlay(alignment: .topLeading) { cornerFlourish().offset(x: 6, y: 6) }
        .overlay(alignment: .topTrailing) { cornerFlourish().scaleEffect(x: -1, y: 1).offset(x: -6, y: 6) }
        .overlay(alignment: .bottomLeading) { cornerFlourish().rotationEffect(.degrees(180)).offset(x: 6, y: -6) }
        .overlay(alignment: .bottomTrailing) { cornerFlourish().rotationEffect(.degrees(180)).scaleEffect(x: -1, y: 1).offset(x: -6, y: -6) }
    }

    private func menuLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.wasiBody(11, weight: .medium))
                .foregroundStyle(Color.wasiInkLight)
                .tracking(0.6)
            Text(value)
                .font(.wasiBody(16, weight: .semibold))
                .foregroundStyle(Color.wasiInk)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Color.wasiBorder.opacity(0.7))
                .frame(height: 0.8)
        }
    }

    private func displayableText(_ text: String?) -> String? {
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let hiddenValues = ["情報なし", "未設定", "未登録", "-"]
        return hiddenValues.contains(raw) ? nil : raw
    }

    private func cornerFlourish() -> some View {
        HStack(spacing: 2) {
            Image(systemName: "leaf")
                .font(.system(size: 9, weight: .semibold))
            Image(systemName: "leaf.fill")
                .font(.system(size: 7, weight: .semibold))
        }
        .foregroundStyle(Color.wasiAccent.opacity(0.55))
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

                        if let detailURL = shop.hotPepperURL {
                            Link(destination: detailURL) {
                                HStack {
                                    Spacer()
                                    Text("ホットペッパーで見る")
                                        .font(.wasiBody(14, weight: .medium))
                                        .tracking(0.5)
                                    Text("→")
                                    Spacer()
                                }
                                .foregroundStyle(Color(red: 0.961, green: 0.941, blue: 0.910))
                                .padding(.vertical, 13)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(red: 0.961, green: 0.941, blue: 0.910).opacity(0.35), lineWidth: 1)
                                )
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

@Observable
@MainActor
final class SearchHistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let saveKey = "ichitaku.history.entries"

    init() {
        load()
    }

    @discardableResult
    func add(shop: Shop) -> UUID {
        entries.removeAll { $0.shopID == shop.id }
        let entry = HistoryEntry(
            date: Date(),
            shopID: shop.id,
            shopName: shop.name,
            address: shop.address,
            photoURL: shop.largePhotoURL?.absoluteString,
            mapURL: shop.mapAppURL?.absoluteString,
            hotPepperURL: shop.hotPepperURL?.absoluteString,
            genre: shop.genre?.name,
            budget: shop.budget.name ?? shop.budget.average,
            open: shop.open,
            access: shop.mobileAccess,
            lat: shop.lat,
            lng: shop.lng
        )
        entries.insert(entry, at: 0)
        save()
        return entry.id
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
    }
}

struct HistoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let shopID: String
    let shopName: String
    let address: String?
    let photoURL: String?
    let mapURL: String?
    let hotPepperURL: String?
    let genre: String?
    let budget: String?
    let open: String?
    let access: String?
    let lat: Double?
    let lng: Double?
}

struct HistoryListView: View {
    @Bindable var historyStore: SearchHistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if historyStore.entries.isEmpty {
                    Text("まだ履歴はありません。")
                        .font(.wasiBody(13))
                        .foregroundStyle(Color.wasiInkLight)
                        .padding(.top, 24)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("保存したお店")
                            .font(.wasiDisplay(24))
                            .foregroundStyle(Color.wasiInk)
                        Text("MENU BOOK")
                            .font(.wasiBody(11, weight: .medium))
                            .foregroundStyle(Color.wasiAccent)
                            .tracking(3)
                    }

                    ForEach(groupedEntries, id: \.monthKey) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.monthTitle)
                                .font(.wasiBody(13, weight: .semibold))
                                .foregroundStyle(Color.wasiAccent)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(section.entries, id: \.id) { entry in
                                    NavigationLink {
                                        HistoryDetailView(entry: entry)
                                    } label: {
                                        HistoryMenuCard(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.wasiBackground.ignoresSafeArea())
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupedEntries: [HistoryMonthSection] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"

        let groups = Dictionary(grouping: historyStore.entries) { entry -> Date in
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            return calendar.date(from: comps) ?? entry.date
        }

        return groups.keys.sorted(by: >).map { monthDate in
            let entries = (groups[monthDate] ?? []).sorted { $0.date > $1.date }
            return HistoryMonthSection(
                monthKey: monthDate,
                monthTitle: formatter.string(from: monthDate),
                entries: entries
            )
        }
    }
}

private struct HistoryMonthSection {
    let monthKey: Date
    let monthTitle: String
    let entries: [HistoryEntry]
}

struct HistoryMenuCard: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                dateBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.shopName)
                        .font(.wasiDisplay(18, weight: .semibold))
                        .foregroundStyle(Color.wasiInk)
                        .lineLimit(2)

                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.wasiBody(10))
                        .foregroundStyle(Color.wasiAccent)
                }
                Spacer()
            }

            AsyncImage(url: URL(string: entry.photoURL ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.wasiAccentLight
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.wasiBorder, lineWidth: 0.6))

            historyMiniLine(title: "住所", value: entry.address ?? "住所情報なし", symbol: "mappin.and.ellipse")

            HStack(spacing: 6) {
                Spacer()
                Text("詳細を見る")
                    .font(.wasiBody(11, weight: .medium))
                    .foregroundStyle(Color.wasiAccent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.wasiAccent)
            }
        }
        .padding(14)
        .background(Color.wasiSurface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wasiBorder, lineWidth: 1.1))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 7)
                .stroke(Color.wasiBorder.opacity(0.85), lineWidth: 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) { miniFlourish().scaleEffect(x: -1, y: 1).offset(x: -6, y: 6) }
        .overlay(alignment: .bottomTrailing) { miniFlourish().rotationEffect(.degrees(180)).scaleEffect(x: -1, y: 1).offset(x: -6, y: -6) }
    }

    private var dateBadge: some View {
        VStack(spacing: 2) {
            Text(entry.date.formatted(.dateTime.day()))
                .font(.wasiBody(16, weight: .semibold))
                .foregroundStyle(Color.wasiSurface)
            Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                .font(.wasiBody(9, weight: .medium))
                .foregroundStyle(Color.wasiSurface.opacity(0.92))
                .textCase(.uppercase)
        }
        .frame(width: 42, height: 48)
        .background(Color.wasiAccent)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func miniFlourish() -> some View {
        HStack(spacing: 1) {
            Image(systemName: "leaf")
                .font(.system(size: 8, weight: .semibold))
            Image(systemName: "leaf.fill")
                .font(.system(size: 6, weight: .semibold))
        }
        .foregroundStyle(Color.wasiAccent.opacity(0.52))
    }

    private func historyMiniLine(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.wasiAccent)
                Text(title)
                    .font(.wasiBody(10, weight: .medium))
                    .foregroundStyle(Color.wasiAccent)
            }
            Text(value)
                .font(.wasiBody(11))
                .foregroundStyle(Color.wasiInk)
                .lineLimit(2)
            Rectangle()
                .fill(Color.wasiBorder.opacity(0.6))
                .frame(height: 0.7)
        }
    }
}

struct HistoryDetailView: View {
    let entry: HistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.shopName)
                        .font(.wasiDisplay(28))
                        .foregroundStyle(Color.wasiInk)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    AsyncImage(url: URL(string: entry.photoURL ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.wasiAccentLight
                        }
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.wasiBorder, lineWidth: 0.8))

                    historyRow(title: "住所", value: entry.address ?? "情報なし")
                    historyRow(title: "予算", value: entry.budget ?? "情報なし")
                    historyRow(title: "営業時間", value: entry.open ?? "情報なし")
                    historyRow(title: "アクセス", value: entry.access ?? "情報なし")
                    historyRow(title: "保存日時", value: entry.date.formatted(date: .abbreviated, time: .shortened))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .background(Color.wasiSurface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wasiBorder, lineWidth: 1.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .inset(by: 8)
                        .stroke(Color.wasiBorder.opacity(0.9), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) { miniFlourish().offset(x: 6, y: 6) }
                .overlay(alignment: .topTrailing) { miniFlourish().scaleEffect(x: -1, y: 1).offset(x: -6, y: 6) }
                .overlay(alignment: .bottomLeading) { miniFlourish().rotationEffect(.degrees(180)).offset(x: 6, y: -6) }
                .overlay(alignment: .bottomTrailing) { miniFlourish().rotationEffect(.degrees(180)).scaleEffect(x: -1, y: 1).offset(x: -6, y: -6) }

                if let mapURLString = entry.mapURL, let mapURL = URL(string: mapURLString) {
                    if let lat = entry.lat, let lng = entry.lng {
                        let region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                        Link(destination: mapURL) {
                            Map(coordinateRegion: .constant(region), annotationItems: [MapPinPoint(coordinate: region.center)]) { item in
                                MapMarker(coordinate: item.coordinate, tint: .red)
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Link("地図アプリを開く", destination: mapURL)
                        .font(.wasiBody(14, weight: .medium))
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .background(Color.wasiBackground.ignoresSafeArea())
        .navigationTitle("履歴詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.wasiBody(11))
                .foregroundStyle(Color.wasiAccent)
            Text(value)
                .font(.wasiBody(14))
                .foregroundStyle(Color.wasiInk)
        }
    }

    private func miniFlourish() -> some View {
        HStack(spacing: 1) {
            Image(systemName: "leaf")
                .font(.system(size: 9, weight: .semibold))
            Image(systemName: "leaf.fill")
                .font(.system(size: 7, weight: .semibold))
        }
        .foregroundStyle(Color.wasiAccent.opacity(0.62))
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

    func searchHint(walkMinutes: Int, carMinutes: Int, trainMinutes: Int) -> String {
        switch self {
        case .walk:  return "現在地から徒歩\(max(walkMinutes, 1))分以内のお店を表示します。"
        case .car:   return "現在地から車\(max(carMinutes, 1))分以内のお店を表示します。"
        case .train: return "選択した駅から徒歩\(max(trainMinutes, 1))分以内のお店を表示します。"
        }
    }
}

#Preview {
    ContentView()
}
