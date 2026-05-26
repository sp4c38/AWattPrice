import Foundation

struct WidgetPricePoint: Codable, Identifiable {
    let startTime: Date
    let endTime: Date
    let marketprice: Double

    var id: Date { startTime }

    init(startTime: Date, endTime: Date, marketprice: Double) {
        self.startTime = startTime
        self.endTime = endTime
        self.marketprice = marketprice
    }

    init(pricePoint: EnergyPricePoint) {
        self.startTime = pricePoint.startTime
        self.endTime = pricePoint.endTime
        self.marketprice = pricePoint.marketprice
    }
}

struct WidgetPriceWindow: Codable, Identifiable {
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let averagePrice: Double

    var id: TimeInterval { duration }
}

enum WidgetPriceTrend: Equatable {
    case rising
    case falling
    case stable
}

struct WidgetPriceSnapshot: Codable {
    let createdAt: Date
    let marketAreaName: String
    let points: [WidgetPricePoint]
    let currentPrice: WidgetPricePoint?
    let averagePrice: Double?
    let minPrice: WidgetPricePoint?
    let maxPrice: WidgetPricePoint?
    let cheapestWindows: [WidgetPriceWindow]

    var hasPrices: Bool {
        points.isEmpty == false
    }

    var priceStep: TimeInterval {
        guard points.count >= 2 else {
            return points.first.map { $0.endTime.timeIntervalSince($0.startTime) } ?? 60 * 60
        }

        return points[1].startTime.timeIntervalSince(points[0].startTime)
    }

    var forecastPoints: [WidgetPricePoint] {
        let endDate = createdAt.addingTimeInterval(24 * 60 * 60)
        return points.filter { $0.startTime < endDate }
    }

    var hourlyForecastPoints: [WidgetPricePoint] {
        let calendar = Calendar.autoupdatingCurrent
        let groupedPoints = Dictionary(grouping: forecastPoints) { point in
            calendar.startOfHour(for: point.startTime)
        }

        return groupedPoints.keys.sorted().compactMap { hourStart in
            guard let hourPoints = groupedPoints[hourStart] else { return nil }
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart.addingTimeInterval(60 * 60)
            let average = WidgetPriceSnapshot.weightedAverage(for: hourPoints) ?? hourPoints.first?.marketprice ?? 0

            return WidgetPricePoint(
                startTime: hourStart,
                endTime: hourEnd,
                marketprice: average
            )
        }
    }

    var hourlyForecastAveragePrice: Double? {
        WidgetPriceSnapshot.weightedAverage(for: hourlyForecastPoints)
    }

    var hourlyForecastMinPrice: WidgetPricePoint? {
        hourlyForecastPoints.min { $0.marketprice < $1.marketprice }
    }

    var hourlyForecastMaxPrice: WidgetPricePoint? {
        hourlyForecastPoints.max { $0.marketprice < $1.marketprice }
    }

    var currentHourlyForecastPrice: WidgetPricePoint? {
        guard let currentPrice else { return hourlyForecastPoints.first }

        return hourlyForecastPoints.first { point in
            point.startTime <= currentPrice.startTime && point.endTime > currentPrice.startTime
        } ?? hourlyForecastPoints.first
    }

    var nextThreeHourTrend: WidgetPriceTrend? {
        let hourlyPoints = hourlyForecastPoints
        let startIndex: Int

        if let currentPrice,
           let index = hourlyPoints.firstIndex(where: { point in
               point.startTime <= currentPrice.startTime && point.endTime > currentPrice.startTime
           }) {
            startIndex = index
        } else {
            startIndex = hourlyPoints.startIndex
        }

        guard hourlyPoints.indices.contains(startIndex) else { return nil }

        let trendPoints = Array(hourlyPoints[startIndex...].prefix(3))
        guard let firstPrice = trendPoints.first?.marketprice,
              let lastPrice = trendPoints.last?.marketprice,
              trendPoints.count >= 2
        else {
            return nil
        }

        let change = lastPrice - firstPrice
        let stableThreshold = 0.1

        if abs(change) <= stableThreshold {
            return .stable
        }

        return change > 0 ? .rising : .falling
    }

    var nextPriceBoundary: Date? {
        let now = Date()
        return points.first { $0.endTime > now }?.endTime
    }

    init(energyData: EnergyData, setting: Setting, createdAt: Date = Date()) {
        let currentPoints = energyData.currentPrices.map(WidgetPricePoint.init(pricePoint:))
        let currentPrice = WidgetPriceSnapshot.currentPrice(in: currentPoints, now: createdAt)

        self.createdAt = createdAt
        self.marketAreaName = setting.marketArea.localizedDisplayName
        self.points = currentPoints
        self.currentPrice = currentPrice
        self.averagePrice = WidgetPriceSnapshot.weightedAverage(for: currentPoints)
        self.minPrice = currentPoints.min { $0.marketprice < $1.marketprice }
        self.maxPrice = currentPoints.max { $0.marketprice < $1.marketprice }
        self.cheapestWindows = WidgetPriceSnapshot.cheapestWindows(in: currentPoints)
    }

