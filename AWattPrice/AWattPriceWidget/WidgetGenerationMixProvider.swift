import Foundation
import WidgetKit

struct WidgetGenerationMixEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetGenerationMixSnapshot
    let state: WidgetEntryState

    static var preview: WidgetGenerationMixEntry {
        WidgetGenerationMixEntry(
            date: Date(),
            snapshot: WidgetGenerationMixPreviewData.snapshot(),
            state: .fresh
        )
    }
}

struct WidgetGenerationMixProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetGenerationMixEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetGenerationMixEntry) -> Void) {
        guard context.isPreview == false else {
            completion(.preview)
            return
        }

        guard ProSupporterEntitlementStore.hasPro else {
            let snapshot = WidgetGenerationMixSnapshot.cached() ?? WidgetGenerationMixSnapshot.empty(
                setting: WidgetSettingsProvider.shared.reloadSetting()
            )
            completion(WidgetGenerationMixEntry(date: Date(), snapshot: snapshot, state: .lockedPro))
            return
        }

        let snapshot = WidgetGenerationMixSnapshot.cached() ?? WidgetGenerationMixSnapshot.empty(
            setting: WidgetSettingsProvider.shared.reloadSetting()
        )
        completion(WidgetGenerationMixEntry(date: Date(), snapshot: snapshot, state: snapshot.hasMix ? .cached : .unavailable))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetGenerationMixEntry>) -> Void) {
        Task {
            let setting = WidgetSettingsProvider.shared.reloadSetting()

            guard ProSupporterEntitlementStore.hasPro else {
                let snapshot = WidgetGenerationMixSnapshot.cached() ?? WidgetGenerationMixSnapshot.empty(setting: setting)
                let entry = WidgetGenerationMixEntry(date: Date(), snapshot: snapshot, state: .lockedPro)
                completion(Timeline(entries: [entry], policy: .after(nextRetryDate())))
                return
            }

            do {
                let snapshot = try await downloadSnapshot(setting: setting)
                snapshot.cache()
                let entry = WidgetGenerationMixEntry(date: Date(), snapshot: snapshot, state: .fresh)
                completion(Timeline(entries: [entry], policy: .after(nextReloadDate(for: snapshot))))
            } catch {
                let snapshot = WidgetGenerationMixSnapshot.cached() ?? WidgetGenerationMixSnapshot.empty(setting: setting)
                let entry = WidgetGenerationMixEntry(date: Date(), snapshot: snapshot, state: snapshot.hasMix ? .cached : .unavailable)
                completion(Timeline(entries: [entry], policy: .after(nextRetryDate())))
            }
        }
    }

    private func downloadSnapshot(setting: Setting) async throws -> WidgetGenerationMixSnapshot {
        let history = try await GenerationMixHistoryData.download(marketArea: setting.marketArea, range: .day)
        return WidgetGenerationMixSnapshot(generationMix: GenerationMixData(history: history), setting: setting)
    }

    private func nextReloadDate(for snapshot: WidgetGenerationMixSnapshot) -> Date {
        let now = Date()
        if snapshot.endTime > now {
            return snapshot.endTime.addingTimeInterval(5 * 60)
        }

        return nextHalfHour(after: now, calendar: .autoupdatingCurrent)
    }

    private func nextRetryDate() -> Date {
        nextHalfHour(after: Date(), calendar: .autoupdatingCurrent)
    }

    private func nextHalfHour(after date: Date, calendar: Calendar) -> Date {
        let startOfHour = calendar.startOfHour(for: date)
        let halfHour = startOfHour.addingTimeInterval(30 * 60)
        return date < halfHour ? halfHour : startOfHour.addingTimeInterval(60 * 60)
    }
}

enum WidgetGenerationMixPreviewData {
    static func snapshot() -> WidgetGenerationMixSnapshot {
        let setting = Setting()
        let now = Calendar.autoupdatingCurrent.startOfHour(for: Date())

        return WidgetGenerationMixSnapshot(
            createdAt: Date(),
            marketAreaName: setting.marketArea.localizedDisplayName,
            updatedAt: now,
            startTime: now,
            endTime: now.addingTimeInterval(60 * 60),
            totalGenerationMW: 58_400,
            renewableGenerationMW: 38_540,
            renewableShare: 66,
            categories: [
                WidgetGenerationMixCategory(category: "wind", generationMW: 18_900, share: 32, isRenewable: true),
                WidgetGenerationMixCategory(category: "solar", generationMW: 12_700, share: 22, isRenewable: true),
                WidgetGenerationMixCategory(category: "hydro", generationMW: 4_900, share: 8, isRenewable: true),
                WidgetGenerationMixCategory(category: "biomass", generationMW: 2_040, share: 4, isRenewable: true),
                WidgetGenerationMixCategory(category: "fossil", generationMW: 18_160, share: 31, isRenewable: false),
                WidgetGenerationMixCategory(category: "other", generationMW: 1_700, share: 3, isRenewable: false),
            ]
        )
    }
}
