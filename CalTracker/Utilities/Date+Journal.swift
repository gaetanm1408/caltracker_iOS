import Foundation

extension Date {
    func startOfDay(_ calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func addingDays(_ days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func isSameDay(as other: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: other)
    }

    /// "Aujourd'hui" / "Hier" / "lundi 3 juin" depending on how close the day is.
    func journalTitle(calendar: Calendar = .current, now: Date = .now) -> String {
        if calendar.isDateInToday(self) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(self) { return "Hier" }
        if calendar.isDateInTomorrow(self) { return "Demain" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        let sameYear = calendar.component(.year, from: self) == calendar.component(.year, from: now)
        formatter.dateFormat = sameYear ? "EEEE d MMMM" : "d MMMM yyyy"
        return formatter.string(from: self).capitalizedFirstLetter
    }
}

extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
