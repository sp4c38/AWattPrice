//
//  EnergyDataController.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Combine
import Foundation

class EnergyDataController: ObservableObject {
    enum DownloadState {
        case idle
        case downloading
        case failed(error: Error)
        case finished(time: Date)
    }
    
    var cancellables = [AnyCancellable]()
    
    @Published var downloadState: DownloadState = .idle
    @Published var energyData: EnergyData? = nil
    
    func download(region: Region) {
        downloadState = .downloading
        EnergyData.download(region: region)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    logger.debug("Energy data download completed.")
                    let now = Date()
                    self.downloadState = .finished(time: now)
                case .failure(let error):
                    print("Energy data download failed: \(error).")
                    self.downloadState = .failed(error: error)
                }
            } receiveValue: { newEnergyData in
                self.energyData = newEnergyData
            }
            .store(in: &cancellables)
    }
}
