//
//  EnergyDataService.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Foundation
import WidgetKit

struct EnergyPricePoint: Decodable {
    var startTime: Date
    var endTime: Date
    var marketprice: Double
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case marketprice
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decode(Date.self, forKey: .startTime)
        endTime = try values.decode(Date.self, forKey: .endTime)
        
        var decodedMarketprice = try values.decode(Double.self, forKey: .marketprice)
        decodedMarketprice = decodedMarketprice.euroMWhToCentkWh
        if decodedMarketprice.isZero, decodedMarketprice.sign == .minus {
            decodedMarketprice = abs(decodedMarketprice)
        }
        marketprice = decodedMarketprice
    }
    
    static let marketpricesAreInIncreasingOrder: (EnergyPricePoint, EnergyPricePoint) -> Bool = {
        $0.marketprice < $1.marketprice
    }
}


struct EnergyData: Decodable {
    let area: String?
    let resolution: String?
    let prices: [EnergyPricePoint]
    
    /// Prices that are still active or upcoming, or all selected points for historical data.
    var currentPrices: [EnergyPricePoint] = []
    
    var minCostPricePoint: EnergyPricePoint?
    var maxCostPricePoint: EnergyPricePoint?
    
    /// Current prices time range from the start time of the earliest to the end time of the latest price point.
    var minMaxTimeRange: ClosedRange<Date>?

    enum CodingKeys: CodingKey {
        case area
        case resolution
        case prices
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        area = try values.decodeIfPresent(String.self, forKey: .area)
        resolution = try values.decodeIfPresent(String.self, forKey: .resolution)
        prices = try values.decode([EnergyPricePoint].self, forKey: .prices)
    }

    var priceStep: TimeInterval {
        if prices.count >= 2 {
            return prices[1].startTime.timeIntervalSince(prices[0].startTime)
        }
        if let firstPrice = prices.first {
            return firstPrice.endTime.timeIntervalSince(firstPrice.startTime)
        }
        return 60 * 60
    }
    
    mutating func computeValues(with pricingConfiguration: PricingConfiguration, includesPastPrices: Bool = false) {
        let now = Date()
        
        let selectedPrices = includesPastPrices
            ? prices
            : prices.filter { $0.endTime > now }

        currentPrices = Self.adjustedPrices(
            selectedPrices.sorted { $0.startTime < $1.startTime },
            with: pricingConfiguration
        )

        minCostPricePoint = currentPrices.min(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
        maxCostPricePoint = currentPrices.max(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
        
        minMaxTimeRange = currentPrices.first.flatMap { firstPrice in
            currentPrices.last.map { lastPrice in
                firstPrice.startTime...lastPrice.endTime
            }
        }
    }

    static func adjustedPrices(
        _ pricePoints: [EnergyPricePoint],
        with pricingConfiguration: PricingConfiguration
    ) -> [EnergyPricePoint] {
        var adjustedPricePoints = pricePoints

        for i in adjustedPricePoints.indices {
            if
                adjustedPricePoints[i].marketprice > 0,
                let taxMultiplier = pricingConfiguration.marketArea.taxMultiplier
            {
                adjustedPricePoints[i].marketprice *= taxMultiplier
            }

            for addOn in pricingConfiguration.orderedAddOns {
                switch addOn.kind {
                case .fixed, .monthly:
                    adjustedPricePoints[i].marketprice += addOn.value
                case .percentage:
                    adjustedPricePoints[i].marketprice *= 1 + addOn.value / 100
                }
            }
        }

        return adjustedPricePoints
    }
    
    /// Creates and returns a JSONDecoder configured with appropriate date decoding strategy
    /// - Returns: A configured JSONDecoder instance
    static func jsonDecoder() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        return jsonDecoder
    }
    
    /// Downloads energy data for the specified market area using async/await
    /// - Parameter marketArea: The market area to fetch data for
    /// - Returns: The downloaded and decoded energy data
    /// - Throws: Error if the download or decoding fails
    static func download(marketArea: MarketArea) async throws -> EnergyData {
        let request = APIClient.createEnergyDataRequest(marketArea: marketArea)
        return try await APIClient().request(to: request)
    }

    static func downloadHistory(marketArea: MarketArea, date: Date) async throws -> EnergyData {
        let request = APIClient.createEnergyPriceHistoryRequest(marketArea: marketArea, date: date)
        return try await APIClient().request(to: request)
    }
}

struct GenerationMixCategory: Decodable, Identifiable {
    let category: String
    let generationMW: Double
    let share: Double
    let isRenewable: Bool

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case generationMW = "generation_mw"
        case share
        case isRenewable = "is_renewable"
    }

