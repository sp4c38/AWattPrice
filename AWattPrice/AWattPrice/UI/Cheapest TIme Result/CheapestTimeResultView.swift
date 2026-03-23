//
//  ConsumptionResultView.swift
//  AwattarApp
//
//  Created by Léon Becker on 21.09.20.
//

import SwiftUI

private struct CheapestTimeMetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct CheapestTimeTimelineRow: View {
    let pricePoint: EnergyPricePoint
    let isFirst: Bool
    let isLast: Bool

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var priceText: String {
        "\(pricePoint.marketprice.priceString ?? "-") ct/kWh"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(cheapestTimeAccent)
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(cheapestTimeAccent.opacity(0.22))
                        .frame(width: 2)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(timeFormatter.string(from: pricePoint.startTime)) - \(timeFormatter.string(from: pricePoint.endTime))")
                    .font(.headline)

                Text(isFirst ? "Recommended start".localized() : "Hourly slot".localized())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(priceText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFirst ? cheapestTimeAccent : .primary)
        }
    }
}

private struct CheapestTimeResultContent: View {
    let result: HourPair

    private var heroTitle: String {
        guard let startDate = result.startDate else { return "Best Window".localized() }

        let calendar = Calendar.current
        if calendar.isDateInToday(startDate) {
            return "Best Window Today".localized()
        }

        if calendar.isDateInTomorrow(startDate) {
            return "Best Window Tomorrow".localized()
        }

        return "Best Window".localized()
    }

    private var windowText: String {
        guard let startDate = result.startDate, let endDate = result.endDate else { return "" }

        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "EEE, d MMM  HH:mm"

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"

        return "\(startFormatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
    }

    private var durationText: String {
        let totalSeconds = Int(result.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return TotalTimeFormatter().string(hour: hours, minute: minutes)
    }

    private var averagePriceText: String {
        "\(result.averagePrice.priceString ?? "-") ct/kWh"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(heroTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(windowText)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("The highlighted window gives you the lowest average price within your selected range.".localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cheapestTimeCardStyle()

                HStack(spacing: 12) {
                    CheapestTimeMetricCard(title: "Duration", value: durationText, systemImage: "timer")
                    CheapestTimeMetricCard(title: "Average Price", value: averagePriceText, systemImage: "bolt.fill")
                }

                CheapestTimeMetricCard(
                    title: "Covered Hours",
                    value: "\(result.slotCount)",
                    systemImage: "calendar.badge.clock"
                )

                VStack(alignment: .leading, spacing: 16) {
                    Label("Timeline", systemImage: "list.bullet.rectangle.portrait")
                        .font(.headline)

                    ForEach(Array(result.associatedPricePoints.enumerated()), id: \.offset) { index, pricePoint in
                        CheapestTimeTimelineRow(
                            pricePoint: pricePoint,
                            isFirst: index == 0,
                            isLast: index == result.associatedPricePoints.count - 1
                        )
                    }
                }
                .cheapestTimeCardStyle()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }
}

struct CheapestTimeResultView: View {
    @EnvironmentObject private var energyDataService: EnergyDataService
    @EnvironmentObject private var cheapestHourManager: CheapestHourManager

    var body: some View {
        Group {
            if let result = cheapestHourManager.result {
                CheapestTimeResultContent(result: result)
            } else if cheapestHourManager.failedToFindResult {
                ContentUnavailableView(
                    "No Result Found",
                    systemImage: "bolt.slash",
                    description: Text("cheapestPriceResultPage.cheapestTimeErrorOccurred".localized())
                )
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Finding best window...".localized())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let energyData = energyDataService.energyData {
                cheapestHourManager.calculateCheapestHours(energyData: energyData)
            }
        }
    }
}

struct CheapestTimeResultView_Previews: PreviewProvider {
    static var associatedPricePoints: [EnergyPricePoint] = {
        let prices = EnergyData.previewContent().currentPrices
        return Array(prices.prefix(3))
    }()

    static var previews: some View {
        let cheapestHourManager: CheapestHourManager = {
            let cheapestHourManager = CheapestHourManager()
            cheapestHourManager.setPreviewResult(HourPair(associatedPricePoints: associatedPricePoints))
            return cheapestHourManager
        }()

        CheapestTimeResultView()
            .environmentObject(cheapestHourManager)
            .environmentObject(EnergyDataService())
    }
}
