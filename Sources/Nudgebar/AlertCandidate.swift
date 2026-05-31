import Foundation

public struct AlertCandidate: Equatable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let calendarTitle: String
    public let location: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.location = location
    }

    public static func sample(now: Date = .now) -> AlertCandidate {
        AlertCandidate(
            id: "sample-alert",
            title: "Upcoming event",
            startDate: now.addingTimeInterval(5 * 60),
            endDate: now.addingTimeInterval(35 * 60),
            calendarTitle: "Sample Calendar",
            location: "Conference Room"
        )
    }
}
