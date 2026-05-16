import Foundation
import SwiftUI
import WidgetKit

enum WidgetEntryState {
    case fresh
    case cached
    case unavailable
    case lockedPro
}

struct WidgetPriceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPriceSnapshot
    let state: WidgetEntryState

    static var preview: WidgetPriceEntry {
        WidgetPriceEntry(
            date: Date(),
            snapshot: WidgetPreviewData.snapshot(),
            state: .fresh
        )
    }
}

struct WidgetPriceProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetPriceEntry {
        WidgetPriceEntry.preview
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetPriceEntry) -> Void) {
        guard context.isPreview == false else {
            completion(.preview)
            return
        }

        guard ProSupporterEntitlementStore.hasPro else {
            let snapshot = WidgetPriceSnapshot.cached() ?? WidgetPriceSnapshot.empty(
                setting: WidgetSettingsProvider.shared.reloadSetting()
            )
            completion(WidgetPriceEntry(date: Date(), snapshot: snapshot, state: .lockedPro))
            return
        }

        let snapshot = WidgetPriceSnapshot.cached() ?? WidgetPriceSnapshot.empty(
            setting: WidgetSettingsProvider.shared.reloadSetting()
        )
        completion(WidgetPriceEntry(date: Date(), snapshot: snapshot, state: snapshot.hasPrices ? .cached : .unavailable))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetPriceEntry>) -> Void) {
        Task {
            let setting = WidgetSettingsProvider.shared.reloadSetting()

            guard ProSupporterEntitlementStore.hasPro else {
                let snapshot = WidgetPriceSnapshot.cached() ?? WidgetPriceSnapshot.empty(setting: setting)
                let entry = WidgetPriceEntry(date: Date(), snapshot: snapshot, state: .lockedPro)
                completion(Timeline(entries: [entry], policy: .after(nextRetryDate())))
                return
            }

            do {
                let snapshot = try await downloadSnapshot(setting: setting)
                snapshot.cache()
                let entry = WidgetPriceEntry(date: Date(), snapshot: snapshot, state: .fresh)
                completion(Timeline(entries: [entry], policy: .after(nextReloadDate(for: snapshot))))
            } catch {
                let snapshot = WidgetPriceSnapshot.cached() ?? WidgetPriceSnapshot.empty(setting: setting)
                let entry = WidgetPriceEntry(date: Date(), snapshot: snapshot, state: snapshot.hasPrices ? .cached : .unavailable)
                completion(Timeline(entries: [entry], policy: .after(nextRetryDate())))
            }
        }
    }

    private func downloadSnapshot(setting: Setting) async throws -> WidgetPriceSnapshot {
        let pricingConfiguration = setting.pricingConfiguration
        var energyData = try await EnergyData.download(marketArea: pricingConfiguration.marketArea)
        energyData.computeValues(with: pricingConfiguration)
        return WidgetPriceSnapshot(energyData: energyData, setting: setting)
    }

    private func nextReloadDate(for snapshot: WidgetPriceSnapshot) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let nextBoundary = snapshot.nextPriceBoundary ?? nextHour(after: now, calendar: calendar)

        guard needsTomorrowRefresh(snapshot: snapshot, calendar: calendar, now: now) else {
            return nextBoundary
        }

        return min(nextBoundary, nextHalfHour(after: now, calendar: calendar))
    }

    private func needsTomorrowRefresh(snapshot: WidgetPriceSnapshot, calendar: Calendar, now: Date) -> Bool {
        guard calendar.component(.hour, from: now) >= 13 else { return false }

        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(24 * 60 * 60)

        guard let lastPoint = snapshot.points.last else { return true }
        return lastPoint.startTime < startOfTomorrow
    }

    private func nextRetryDate() -> Date {
        nextHalfHour(after: Date(), calendar: .autoupdatingCurrent)
    }

    private func nextHour(after date: Date, calendar: Calendar) -> Date {
        let startOfHour = calendar.startOfHour(for: date)
        return startOfHour.addingTimeInterval(60 * 60)
    }

    private func nextHalfHour(after date: Date, calendar: Calendar) -> Date {
        let startOfHour = calendar.startOfHour(for: date)
        let halfHour = startOfHour.addingTimeInterval(30 * 60)
        return date < halfHour ? halfHour : startOfHour.addingTimeInterval(60 * 60)
    }
}

enum WidgetPreviewData {
    static func snapshot() -> WidgetPriceSnapshot {
        guard
            let dataURL = Bundle.main.url(forResource: "PricesPreviewContent", withExtension: "json"),
            let data = try? Data(contentsOf: dataURL),
            var energyData = try? EnergyData.jsonDecoder().decode(EnergyData.self, from: data)
        else {
            return fallbackSnapshot()
        }

        let setting = WidgetSettingsProvider.shared.reloadSetting()
        energyData.computeValues(with: setting.pricingConfiguration)
        let snapshot = WidgetPriceSnapshot(energyData: energyData, setting: setting)
        return snapshot.hasPrices ? snapshot : fallbackSnapshot()
    }

    private static func fallbackSnapshot() -> WidgetPriceSnapshot {
        let setting = Setting()
        let now = Calendar.autoupdatingCurrent.startOfHour(for: Date())
        var points: [WidgetPricePoint] = []

        for index in 0..<24 {
            let startTime = now.addingTimeInterval(TimeInterval(index * 60 * 60))
            let endTime = now.addingTimeInterval(TimeInterval((index + 1) * 60 * 60))
            let price = Double((index % 8) + 2)

            let point = WidgetPricePoint(
                startTime: startTime,
                endTime: endTime,
                marketprice: price
            )
            points.append(point)
        }

        return WidgetPriceSnapshot(
            createdAt: Date(),
            marketAreaName: setting.marketArea.localizedDisplayName,
            points: points
        )
    }
}
