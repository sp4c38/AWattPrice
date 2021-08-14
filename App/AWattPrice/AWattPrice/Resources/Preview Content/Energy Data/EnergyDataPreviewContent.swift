//
//  EnergyDataPreview.swift
//  AWattPrice
//
//  Created by Léon Becker on 14.08.21.
//

import Foundation

extension EnergyData {
    static func previewContent() -> EnergyData {
        guard let dataURL = Bundle.main.url(forResource: "PreviewEnergyData", withExtension: "json") else {
            fatalError("Couldn't find energy data preview json.")
        }
        let data: Data
        do {
            data = try Data(contentsOf: dataURL)
        } catch {
            fatalError("Couldn't read energy data preview json: \(error).")
        }
        let decoder = jsonDecoder()
        let energyData: EnergyData
        do {
            energyData = try decoder.decode(EnergyData.self, from: data)
        } catch {
            fatalError("Couldn't decode energy data preview json: \(error).")
        }
        return energyData
    }
}