    var displayOrder: Int {
        switch category {
        case "solar":
            return 0
        case "wind":
            return 1
        case "hydro":
            return 2
        case "biomass":
            return 3
        case "fossil":
            return 4
        case "nuclear":
            return 5
        default:
            return 6
        }
    }
}

struct GenerationMixData: Decodable {
    let area: String?
    let resolution: String?
    let updatedAt: Date
    let startTime: Date
    let endTime: Date
    let totalGenerationMW: Double
    let renewableGenerationMW: Double
    let renewableShare: Double
    let categories: [GenerationMixCategory]

    init(history: GenerationMixHistoryData) {
        let latestInterval = history.sortedIntervals.last
        self.area = history.area
        self.resolution = history.resolution
        self.updatedAt = history.updatedAt
        self.startTime = latestInterval?.startTime ?? history.startTime
        self.endTime = latestInterval?.endTime ?? history.endTime
        self.totalGenerationMW = latestInterval?.totalGenerationMW ?? history.totalGenerationMW
        self.renewableGenerationMW = latestInterval?.renewableGenerationMW ?? history.renewableGenerationMW
        self.renewableShare = latestInterval?.renewableShare ?? history.renewableShare
        self.categories = latestInterval?.categories ?? history.categories
    }

    var visibleCategories: [GenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted {
                if $0.share == $1.share {
                    return $0.displayOrder < $1.displayOrder
                }

                return $0.share > $1.share
            }
    }

    var orderedCategories: [GenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    enum CodingKeys: String, CodingKey {
        case area
        case resolution
        case updatedAt = "updated_at"
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case totalGenerationMW = "total_generation_mw"
        case renewableGenerationMW = "renewable_generation_mw"
        case renewableShare = "renewable_share"
        case categories
    }

    static func jsonDecoder() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        return jsonDecoder
    }

}

struct GenerationMixInterval: Decodable, Identifiable {
    let startTime: Date
    let endTime: Date
    let totalGenerationMW: Double
    let renewableGenerationMW: Double
    let renewableShare: Double
    let categories: [GenerationMixCategory]

    var id: Date { startTime }

    var visibleCategories: [GenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case totalGenerationMW = "total_generation_mw"
        case renewableGenerationMW = "renewable_generation_mw"
        case renewableShare = "renewable_share"
        case categories
    }
}

enum GenerationMixHistoryRange: Int, CaseIterable, Identifiable {
    case day
    case threeDays
    case week

    var id: Int { rawValue }

    var hours: Int {
        switch self {
        case .day:
            return 24
        case .threeDays:
            return 72
        case .week:
            return 168
        }
    }

    var title: String {
        switch self {
        case .day:
            return "24h"
        case .threeDays:
            return "3d"
        case .week:
            return "7d"
        }
    }
}

struct GenerationMixHistoryData: Decodable {
    let area: String?
    let resolution: String?
    let updatedAt: Date
    let startTime: Date
    let endTime: Date
    let totalGenerationMW: Double
    let renewableGenerationMW: Double
    let renewableShare: Double
    let categories: [GenerationMixCategory]
    let intervals: [GenerationMixInterval]

    var visibleCategories: [GenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted {
                if $0.share == $1.share {
                    return $0.displayOrder < $1.displayOrder
                }

                return $0.share > $1.share
            }
    }

