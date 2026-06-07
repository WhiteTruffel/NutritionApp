import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        components.day! += 1
        return Calendar.current.date(from: components)!.addingTimeInterval(-1)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
