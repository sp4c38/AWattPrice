//
//  EnergyDataController.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Combine
import Foundation

/// Service responsible for managing energy data throughout the application
class EnergyDataController: ObservableObject {
    enum DownloadState {
        case idle
        case downloading
        case failed(error: Error)
        case finished(time: Date)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var downloadState: DownloadState = .idle
    @Published var energyData: EnergyData? = nil
    
    /// Downloads energy data for the specified region
    /// - Parameter region: The region to fetch data for
    /// - Returns: A publisher that will emit when the download completes
    func download(region: Region) {
        let publisher = EnergyData.download(region: region)
            .receive(on: DispatchQueue.main)
            .share()
        
        downloadState = .downloading
        
        publisher
            .sink { [weak self] completion in
                guard let self = self else { return }
                switch completion {
                case .finished:
                    logger.debug("Energy data download completed.")
                    let now = Date()
                    self.downloadState = .finished(time: now)
                case .failure(let error):
                    logger.error("Energy data download failed: \(error).")
                    self.downloadState = .failed(error: error)
                }
            } receiveValue: { [weak self] newEnergyData in
                self?.energyData = newEnergyData
            }
            .store(in: &cancellables)
    }
    
    /// Cancels any ongoing downloads
    func cancelDownloads() {
        cancellables.removeAll()
        if case .downloading = downloadState {
            downloadState = .idle
        }
    }
}