    var orderedCategories: [GenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    var sortedIntervals: [GenerationMixInterval] {
        intervals.sorted { $0.startTime < $1.startTime }
    }

    enum CodingKeys: String, CodingKey {
        case area
        case resolution
        case updatedAt = "updated_at"
        case startTime = "start_timestamp"
        case endTime = "end_timestamp"
        case totalGenerationMW = "total_generation_mw"
        case renewableGenerationMW = "renewable_generation_mw"
        case renewableShare = "renewable_share"
        case categories
        case intervals
    }

    static func jsonDecoder() -> JSONDecoder {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
        return jsonDecoder
    }

    static func download(
        marketArea: MarketArea,
        range: GenerationMixHistoryRange = .day
    ) async throws -> GenerationMixHistoryData {
        let request = APIClient.createGenerationMixHistoryRequest(marketArea: marketArea, range: range)
        return try await APIClient().request(to: request)
    }
}



/// Service responsible for managing energy data throughout the application
class EnergyDataService: ObservableObject {
    enum DownloadState {
        case idle
        case downloading
        case failed(error: Error)
        case finished(time: Date)
    }

    enum GenerationMixDownloadState {
        case idle
        case downloading
        case failed
        case finished
    }
    
    private var currentDownloadTask: Task<Void, Never>?
    private var currentDownloadAreaKey: String?
    
    @Published var downloadState: DownloadState = .idle
    @Published var energyData: EnergyData? = nil
    @Published var generationMixData: GenerationMixData? = nil
      @Published var generationMixDownloadState: GenerationMixDownloadState = .idle
      @Published var generationMixHistoryData: GenerationMixHistoryData? = nil
      
      func download(setting: Setting) {
        let pricingConfiguration = setting.pricingConfiguration
        let requestedMarketAreaKey = pricingConfiguration.marketArea.key
        let marketAreaName = pricingConfiguration.marketArea.localizedDisplayName

        if currentDownloadAreaKey == requestedMarketAreaKey {
            return
        }

        cancelDownloads()
        currentDownloadAreaKey = requestedMarketAreaKey
        downloadState = .downloading

        if energyData?.area != requestedMarketAreaKey {
            energyData = nil
            generationMixData = nil
            generationMixHistoryData = nil
        }
        generationMixDownloadState = .downloading
        
        currentDownloadTask = Task {
            defer {
                currentDownloadAreaKey = nil
            }

            do {
                var newEnergyData = try await EnergyData.download(marketArea: pricingConfiguration.marketArea)
                newEnergyData.computeValues(with: pricingConfiguration)
                let processedEnergyData = newEnergyData
                let widgetSnapshot = WidgetPriceSnapshot(
                    createdAt: Date(),
                    marketAreaName: marketAreaName,
                    points: processedEnergyData.currentPrices.map(WidgetPricePoint.init(pricePoint:))
                )
                
                await MainActor.run {
                    self.energyData = processedEnergyData
                    widgetSnapshot.cache()
                    AWattPriceWidgetTimelines.reloadAll()
                    print("Energy data download completed.")
                    self.downloadState = .finished(time: Date())
                }

                do {
                    // Always fetch 7d so the history view can derive any sub-range
                    // without issuing additional network requests.
                    let history = try await GenerationMixHistoryData.download(marketArea: pricingConfiguration.marketArea, range: .week)
                    let generationMixData = GenerationMixData(history: history)
                    await MainActor.run {
                        guard self.energyData?.area == requestedMarketAreaKey else { return }
                        self.generationMixData = generationMixData
                        self.generationMixHistoryData = history
                        self.generationMixDownloadState = .finished
                         print("Generation mix history download completed.")
                      }
                   } catch {
                      await MainActor.run {
                         guard !Self.isCancellation(error) else { return }
                         self.generationMixData = nil
                         self.generationMixHistoryData = nil
                         self.generationMixDownloadState = .failed
                         print("Generation mix history download failed: \(error).")
                      }
                   }
               } catch {
                await MainActor.run {
                    guard !Self.isCancellation(error) else {
                        print("Energy data download cancelled.")
                        return
                    }

                    print("Energy data download failed: \(error).")
                    self.generationMixDownloadState = .idle
                    self.downloadState = .failed(error: error)
                }
            }
        }
    }
    
    /// Cancels any ongoing downloads
    func cancelDownloads() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        currentDownloadAreaKey = nil
        if case .downloading = downloadState {
            downloadState = .idle
        }
        if case .downloading = generationMixDownloadState {
            generationMixDownloadState = .idle
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSURLErrorCancelled
    }
}
