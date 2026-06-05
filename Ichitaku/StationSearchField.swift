import MapKit
import SwiftUI

/// 駅名を入力しながら候補が出るサジェスト付き入力欄です。
struct StationSearchField: View {
    @Binding var stationKeyword: String
    /// 候補を選んだときに駅名と座標を返します。
    var onSelect: (String, CLLocationCoordinate2D) -> Void
    /// ユーザーが手入力で駅名を変更したときに呼ばれます。
    var onManualEdit: (() -> Void)? = nil

    @State private var suggestions: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("駅名（例: 新宿、渋谷）", text: $stationKeyword)
                    .autocorrectionDisabled()
                    .onChange(of: stationKeyword) { _, newValue in
                        // 候補から選んだ直後は再検索しない
                        if isSelected {
                            isSelected = false
                            return
                        }
                        onManualEdit?()
                        scheduleSearch(query: newValue)
                    }

                if !stationKeyword.isEmpty {
                    Button {
                        stationKeyword = ""
                        suggestions = []
                        searchTask?.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, item in
                        Button {
                            selectStation(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(Color.orange)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(for: item))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if let area = item.placemark.administrativeArea {
                                        Text(area + (item.placemark.locality.map { " \($0)" } ?? ""))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < suggestions.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Private

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }
        searchTask = Task {
            // 300ms のデバウンス
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await fetchSuggestions(query: query)
        }
    }

    @MainActor
    private func fetchSuggestions(query: String) async {
        let searchQuery = query.hasSuffix("駅") ? query : "\(query)駅"

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])

        // 日本全土を対象に検索
        let japanCenter = CLLocationCoordinate2D(latitude: 36.5, longitude: 137.0)
        let span = MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
        request.region = MKCoordinateRegion(center: japanCenter, span: span)

        guard let response = try? await MKLocalSearch(request: request).start() else {
            suggestions = []
            return
        }

        // 鉄道駅らしい候補だけ残す（「駅」を含む名称 or 交通系POI）
        suggestions = response.mapItems
            .filter { item in
                let name = item.name ?? ""
                return name.contains("駅") || name.contains("Station")
            }
            .prefix(6)
            .map { $0 }
    }

    private func selectStation(_ item: MKMapItem) {
        isSelected = true
        let name = displayName(for: item)
        stationKeyword = name
        suggestions = []
        onSelect(name, item.placemark.coordinate)
    }

    /// 「◯◯駅」の形で表示名を作ります。
    private func displayName(for item: MKMapItem) -> String {
        let name = item.name ?? stationKeyword
        // すでに「駅」が含まれていればそのまま返す
        if name.contains("駅") { return name }
        return "\(name)駅"
    }
}
