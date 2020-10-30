//
//  AwattarTarifSelectionSettings.swift
//  AWattPrice
//
//  Created by Léon Becker on 29.10.20.
//

import SwiftUI

struct AwattarTarifSelectionSetting: View {
    @EnvironmentObject var currentSetting: CurrentSetting
    @EnvironmentObject var awattarData: AwattarData
    
    @State var awattarEnergyProfileFirstIndex: Int = 0
    @State var awattarEnergyProfileSecondIndex: Int = 0
    @State var placeHolderPickerSelection: Int = 0
    
    @State var firstContentOffset: CGFloat = 0
    @State var secondContentOffset: CGFloat = +250
    @State var waitBeforeExecution: UInt64 = 0
    
    var body: some View {
        Section(
            header: Text("Awattar Tarif"),
            footer: Text("tariffSelectionTip")
        ) {
            VStack(alignment: .center, spacing: 10) {
                Picker(selection: $placeHolderPickerSelection, label: Text("")) {
                    ForEach(awattarData.profilesData.profiles, id: \.name) { profile in
                        Text(profile.name).tag(awattarData.profilesData.profiles.firstIndex(of: profile)!)
                    }
                }
                .onChange(of: placeHolderPickerSelection) { newValue in
                    currentSetting.changeAwattarTariffIndex(newTariffIndex: Int16(newValue))
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + waitBeforeExecution)) {
                        var sideOffset: CGFloat = 0
                        
                        var valuesBetween = [(Int, Int)]()
                        
                        if newValue > awattarEnergyProfileSecondIndex {
                            for profileValue in awattarEnergyProfileSecondIndex..<newValue {
                                valuesBetween.append((profileValue, profileValue + 1))
                            }
                        } else {
                            for profileValue in newValue..<awattarEnergyProfileSecondIndex {
                                valuesBetween.append((profileValue + 1, profileValue))
                            }
                            valuesBetween.reverse()
                        }

                        waitBeforeExecution = UInt64(405000000 * valuesBetween.count)

                        var index = 0
                        for transitionValues in valuesBetween {
                            let executingTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(index * 405000000))
                            DispatchQueue.main.asyncAfter(deadline: executingTime) {
                                if transitionValues.1 < transitionValues.0 {
                                    sideOffset = 250
                                } else {
                                    sideOffset = -250
                                }
                                
                                secondContentOffset = -(sideOffset)
                                awattarEnergyProfileSecondIndex = transitionValues.1
                                
                                withAnimation(.easeIn(duration: 0.4)) {
                                    secondContentOffset = 0
                                    firstContentOffset = sideOffset
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    awattarEnergyProfileFirstIndex = transitionValues.1
                                    firstContentOffset = 0
                                }
                            }
                            index += 1
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + waitBeforeExecution)) {
                            waitBeforeExecution -= waitBeforeExecution
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .pickerStyle(SegmentedPickerStyle())
                .zIndex(0)

                ZStack {
                    VStack(alignment: .center, spacing: 15) {
                        Image(awattarData.profilesData.profiles[awattarEnergyProfileFirstIndex].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60, alignment: .center)
                            .padding(.top, 5)
                        
                        Text(awattarData.profilesData.profiles[awattarEnergyProfileFirstIndex].name)
                            .bold()
                            .font(.title3)
                    }
                    .offset(x: firstContentOffset)

                    VStack(alignment: .center, spacing: 15) {
                        Image(awattarData.profilesData.profiles[awattarEnergyProfileSecondIndex].imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60, alignment: .center)
                            .padding(.top, 5)
                        
                        Text(awattarData.profilesData.profiles[awattarEnergyProfileSecondIndex].name)
                            .bold()
                            .font(.title3)
                    }
                    .offset(x: secondContentOffset)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .onAppear {
            awattarEnergyProfileFirstIndex = Int(currentSetting.setting!.awattarTariffIndex)
            awattarEnergyProfileSecondIndex = awattarEnergyProfileFirstIndex
            placeHolderPickerSelection = awattarEnergyProfileFirstIndex
        }
    }
}

struct AwattarTarifSelectionSettings_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                AwattarTarifSelectionSetting()
                    .environmentObject(CurrentSetting(managedObjectContext: PersistenceManager().persistentContainer.viewContext))
                    .environmentObject(AwattarData())
            }.listStyle(InsetGroupedListStyle())
        }
    }
}
