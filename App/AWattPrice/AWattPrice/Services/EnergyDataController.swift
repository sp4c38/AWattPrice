//
//  EnergyDataController.swift
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
    let prices: [EnergyPricePoint]
    
    /// Prices which have start equal or past the start of the current hour.
    var currentPrices: [EnergyPricePoint] = []
    
    var minCostPricePoint: EnergyPricePoint?
    var maxCostPricePoint: EnergyPricePoint?
    
    /// Current prices time range from the start time of the earliest to the end time of the latest price point.
    var minMaxTimeRange: ClosedRange<Date>?

    enum CodingKeys: CodingKey {
        case prices
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        prices = try values.decode([EnergyPricePoint].self, forKey: .prices)
    }
    
    mutating func computeValues(with setting: SettingCoreData) {
        let now = Date()
        let hourStart = Calendar.current.startOfHour(for: now)
        
        // Filter and sort in a more clear and concise way
        currentPrices = prices
            .filter { $0.startTime >= hourStart }
            .sorted { $0.startTime < $1.startTime }
        
        // Apply price adjustments
        for i in currentPrices.indices {
            if setting.entity.pricesWithVAT == true,
               currentPrices[i].marketprice > 0,
               let regionTaxMultiplier = Region(rawValue: setting.entity.regionIdentifier)?.taxMultiplier
            {
                currentPrices[i].marketprice *= regionTaxMultiplier
            }
            currentPrices[i].marketprice += setting.entity.baseFee
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
    
    /// Downloads energy data for the specified region using async/await
    /// - Parameter region: The region to fetch data for
    /// - Returns: The downloaded and decoded energy data
    /// - Throws: Error if the download or decoding fails
    static func download(region: Region) async throws -> EnergyData {
        let apiClient = APIClient()
        return try await apiClient.downloadEnergyData(region: region)
    }
}



/// Service responsible for managing energy data throughout the application
class EnergyDataController: ObservableObject {
    enum DownloadState {
        case idle
        case downloading
        case failed(error: Error)
        case finished(time: Date)
    }
    
    private var currentDownloadTask: Task<Void, Never>?
    
    @Published var downloadState: DownloadState = .idle
    @Published var energyData: EnergyData? = nil
    
    /// Downloads energy data for the specified region using async/await
    /// - Parameter region: The region to fetch data for
    func download(region: Region) {
        // Cancel any existing task first
        cancelDownloads()
        downloadState = .downloading
        
        currentDownloadTask = Task {
            do {
                // This work happens on a background thread
                let newEnergyData = try await EnergyData.download(region: region)
                
                // Switch to the main thread only for UI updates
                await MainActor.run {
                    self.energyData = newEnergyData
                    logger.debug("Energy data download completed.")
                    self.downloadState = .finished(time: Date())
                }
            } catch {
                await MainActor.run {
                    logger.error("Energy data download failed: \(error).")
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