    init(createdAt: Date = Date(), marketAreaName: String, points: [WidgetPricePoint]) {
        let sortedPoints = points.sorted { $0.startTime < $1.startTime }

        self.createdAt = createdAt
        self.marketAreaName = marketAreaName
        self.points = sortedPoints
        self.currentPrice = WidgetPriceSnapshot.currentPrice(in: sortedPoints, now: createdAt)
        self.averagePrice = WidgetPriceSnapshot.weightedAverage(for: sortedPoints)
        self.minPrice = sortedPoints.min { $0.marketprice < $1.marketprice }
        self.maxPrice = sortedPoints.max { $0.marketprice < $1.marketprice }
        self.cheapestWindows = WidgetPriceSnapshot.cheapestWindows(in: sortedPoints)
    }

    static func cached() -> WidgetPriceSnapshot? {
        guard
            let data = UserDefaults(suiteName: internalAppGroupIdentifier)?.data(forKey: cacheKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetPriceSnapshot.self, from: data)
    }

    func cache() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: internalAppGroupIdentifier)?.set(data, forKey: Self.cacheKey)
    }

    static func empty(setting: Setting = Setting()) -> WidgetPriceSnapshot {
        WidgetPriceSnapshot(
            createdAt: Date(),
            marketAreaName: setting.marketArea.localizedDisplayName,
            points: [],
            currentPrice: nil,
            averagePrice: nil,
            minPrice: nil,
            maxPrice: nil,
            cheapestWindows: []
        )
    }

    init(
        createdAt: Date,
        marketAreaName: String,
        points: [WidgetPricePoint],
        currentPrice: WidgetPricePoint?,
        averagePrice: Double?,
        minPrice: WidgetPricePoint?,
        maxPrice: WidgetPricePoint?,
        cheapestWindows: [WidgetPriceWindow]
    ) {
        self.createdAt = createdAt
        self.marketAreaName = marketAreaName
        self.points = points
        self.currentPrice = currentPrice
        self.averagePrice = averagePrice
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.cheapestWindows = cheapestWindows
    }

    private static let cacheKey = "WidgetPriceSnapshot"
    private static let cheapestWindowDurations: [TimeInterval] = [
        60 * 60,
        2 * 60 * 60,
        4 * 60 * 60,
    ]

    private static func currentPrice(in points: [WidgetPricePoint], now: Date) -> WidgetPricePoint? {
        points.first { $0.startTime <= now && $0.endTime > now } ?? points.first
    }

    private static func weightedAverage(for points: [WidgetPricePoint]) -> Double? {
        guard points.isEmpty == false else { return nil }

        let totalDuration = points.reduce(0) { result, point in
            result + point.endTime.timeIntervalSince(point.startTime)
        }

        guard totalDuration > 0 else { return nil }

        let weightedSum = points.reduce(0) { result, point in
            let duration = point.endTime.timeIntervalSince(point.startTime)
            return result + point.marketprice * duration
        }

        return weightedSum / totalDuration
    }

    private static func cheapestWindows(in points: [WidgetPricePoint]) -> [WidgetPriceWindow] {
        var windows: [WidgetPriceWindow] = []

        for duration in cheapestWindowDurations {
            if let window = cheapestWindow(duration: duration, in: points) {
                windows.append(window)
            }
        }

        return windows
    }

    private static func cheapestWindow(duration: TimeInterval, in points: [WidgetPricePoint]) -> WidgetPriceWindow? {
        guard points.isEmpty == false else { return nil }

        var bestWindow: WidgetPriceWindow?

        for startIndex in points.indices {
            var selectedPoints: [WidgetPricePoint] = []
            var endIndex = startIndex

            while endIndex < points.endIndex,
                  points[endIndex].endTime.timeIntervalSince(points[startIndex].startTime) <= duration {
                selectedPoints.append(points[endIndex])
                endIndex += 1
            }

            guard
                let firstPoint = selectedPoints.first,
                let lastPoint = selectedPoints.last,
                lastPoint.endTime.timeIntervalSince(firstPoint.startTime) >= duration,
                let averagePrice = weightedAverage(for: selectedPoints)
            else {
                continue
            }

            let window = WidgetPriceWindow(
                duration: duration,
                startTime: firstPoint.startTime,
                endTime: lastPoint.endTime,
                averagePrice: averagePrice
            )

            if bestWindow == nil || window.averagePrice < bestWindow!.averagePrice {
                bestWindow = window
            }
        }

        return bestWindow
    }
}
