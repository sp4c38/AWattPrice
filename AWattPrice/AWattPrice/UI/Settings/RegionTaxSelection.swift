import MapKit
import SwiftUI

enum MarketAreaDataSource {
    case remote
    case fallback
}

private enum MarketAreaMapCatalog {
    static let europeRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.0, longitude: 18.0),
        span: MKCoordinateSpan(latitudeDelta: 36, longitudeDelta: 54)
    )

    static let countryCoordinates: [String: CLLocationCoordinate2D] = [
        "AL": CLLocationCoordinate2D(latitude: 41.1, longitude: 20.0),
        "AM": CLLocationCoordinate2D(latitude: 40.3, longitude: 44.9),
        "AT": CLLocationCoordinate2D(latitude: 47.6, longitude: 14.3),
        "AZ": CLLocationCoordinate2D(latitude: 40.4, longitude: 47.7),
        "BA": CLLocationCoordinate2D(latitude: 44.2, longitude: 17.7),
        "BE": CLLocationCoordinate2D(latitude: 50.7, longitude: 4.6),
        "BG": CLLocationCoordinate2D(latitude: 42.8, longitude: 25.2),
        "CH": CLLocationCoordinate2D(latitude: 46.8, longitude: 8.3),
        "CZ": CLLocationCoordinate2D(latitude: 49.9, longitude: 15.5),
        "DE": CLLocationCoordinate2D(latitude: 51.0, longitude: 10.4),
        "DK": CLLocationCoordinate2D(latitude: 56.1, longitude: 10.0),
        "EE": CLLocationCoordinate2D(latitude: 58.7, longitude: 25.0),
        "ES": CLLocationCoordinate2D(latitude: 40.3, longitude: -3.5),
        "FI": CLLocationCoordinate2D(latitude: 64.5, longitude: 26.0),
        "FR": CLLocationCoordinate2D(latitude: 46.4, longitude: 2.4),
        "GE": CLLocationCoordinate2D(latitude: 42.1, longitude: 43.5),
        "GB": CLLocationCoordinate2D(latitude: 54.5, longitude: -2.5),
        "GR": CLLocationCoordinate2D(latitude: 39.1, longitude: 22.9),
        "HR": CLLocationCoordinate2D(latitude: 45.3, longitude: 16.2),
        "HU": CLLocationCoordinate2D(latitude: 47.1, longitude: 19.4),
        "IE": CLLocationCoordinate2D(latitude: 53.3, longitude: -8.0),
        "IT": CLLocationCoordinate2D(latitude: 42.9, longitude: 12.8),
        "LT": CLLocationCoordinate2D(latitude: 55.2, longitude: 23.9),
        "LU": CLLocationCoordinate2D(latitude: 49.8, longitude: 6.1),
        "LV": CLLocationCoordinate2D(latitude: 56.9, longitude: 24.6),
        "MD": CLLocationCoordinate2D(latitude: 47.2, longitude: 28.5),
        "ME": CLLocationCoordinate2D(latitude: 42.8, longitude: 19.3),
        "MK": CLLocationCoordinate2D(latitude: 41.6, longitude: 21.7),
        "MT": CLLocationCoordinate2D(latitude: 35.9, longitude: 14.4),
        "NL": CLLocationCoordinate2D(latitude: 52.2, longitude: 5.4),
        "NO": CLLocationCoordinate2D(latitude: 61.4, longitude: 8.5),
        "PL": CLLocationCoordinate2D(latitude: 52.0, longitude: 19.3),
        "PT": CLLocationCoordinate2D(latitude: 39.6, longitude: -8.0),
        "RO": CLLocationCoordinate2D(latitude: 45.8, longitude: 24.9),
        "RS": CLLocationCoordinate2D(latitude: 44.1, longitude: 20.8),
        "SE": CLLocationCoordinate2D(latitude: 62.0, longitude: 16.8),
        "SI": CLLocationCoordinate2D(latitude: 46.1, longitude: 14.9),
        "SK": CLLocationCoordinate2D(latitude: 48.7, longitude: 19.7),
        "TR": CLLocationCoordinate2D(latitude: 39.0, longitude: 35.0),
        "UA": CLLocationCoordinate2D(latitude: 49.0, longitude: 31.3),
        "XK": CLLocationCoordinate2D(latitude: 42.7, longitude: 21.0),
    ]

    static let areaCoordinates: [String: CLLocationCoordinate2D] = [
        "DE-LU": CLLocationCoordinate2D(latitude: 51.2, longitude: 10.1),
        "AT": CLLocationCoordinate2D(latitude: 47.6, longitude: 14.3),
        "DK1": CLLocationCoordinate2D(latitude: 56.2, longitude: 9.0),
        "DK2": CLLocationCoordinate2D(latitude: 55.6, longitude: 12.4),
        "IT-Brindisi": CLLocationCoordinate2D(latitude: 40.6, longitude: 17.9),
        "IT-Calabria": CLLocationCoordinate2D(latitude: 38.9, longitude: 16.4),
        "IT-Centre-North": CLLocationCoordinate2D(latitude: 43.6, longitude: 11.0),
        "IT-Centre-South": CLLocationCoordinate2D(latitude: 41.9, longitude: 14.4),
        "IT-Foggia": CLLocationCoordinate2D(latitude: 41.5, longitude: 15.5),
        "IT-North": CLLocationCoordinate2D(latitude: 45.1, longitude: 9.5),
        "IT-Priolo": CLLocationCoordinate2D(latitude: 37.1, longitude: 15.2),
        "IT-Rossano": CLLocationCoordinate2D(latitude: 39.6, longitude: 16.6),
        "IT-Sardinia": CLLocationCoordinate2D(latitude: 40.1, longitude: 9.0),
        "IT-Sicily": CLLocationCoordinate2D(latitude: 37.5, longitude: 14.1),
        "IT-South": CLLocationCoordinate2D(latitude: 40.6, longitude: 16.8),
        "NO1": CLLocationCoordinate2D(latitude: 59.9, longitude: 10.8),
        "NO2": CLLocationCoordinate2D(latitude: 58.6, longitude: 7.6),
        "NO3": CLLocationCoordinate2D(latitude: 63.4, longitude: 10.4),
        "NO4": CLLocationCoordinate2D(latitude: 66.9, longitude: 14.6),
        "NO5": CLLocationCoordinate2D(latitude: 60.5, longitude: 5.4),
        "SE1": CLLocationCoordinate2D(latitude: 67.5, longitude: 20.0),
        "SE2": CLLocationCoordinate2D(latitude: 63.8, longitude: 16.0),
        "SE3": CLLocationCoordinate2D(latitude: 59.4, longitude: 15.2),
        "SE4": CLLocationCoordinate2D(latitude: 56.5, longitude: 14.8),
        "UA": CLLocationCoordinate2D(latitude: 49.0, longitude: 31.3),
        "UA-BEI": CLLocationCoordinate2D(latitude: 50.3, longitude: 28.7),
        "UA-DobTPP": CLLocationCoordinate2D(latitude: 50.0, longitude: 24.1),
        "UA-IPS": CLLocationCoordinate2D(latitude: 48.5, longitude: 24.7),
    ]

    static func coordinate(for marketArea: MarketArea) -> CLLocationCoordinate2D? {
        areaCoordinates[marketArea.key] ?? countryCoordinates[marketArea.countryCode]
    }
}

