import Foundation

public enum AlertPolicy {
    public static func eventsToAlert(
        events: [AlertCandidate],
        now: Date,
        leadTime: TimeInterval,
        alertedIDs: Set<String>
    ) -> [AlertCandidate] {
        guard leadTime >= 0 else {
            return []
        }

        let alertWindowEnd = now.addingTimeInterval(leadTime)

        return events
            .filter { event in
                event.startDate >= now
                    && event.startDate <= alertWindowEnd
                    && !alertedIDs.contains(event.id)
            }
            .sorted { lhs, rhs in
                lhs.startDate < rhs.startDate
            }
    }
}
