//
//  EnergyDataController.swift
//  AWattPrice
//
//  Created by Léon Becker on 13.08.21.
//

import Combine
import Foundation

class EnergyDataController: ObservableObject {
    var cancellables = [AnyCancellable]()
    
    @Published var energyData: EnergyData? = nil
    /// Gets set to error when download is unsuccessful, but gets unset again in following calls if those completed without error.
    @Published var downloadError: Error? = nil
    
    func download(region: Region) {
        EnergyData.download(region: region)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    logger.debug("Energy data download completed.")
                case .failure(let error):
                    logger.error("Energy data download failed: \(error.localizedDescription).")
                    self.downloadError = error
                }
            } receiveValue: { newEnergyData in
                self.energyData = newEnergyData
            }
            .store(in: &cancellables)
    }
}
