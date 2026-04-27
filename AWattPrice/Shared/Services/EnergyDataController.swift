//
//  EnergyDataService.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Foundation

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
    
    /// Prices that are still active or upcoming.
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
    
    mutating func computeValues(with pricingConfiguration: PricingConfiguration) {
        let now = Date()
        
        currentPrices = prices
            .filter { $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
        
        for i in currentPrices.indices {
            if
                currentPrices[i].marketprice > 0,
                let taxMultiplier = pricingConfiguration.marketArea.taxMultiplier
            {
                currentPrices[i].marketprice *= taxMultiplier
            }
            currentPrices[i].marketprice *= 1 + pricingConfiguration.percentagePriceAddOn / 100
            currentPrices[i].marketprice += pricingConfiguration.fixedPriceAddOn
        }

        minCostPricePoint = currentPrices.min(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
        maxCostPricePoint = currentPrices.max(by: EnergyPricePoint.marketpricesAreInIncreasingOrder)
        
        minMaxTimeRange = currentPrices.first.flatMap { firstPrice in
            currentPrices.last.map { lastPrice in
                firstPrice.startTime...lastPrice.endTime
            }
        }
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
}



/// Service responsible for managing energy data throughout the application
class EnergyDataService: ObservableObject {
    enum DownloadState {
        case idle
        case downloading
        case failed(error: Error)
        case finished(time: Date)
    }
    
    private var currentDownloadTask: Task<Void, Never>?
    
    @Published var downloadState: DownloadState = .idle
    @Published var energyData: EnergyData? = nil
    
    func download(setting: Setting) {
        let pricingConfiguration = setting.pricingConfiguration
        let requestedMarketAreaKey = pricingConfiguration.marketArea.key

        // Cancel any existing task first
        cancelDownloads()
        downloadState = .downloading

        if energyData?.area != requestedMarketAreaKey {
            energyData = nil
        }
        
        currentDownloadTask = Task {
            do {
                let newEnergyData = try await EnergyData.download(marketArea: pricingConfiguration.marketArea)
                
                await MainActor.run {
                    self.energyData = newEnergyData
                    self.energyData?.computeValues(with: pricingConfiguration)
                    print("Energy data download completed.")
                    self.downloadState = .finished(time: Date())
                }
            } catch {
                await MainActor.run {
                    print("Energy data download failed: \(error).")
                    self.downloadState = .failed(error: error)
                }
            }
        }
    }
    
    /// Cancels any ongoing downloads
    func cancelDownloads() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        if case .downloading = downloadState {
            downloadState = .idle
        }
    }
}