@MainActor
class MarketAreaTaxSelectionViewModel: ObservableObject {
    var settingsManager: SettingsManager
    var notificationService: NotificationService
    var energyDataService: EnergyDataService

    @Published private(set) var availableMarketAreas: [MarketArea] = MarketArea.fallbackAreas
    @Published private(set) var marketAreaDataSource: MarketAreaDataSource = .fallback
    @Published var mapCameraPosition: MapCameraPosition = .region(MarketAreaMapCatalog.europeRegion)
    
    @Published var selectedMarketAreaKey: String {
        didSet {
            if oldValue != selectedMarketAreaKey {
                Task { await marketAreaChanges(newAreaKey: selectedMarketAreaKey) }
            }
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingAreas = false

    private var hasLoadedAreas = false
    
    init(settingsManager: SettingsManager,notificationService: NotificationService, energyDataService: EnergyDataService) {
        self.settingsManager = settingsManager
        self.notificationService = notificationService
        self.energyDataService = energyDataService
        
        self.selectedMarketAreaKey = settingsManager.setting.marketAreaKey
    }

    var selectedMarketArea: MarketArea {
        marketArea(for: selectedMarketAreaKey)
    }

    var mappableMarketAreas: [MarketArea] {
        availableMarketAreas.filter { MarketAreaMapCatalog.coordinate(for: $0) != nil }
    }

    func marketArea(for key: String) -> MarketArea {
        availableMarketAreas.first(where: { $0.key == key }) ?? MarketArea.area(for: key)
    }

    func coordinate(for marketArea: MarketArea) -> CLLocationCoordinate2D? {
        MarketAreaMapCatalog.coordinate(for: marketArea)
    }

    func focusSelectedArea(animated: Bool = false) {
        guard let coordinate = coordinate(for: selectedMarketArea) else { return }
        let focusedPosition = MapCameraPosition.region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 14)
            )
        )

