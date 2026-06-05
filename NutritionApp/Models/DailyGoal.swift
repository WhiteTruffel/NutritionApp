import Foundation
import SwiftData

@Model
final class DailyGoal {
    var date: Date
    var kcalTarget: Double
    var proteinTarget: Double

    init(date: Date, kcalTarget: Double, proteinTarget: Double) {
        self.date = date
        self.kcalTarget = kcalTarget
        self.proteinTarget = proteinTarget
    }
}
