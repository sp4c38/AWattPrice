import Foundation

struct WidgetGenerationMixCategory: Codable, Identifiable {
    let category: String
    let generationMW: Double
    let share: Double
    let isRenewable: Bool

    var id: String { category }

    init(category: String, generationMW: Double, share: Double, isRenewable: Bool) {
        self.category = category
        self.generationMW = generationMW
        self.share = share
        self.isRenewable = isRenewable
    }

    init(category: GenerationMixCategory) {
        self.category = category.category
        self.generationMW = category.generationMW
        self.share = category.share
        self.isRenewable = category.isRenewable
    }

    var displayOrder: Int {
        switch category {
        case "solar":
            return 0
        case "wind":
            return 1
        case "hydro":
            return 2
        case "biomass":
            return 3
        case "fossil":
            return 4
        case "nuclear":
            return 5
        default:
            return 6
        }
    }
}

struct WidgetGenerationMixSnapshot: Codable {
    let createdAt: Date
    let marketAreaName: String
    let updatedAt: Date
    let startTime: Date
    let endTime: Date
    let totalGenerationMW: Double
    let renewableGenerationMW: Double
    let renewableShare: Double
    let categories: [WidgetGenerationMixCategory]

    var hasMix: Bool {
        totalGenerationMW > 0 || categories.isEmpty == false
    }

    var visibleCategories: [WidgetGenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted {
                if $0.share == $1.share {
                    return $0.displayOrder < $1.displayOrder
                }

                return $0.share > $1.share
            }
    }

    var orderedCategories: [WidgetGenerationMixCategory] {
        categories
            .filter { $0.generationMW > 0 }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    init(generationMix: GenerationMixData, setting: Setting, createdAt: Date = Date()) {
        self.createdAt = createdAt
        self.marketAreaName = setting.marketArea.localizedDisplayName
        self.updatedAt = generationMix.updatedAt
        self.startTime = generationMix.startTime
        self.endTime = generationMix.endTime
        self.totalGenerationMW = generationMix.totalGenerationMW
        self.renewableGenerationMW = generationMix.renewableGenerationMW
        self.renewableShare = generationMix.renewableShare
        self.categories = generationMix.categories.map(WidgetGenerationMixCategory.init(category:))
    }

    init(
        createdAt: Date = Date(),
        marketAreaName: String,
        updatedAt: Date,
        startTime: Date,
        endTime: Date,
        totalGenerationMW: Double,
        renewableGenerationMW: Double,
        renewableShare: Double,
        categories: [WidgetGenerationMixCategory]
    ) {
        self.createdAt = createdAt
        self.marketAreaName = marketAreaName
        self.updatedAt = updatedAt
        self.startTime = startTime
        self.endTime = endTime
        self.totalGenerationMW = totalGenerationMW
        self.renewableGenerationMW = renewableGenerationMW
        self.renewableShare = renewableShare
        self.categories = categories
    }

    static func cached() -> WidgetGenerationMixSnapshot? {
        guard
            let data = UserDefaults(suiteName: internalAppGroupIdentifier)?.data(forKey: cacheKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetGenerationMixSnapshot.self, from: data)
    }

    func cache() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: internalAppGroupIdentifier)?.set(data, forKey: Self.cacheKey)
    }

    static func empty(setting: Setting = Setting()) -> WidgetGenerationMixSnapshot {
        let now = Date()
        return WidgetGenerationMixSnapshot(
            createdAt: now,
            marketAreaName: setting.marketArea.localizedDisplayName,
            updatedAt: now,
            startTime: now,
            endTime: now,
            totalGenerationMW: 0,
            renewableGenerationMW: 0,
            renewableShare: 0,
            categories: []
        )
    }

    private static let cacheKey = "WidgetGenerationMixSnapshot"
}