        if animated {
            withAnimation(.easeInOut(duration: 0.55)) {
                mapCameraPosition = focusedPosition
            }
        } else {
            mapCameraPosition = focusedPosition
        }
    }

    func loadAreasIfNeeded() {
        guard hasLoadedAreas == false else { return }
        hasLoadedAreas = true

        Task { await loadAreas() }
    }

    func loadAreas() async {
        isLoadingAreas = true
        defer { isLoadingAreas = false }

        do {
            let response = try await MarketArea.fetchSupportedAreas()
            let sortedAreas = response.areas.sorted { $0.localizedDisplayName < $1.localizedDisplayName }

            availableMarketAreas = sortedAreas.isEmpty ? MarketArea.fallbackAreas : sortedAreas
            marketAreaDataSource = .remote

            if availableMarketAreas.contains(where: { $0.key == selectedMarketAreaKey }) == false {
                let newSelectedKey = availableMarketAreas.first(where: { $0.key == response.defaultArea })?.key
                    ?? availableMarketAreas.first?.key
                    ?? MarketArea.defaultAreaKey
                selectedMarketAreaKey = newSelectedKey
            } else {
                focusSelectedArea()
            }
        } catch {
            print("Failed to load market areas from /areas/: \(error)")
            availableMarketAreas = MarketArea.fallbackAreas
            marketAreaDataSource = .fallback
            focusSelectedArea()
        }
    }
    
    func marketAreaChanges(newAreaKey: String) async {
        let newMarketArea = marketArea(for: newAreaKey)
        var notificationConfiguration = NotificationConfiguration.create(nil, settingsManager.setting)
        notificationConfiguration.general.marketArea = newMarketArea

        focusSelectedArea(animated: true)
        
        do {
            await MainActor.run { isLoading = true }
            
            _ = try await notificationService.changeNotificationConfiguration(notificationConfiguration, settingsManager.setting)
            
            await MainActor.run {
                self.settingsManager.setting.marketArea = newMarketArea
                isLoading = false
            }
            
            self.energyDataService.download(setting: settingsManager.setting)
            
        } catch {
            print("Failed to update notification configuration: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

}

struct RegionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var energyDataService: EnergyDataService
    
    @StateObject var viewModel: MarketAreaTaxSelectionViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: MarketAreaTaxSelectionViewModel(
            settingsManager: SettingsManager.shared,
            notificationService: NotificationService(),
            energyDataService: EnergyDataService()
        ))
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                marketAreaSelectionLink
            }
            .opacity(viewModel.isLoading ? 0.5 : 1)
            .grayscale(viewModel.isLoading ? 0.5 : 0)
        
            if viewModel.isLoading {
                loadingView
            }
        }
        .disabled(viewModel.isLoading)
        .onAppear {
            viewModel.settingsManager = settingsManager
            viewModel.notificationService = notificationService
            viewModel.energyDataService = energyDataService
            viewModel.selectedMarketAreaKey = settingsManager.setting.marketAreaKey
            viewModel.loadAreasIfNeeded()
            viewModel.focusSelectedArea()
        }
    }

    var marketAreaSelectionLink: some View {
        NavigationLink {
            MarketAreaSelectionPage(viewModel: viewModel)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.subtleFill(AppTheme.accent, for: colorScheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Price zone".localized())
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(viewModel.selectedMarketArea.settingsFlag) \(viewModel.selectedMarketArea.localizedDisplayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.isLoadingAreas {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var loadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
    }
}

struct MarketAreaMapSelectionView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: MarketAreaTaxSelectionViewModel
    var height: CGFloat? = nil

    private var unselectedPinFill: Color {
        AppTheme.cardBackground(for: colorScheme)
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $viewModel.mapCameraPosition, interactionModes: [.pan, .zoom]) {
                ForEach(viewModel.mappableMarketAreas) { marketArea in
                    if let coordinate = viewModel.coordinate(for: marketArea) {
                        Annotation(marketArea.localizedDisplayName, coordinate: coordinate) {
                            VStack(spacing: 6) {
                                Text(marketArea.settingsFlag)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(viewModel.selectedMarketAreaKey == marketArea.key ? .white : AppTheme.accent)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle()
                                            .fill(viewModel.selectedMarketAreaKey == marketArea.key ? AppTheme.accent : unselectedPinFill)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.accent, lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
                            }
                            .accessibilityLabel(marketArea.localizedDisplayName)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let marketArea = marketArea(near: value.location, in: proxy) {
                            viewModel.selectedMarketAreaKey = marketArea.key
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: height ?? .infinity)
    }

    private func marketArea(near location: CGPoint, in proxy: MapProxy) -> MarketArea? {
        let hitRadius: CGFloat = 28

        return viewModel.mappableMarketAreas
            .compactMap { marketArea -> (marketArea: MarketArea, distance: CGFloat)? in
                guard
                    let coordinate = viewModel.coordinate(for: marketArea),
                    let markerLocation = proxy.convert(coordinate, to: .local)
                else {
                    return nil
                }

                let distance = hypot(markerLocation.x - location.x, markerLocation.y - location.y)
                return distance <= hitRadius ? (marketArea, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .marketArea
    }
}

private struct MarketAreaSelectionPage: View {
    @ObservedObject var viewModel: MarketAreaTaxSelectionViewModel

    var body: some View {
        MarketAreaMapSelectionView(viewModel: viewModel)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Price zone")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                viewModel.loadAreasIfNeeded()
                viewModel.focusSelectedArea()
            }
    }
}

struct RegionView_Previews: PreviewProvider {
    static var previews: some View {
        RegionView()
            .environmentObject(NotificationService())
            .environmentObject(EnergyDataService())
            .environmentObject(SettingsManager.shared)
    }
}

#Preview("Market Area Selection") {
    NavigationView {
        MarketAreaSelectionPage(
            viewModel: MarketAreaTaxSelectionViewModel(
                settingsManager: SettingsManager.shared,
                notificationService: NotificationService(),
                energyDataService: EnergyDataService()
            )
        )
    }
}
