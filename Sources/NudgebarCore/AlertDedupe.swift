import Foundation

public struct AlertDedupeKey: Codable, Equatable, Hashable, Sendable {
    public let normalizedTitle: String
    public let startSecond: Int64
    public let endSecond: Int64
    public let normalizedLocation: String

    public init(
        normalizedTitle: String,
        startSecond: Int64,
        endSecond: Int64,
        normalizedLocation: String
    ) {
        self.normalizedTitle = normalizedTitle
        self.startSecond = startSecond
        self.endSecond = endSecond
        self.normalizedLocation = normalizedLocation
    }

    public static func make(for occurrence: AlertOccurrence) -> AlertDedupeKey {
        AlertDedupeKey(
            normalizedTitle: normalize(occurrence.title),
            startSecond: Int64(occurrence.startDate.timeIntervalSince1970.rounded()),
            endSecond: Int64(occurrence.endDate.timeIntervalSince1970.rounded()),
            normalizedLocation: normalize(occurrence.location ?? "")
        )
    }

    public var stableID: String {
        "\(normalizedTitle)|\(startSecond)|\(endSecond)|\(normalizedLocation)"
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

public struct AlertGroup: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let key: AlertDedupeKey
    public let occurrences: [AlertOccurrence]

    public init(id: String, key: AlertDedupeKey, occurrences: [AlertOccurrence]) {
        self.id = id
        self.key = key
        self.occurrences = occurrences
    }

    public var primaryOccurrence: AlertOccurrence {
        occurrences.sorted { lhs, rhs in
            if lhs.providerID.presentationPriority != rhs.providerID.presentationPriority {
                return lhs.providerID.presentationPriority > rhs.providerID.presentationPriority
            }

            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }

            return lhs.id < rhs.id
        }[0]
    }

    public var displayData: AlertDisplayData {
        let occurrence = primaryOccurrence
        return AlertDisplayData(
            title: occurrence.title,
            subtitle: occurrence.calendarTitle,
            startsAt: occurrence.startDate,
            sourceTitle: occurrence.calendarTitle,
            location: occurrence.location
        )
    }
}

public enum AlertOccurrenceGrouper {
    public static func groups(for occurrences: [AlertOccurrence]) -> [AlertGroup] {
        let alertableOccurrences = occurrences.filter(\.isAlertable)
        let grouped = Dictionary(grouping: alertableOccurrences, by: AlertDedupeKey.make(for:))

        return grouped
            .map { key, occurrences in
                AlertGroup(
                    id: key.stableID,
                    key: key,
                    occurrences: occurrences.sorted { $0.id < $1.id }
                )
            }
            .sorted { lhs, rhs in
                let lhsPrimary = lhs.primaryOccurrence
                let rhsPrimary = rhs.primaryOccurrence

                if lhsPrimary.startDate != rhsPrimary.startDate {
                    return lhsPrimary.startDate < rhsPrimary.startDate
                }

                return lhs.id < rhs.id
            }
    }
}
