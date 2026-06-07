import HealthKit
import Foundation

final class NutritionHealthStore {
    let store = HKHealthStore()

    func requestAuthorization() async throws {
        let types: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        ]

        try await store.requestAuthorization(toShare: types, read: types)
    }

    func saveHRVSample(hrv: Double) async throws {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let quantity = HKQuantity(unit: HKUnit.secondUnit(with: .milli), doubleValue: hrv)
        let sample = HKQuantitySample(type: hrvType, quantity: quantity, start: Date(), end: Date())

        try await store.save(sample)
    }

    func saveWater(ml: Double) async throws {
        let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        let quantity = HKQuantity(unit: HKUnit.milliliter(), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        try await store.save(sample)
    }

    func getRecentHRV() async throws -> Double? {
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            // Handle samples
        }

        store.execute(query)
        return nil // Simplified
    }
}
