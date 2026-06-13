import Foundation
import HealthKit

/// Kapselt ALLEN HealthKit-Zugriff in einem Aktor (Swift-6-Concurrency).
/// Kernregel: Eine Mahlzeit = EINE HKCorrelation(.food) mit allen Nährwerten.
actor NutritionHealthStore {
    private let store = HKHealthStore()

    enum HealthError: Error { case notAvailable }

    static let dietaryIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed, .dietaryProtein, .dietaryCarbohydrates,
        .dietaryFatTotal, .dietaryFiber, .dietarySugar, .dietarySodium
    ]

    /// Körperdaten, die wir nur LESEN (für die automatische Profil-Übernahme).
    static let bodyQuantityIdentifiers: [HKQuantityTypeIdentifier] = [
        .height, .bodyMass, .bodyFatPercentage, .leanBodyMass
    ]

    // MARK: Autorisierung
    // Für den Food-Korrelationstyp wird KEINE Berechtigung angefragt – HealthKit verbietet das
    // sowohl fürs Schreiben als auch fürs Lesen (NSInvalidArgumentException
    // "Authorization to share/read ... is disallowed: HKCorrelationTypeIdentifierFood").
    // Autorisiert werden ausschließlich die enthaltenen Quantity-Typen; Schreiben und Lesen der
    // Korrelation laufen über die Rechte ihrer Einzelwerte.
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.notAvailable }
        var share: Set<HKSampleType> = []
        var read: Set<HKObjectType> = []
        for id in Self.dietaryIdentifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                share.insert(t); read.insert(t)
            }
        }
        // Aktive Kalorien + Trainingszeit (Sport) nur lesen – Dashboard-Budget & Trends.
        for id in [HKQuantityTypeIdentifier.activeEnergyBurned, .appleExerciseTime] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { read.insert(t) }
        }
        // Workouts + Distanzen nur lesen – für den Training-Reiter.
        read.insert(HKObjectType.workoutType())
        for id in [HKQuantityTypeIdentifier.distanceWalkingRunning, .distanceCycling, .distanceSwimming, .stepCount] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { read.insert(t) }
        }
        // Körperdaten (nur lesen) für die automatische Profil-Übernahme.
        for id in Self.bodyQuantityIdentifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { read.insert(t) }
        }
        if let dob = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) { read.insert(dob) }
        if let bioSex = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) { read.insert(bioSex) }
        if let fitz = HKCharacteristicType.characteristicType(forIdentifier: .fitzpatrickSkinType) { read.insert(fitz) }
        // Gewicht, Wasser und Koffein auch schreiben dürfen.
        for id in [HKQuantityTypeIdentifier.bodyMass, .dietaryWater, .dietaryCaffeine] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { share.insert(t); read.insert(t) }
        }
        // Aktivität & Erholung nur lesen (für die Ringe).
        read.insert(HKObjectType.activitySummaryType())
        for id in [HKQuantityTypeIdentifier.heartRateVariabilitySDNN, .restingHeartRate] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { read.insert(t) }
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(sleep) }
        if let mind = HKCategoryType.categoryType(forIdentifier: .mindfulSession) { read.insert(mind) }
        try await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: Schreiben von Gewicht / Wasser / Koffein

    /// Heutige Schrittzahl seit Tagesbeginn. BL5.
    /// WICHTIG: NICHT alle Quellen summieren – iPhone, Apple Watch und Dritt-Apps schreiben je
    /// eigene Schritt-Samples; eine reine Summe verdoppelt/verdreifacht. Stattdessen `.separateBySource`
    /// und die Quelle mit den meisten Schritten nehmen (≈ Anzeige der Health-App).
    func todaySteps() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: [.cumulativeSum, .separateBySource]) { _, stats, _ in
                guard let stats else { cont.resume(returning: 0); return }
                let v = Self.bestSourceSteps(stats, unit: .count())
                    ?? stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: v)
            }
            store.execute(q)
        }
    }

    /// Datierte Schlafnächte (Stunden je Nacht, Datum = Aufwachtag) für Korrelationen (BL19).
    func sleepNightsDated(days: Int = 14) async -> [SleepNight] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<[SleepNight], Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let asleep = ((results as? [HKCategorySample]) ?? [])
                    .filter { Self.asleepValues.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) }.sorted { $0.start < $1.start }
                guard !asleep.isEmpty else { cont.resume(returning: []); return }
                var merged: [(start: Date, end: Date)] = []
                for iv in asleep {
                    if var last = merged.last, iv.start <= last.end {
                        last.end = max(last.end, iv.end); merged[merged.count - 1] = last
                    } else { merged.append(iv) }
                }
                var nights: [SleepNight] = []
                var acc = 0.0; var prevEnd: Date?; var sessEnd: Date?
                for iv in merged {
                    if let pe = prevEnd, iv.start.timeIntervalSince(pe) > 3 * 3600 {
                        if let e = sessEnd { nights.append(SleepNight(date: Calendar.current.startOfDay(for: e), hours: acc / 3600)) }
                        acc = 0
                    }
                    acc += iv.end.timeIntervalSince(iv.start); prevEnd = iv.end; sessEnd = iv.end
                }
                if let e = sessEnd { nights.append(SleepNight(date: Calendar.current.startOfDay(for: e), hours: acc / 3600)) }
                cont.resume(returning: nights)
            }
            store.execute(q)
        }
    }

    /// Heutige Achtsamkeits-/Meditationsminuten (für die Erholung). Sauna/Atemübungen, die
    /// als Achtsamkeit in Health landen, zählen mit.
    func todayMindfulMinutes() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                let mins = ((results as? [HKCategorySample]) ?? [])
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60
                cont.resume(returning: mins)
            }
            store.execute(q)
        }
    }

    func saveWeight(kg: Double, date: Date = .now) async {
        _ = await saveQuantity(.bodyMass, value: kg, unit: .gramUnit(with: .kilo), date: date)
    }
    /// Speichert Wasser und liefert die UUID des HK-Samples (für spätere Lösch-Propagation, Issue #2).
    @discardableResult
    func saveWater(ml: Double, date: Date = .now) async -> UUID? {
        await saveQuantity(.dietaryWater, value: ml, unit: .literUnit(with: .milli), date: date)
    }
    /// Speichert Koffein und liefert die UUID des HK-Samples (für spätere Lösch-Propagation, Issue #2).
    @discardableResult
    func saveCaffeine(mg: Double, date: Date = .now) async -> UUID? {
        await saveQuantity(.dietaryCaffeine, value: mg, unit: .gramUnit(with: .milli), date: date)
    }

    /// Saves HRV measurement to HealthKit (in milliseconds).
    func saveHRVSample(hrv: Double, date: Date = .now) async -> UUID? {
        await saveQuantity(.heartRateVariabilitySDNN, value: hrv, unit: HKUnit.secondUnit(with: .milli), date: date)
    }

    private func saveQuantity(_ id: HKQuantityTypeIdentifier, value: Double, unit: HKUnit, date: Date) async -> UUID? {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let sample = HKQuantitySample(type: type,
                                      quantity: HKQuantity(unit: unit, doubleValue: value),
                                      start: date, end: date)
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Löscht das eigene Wasser-/Koffein-Sample zu einer beim Schreiben gemerkten UUID (Issue #2).
    /// Einträge ohne UUID (Bestandsdaten) rufen das nie auf; nicht (mehr) vorhandene Samples sind ein No-op.
    /// HealthKit erlaubt ohnehin nur das Löschen App-eigener Samples.
    func deleteIntakeSample(uuid: UUID, kind: IntakeKind) async {
        let id: HKQuantityTypeIdentifier = (kind == .water) ? .dietaryWater : .dietaryCaffeine
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
        let predicate = HKQuery.predicateForObject(with: uuid)
        let samples: [HKSample] = await withCheckedContinuation { (cont: CheckedContinuation<[HKSample], Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: 1, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: results ?? [])
            }
            store.execute(q)
        }
        guard !samples.isEmpty else { return }
        try? await store.delete(samples)
    }

    // MARK: Workouts lesen (Training-Reiter)

    /// Liest die letzten Workouts (Standard: 14 Tage), neueste zuerst.
    func fetchWorkouts(days: Int = 14, limit: Int = 60) async -> [WorkoutSummary] {
        guard HKHealthStore.isHealthDataAvailable(),
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return workouts.map { w in
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            var meters: Double?
            for dt in [HKQuantityType(.distanceWalkingRunning),
                       HKQuantityType(.distanceCycling),
                       HKQuantityType(.distanceSwimming)] {
                if let m = w.statistics(for: dt)?.sumQuantity()?.doubleValue(for: .meter()) {
                    meters = (meters ?? 0) + m
                }
            }
            return WorkoutSummary(
                id: w.uuid,
                name: w.workoutActivityType.germanName,
                symbol: w.workoutActivityType.symbolName,
                start: w.startDate,
                durationMin: w.duration / 60,
                kcal: kcal,
                distanceMeters: meters
            )
        }
    }

    // MARK: Körperdaten aus Apple Health lesen

    /// Liest Geschlecht, Alter, Größe, Gewicht, Körperfett und Magermasse (neueste Werte).
    /// Fehlende/nicht freigegebene Werte bleiben nil.
    func readBodyData() async -> BodyData {
        guard HKHealthStore.isHealthDataAvailable() else { return BodyData() }
        var data = BodyData()

        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .male:   data.sex = .male
            case .female: data.sex = .female
            default:      break
            }
        }
        if let dob = try? store.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: dob) {
            data.age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year
        }

        data.heightCm       = await latestValue(.height)
        data.weightKg       = await latestValue(.bodyMass)
        data.bodyFatPercent = await latestValue(.bodyFatPercentage)
        data.leanBodyMassKg = await latestValue(.leanBodyMass)
        return data
    }

    /// Reads the Fitzpatrick skin type characteristic from Apple Health.
    /// Returns nil if Health is unavailable or the user has not set it (notSet).
    func readFitzpatrickSkinType() -> FitzpatrickSkinType? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let obj = try? store.fitzpatrickSkinType() else { return nil }
        switch obj.skinType {
        case .I:   return .typeI
        case .II:  return .typeII
        case .III: return .typeIII
        case .IV:  return .typeIV
        case .V:   return .typeV
        case .VI:  return .typeVI
        default:   return nil
        }
    }

    private func latestValue(_ id: HKQuantityTypeIdentifier) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, results, _ in
                guard let quantity = (results?.first as? HKQuantitySample)?.quantity else {
                    cont.resume(returning: nil); return
                }
                let unit: HKUnit
                switch id {
                case .height:                   unit = .meterUnit(with: .centi)
                case .bodyMass, .leanBodyMass:  unit = .gramUnit(with: .kilo)
                case .bodyFatPercentage:        unit = .percent()
                case .heartRateVariabilitySDNN: unit = .secondUnit(with: .milli)
                case .restingHeartRate:         unit = HKUnit.count().unitDivided(by: .minute())
                default:                        unit = .count()
                }
                var value = quantity.doubleValue(for: unit)
                if id == .bodyFatPercentage { value *= 100 }   // Bruchteil → Prozent
                cont.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Heute verbrannte aktive Kalorien (kcal). Liefert 0, wenn nicht verfügbar/keine Daten
    /// (z. B. im Simulator) – nie ein Fehler, damit das Dashboard robust bleibt.
    func todayActiveEnergy() async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                cont.resume(returning: kcal)
            }
            store.execute(query)
        }
    }

    // MARK: Tagesreihen für Trends (generisch)

    /// „Beste" Schrittzahl aus den Quellen-Statistiken: bevorzugt **Apple-eigene Quellen**
    /// (iPhone/Watch, Bundle „com.apple…") und nimmt davon die höchste (sie überlappen →
    /// ≈ echter Wert). Dritt-Apps, die oft den Tag aufsummieren/überzählen, werden so
    /// ausgeschlossen – analog zur Quellen-Priorisierung der Health-App.
    private static func bestSourceSteps(_ stats: HKStatistics, unit: HKUnit) -> Double? {
        let sources = stats.sources ?? []
        let apple = sources.filter { $0.bundleIdentifier.hasPrefix("com.apple") }
        let pick = apple.isEmpty ? sources : apple
        let vals = pick.compactMap { stats.sumQuantity(for: $0)?.doubleValue(for: unit) }
        return vals.max()
    }

    /// Passende Einheit je Kennung (HKUnit ist nicht Sendable → intern ableiten, nicht übergeben).
    private static func unit(for id: HKQuantityTypeIdentifier) -> HKUnit {
        switch id {
        case .restingHeartRate:         return HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariabilitySDNN: return .secondUnit(with: .milli)
        case .stepCount:                return .count()
        case .appleExerciseTime:        return .minute()
        case .activeEnergyBurned:       return .kilocalorie()
        case .bodyMass:                 return .gramUnit(with: .kilo)
        case .bodyFatPercentage:        return .percent()
        default:                        return .count()
        }
    }

    /// Tageswerte einer Quantity über `days` Tage – Summe (Schritte, kcal) oder Tagesschnitt
    /// (Ruhepuls, HRV, Gewicht). Lücken (Tage ohne Messung) werden ausgelassen.
    func dailySeries(_ id: HKQuantityTypeIdentifier, days: Int, stat: TrendStat) async -> [DayValue] {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let unit = Self.unit(for: id)
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: .now)
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: anchor) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        // Schritte über Quellen NICHT summieren (Doppelzählung iPhone/Watch/Dritt-Apps) → stärkste Quelle.
        let isSteps = (id == .stepCount)
        let options: HKStatisticsOptions = isSteps ? [.cumulativeSum, .separateBySource]
                                                   : ((stat == .sum) ? .cumulativeSum : .discreteAverage)
        return await withCheckedContinuation { (cont: CheckedContinuation<[DayValue], Never>) in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: options, anchorDate: anchor,
                                                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, collection, _ in
                var out: [DayValue] = []
                collection?.enumerateStatistics(from: start, to: .now) { s, _ in
                    let v: Double?
                    if isSteps {
                        v = Self.bestSourceSteps(s, unit: unit) ?? s.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        v = ((stat == .sum) ? s.sumQuantity() : s.averageQuantity())?.doubleValue(for: unit)
                    }
                    if let v { out.append(DayValue(date: s.startDate, value: v)) }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    // MARK: Schreiben
    func save(_ meal: MealPayload) async throws {
        var samples: Set<HKSample> = []

        func add(_ id: HKQuantityTypeIdentifier, _ value: Double?, _ unit: HKUnit) {
            guard let value, value >= 0,
                  let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
            let q = HKQuantity(unit: unit, doubleValue: value)
            samples.insert(HKQuantitySample(type: type, quantity: q,
                                            start: meal.date, end: meal.date))
        }

        add(.dietaryEnergyConsumed, meal.kcal,     .kilocalorie())
        add(.dietaryProtein,        meal.proteinG, .gram())
        add(.dietaryCarbohydrates,  meal.carbsG,   .gram())
        add(.dietaryFatTotal,       meal.fatG,     .gram())
        add(.dietaryFiber,          meal.fiberG,   .gram())
        add(.dietarySugar,          meal.sugarG,   .gram())
        add(.dietarySodium,         meal.sodiumMg, .gramUnit(with: .milli))

        guard !samples.isEmpty,
              let foodType = HKCorrelationType.correlationType(forIdentifier: .food) else { return }

        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: meal.name,
            HKMetadataKeyExternalUUID: meal.id.uuidString   // Dedup / idempotenter Re-Sync
        ]
        let correlation = HKCorrelation(type: foodType, start: meal.date, end: meal.date,
                                        objects: samples, metadata: metadata)
        try await store.save(correlation)
    }

    // MARK: Löschen (nur eigene, per externer UUID identifizierte Mahlzeiten)
    func delete(mealID: UUID) async throws {
        let foodType = HKCorrelationType.correlationType(forIdentifier: .food)!
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID,
                                                    allowedValues: [mealID.uuidString])
        let samples: [HKSample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: foodType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: results ?? []) }
            }
            store.execute(q)
        }
        guard !samples.isEmpty else { return }
        try await store.delete(samples)
    }

    // MARK: Import (HealthKit → App) – inkrementell per Anchor

    /// Liest neue/geänderte `.food`-Korrelationen seit dem gespeicherten Anchor.
    /// Gibt Sendable-DTOs + den neuen (kodierten) Anchor zurück.
    func importNewMeals(anchor anchorData: Data?) async -> (meals: [ImportedMeal], anchor: Data?) {
        guard HKHealthStore.isHealthDataAvailable(),
              let foodType = HKCorrelationType.correlationType(forIdentifier: .food)
        else { return ([], anchorData) }

        let anchor = anchorData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<(meals: [ImportedMeal], anchor: Data?), Never>) in
            let query = HKAnchoredObjectQuery(type: foodType, predicate: nil,
                                              anchor: anchor, limit: HKObjectQueryNoLimit) { _, samples, _, newAnchor, _ in
                let correlations = (samples as? [HKCorrelation]) ?? []
                let meals = correlations.map { Self.makeImportedMeal($0) }
                let newAnchorData = newAnchor.flatMap {
                    try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
                }
                cont.resume(returning: (meals, newAnchorData ?? anchorData))
            }
            store.execute(query)
        }
    }

    /// Observer + Background Delivery: ruft `onChange` auf, sobald (andere) Apps Ernährungsdaten schreiben.
    /// Benötigt die Capability „HealthKit ▸ Background Delivery" (in Xcode aktivieren) und ein echtes Gerät.
    func startBackgroundDelivery(onChange: @escaping @Sendable () async -> Void) async {
        guard HKHealthStore.isHealthDataAvailable(),
              let foodType = HKCorrelationType.correlationType(forIdentifier: .food) else { return }
        let observer = HKObserverQuery(sampleType: foodType, predicate: nil) { _, completionHandler, _ in
            Task { await onChange(); completionHandler() }
        }
        store.execute(observer)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            store.enableBackgroundDelivery(for: foodType, frequency: .immediate) { _, _ in cont.resume() }
        }
    }

    /// Baut aus einer HK-Korrelation ein Sendable-DTO (läuft im Query-Callback, gibt nur Werttypen zurück).
    private static func makeImportedMeal(_ correlation: HKCorrelation) -> ImportedMeal {
        let name = correlation.metadata?[HKMetadataKeyFoodType] as? String ?? "Mahlzeit"
        let isOwn = correlation.metadata?[HKMetadataKeyExternalUUID] != nil
        var meal = ImportedMeal(hkUUID: correlation.uuid, name: name, date: correlation.startDate, isOwn: isOwn)
        for case let q as HKQuantitySample in correlation.objects {
            switch q.quantityType.identifier {
            case HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: meal.kcal = q.quantity.doubleValue(for: .kilocalorie())
            case HKQuantityTypeIdentifier.dietaryProtein.rawValue:        meal.proteinG = q.quantity.doubleValue(for: .gram())
            case HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue:  meal.carbsG = q.quantity.doubleValue(for: .gram())
            case HKQuantityTypeIdentifier.dietaryFatTotal.rawValue:       meal.fatG = q.quantity.doubleValue(for: .gram())
            case HKQuantityTypeIdentifier.dietaryFiber.rawValue:          meal.fiberG = q.quantity.doubleValue(for: .gram())
            case HKQuantityTypeIdentifier.dietarySugar.rawValue:          meal.sugarG = q.quantity.doubleValue(for: .gram())
            case HKQuantityTypeIdentifier.dietarySodium.rawValue:         meal.sodiumMg = q.quantity.doubleValue(for: .gramUnit(with: .milli))
            default: break
            }
        }
        return meal
    }

    // MARK: Aktivitätsringe & Erholung

    /// Heutige Aktivitätszusammenfassung (Move/Exercise/Stand) inkl. Ziele.
    func todayActivity() async -> ActivityRings? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: .now)
        comps.calendar = cal
        let predicate = HKQuery.predicateForActivitySummary(with: comps)
        return await withCheckedContinuation { (cont: CheckedContinuation<ActivityRings?, Never>) in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
                guard let s = summaries?.first else { cont.resume(returning: nil); return }
                let rings = ActivityRings(
                    moveKcal: s.activeEnergyBurned.doubleValue(for: .kilocalorie()),
                    moveGoal: s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie()),
                    exerciseMin: s.appleExerciseTime.doubleValue(for: .minute()),
                    exerciseGoal: s.appleExerciseTimeGoal.doubleValue(for: .minute()),
                    standHours: s.appleStandHours.doubleValue(for: .count()),
                    standGoal: s.appleStandHoursGoal.doubleValue(for: .count()))
                cont.resume(returning: rings)
            }
            store.execute(query)
        }
    }

    /// Vereinfachter Erholungs-/Bereitschaftsscore (0–100) aus HRV, Ruhepuls und Schlaf,
    /// jeweils gegen den 30-Tage-Schnitt. Bewusst transparent & informativ – kein Messwert.
    func readiness() async -> ReadinessResult? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let hrv = await latestValue(.heartRateVariabilitySDNN)
        let rhr = await latestValue(.restingHeartRate)
        let hrvAvg = await average(.heartRateVariabilitySDNN, days: 30)
        let rhrAvg = await average(.restingHeartRate, days: 30)
        let sleep = await lastSleepHours()

        var sum = 0.0, weight = 0.0
        if let h = hrv, let ha = hrvAvg, ha > 0 { sum += min(h / ha, 1.2) / 1.2 * 0.4; weight += 0.4 }
        if let r = rhr, let ra = rhrAvg, r > 0 { sum += min(ra / r, 1.2) / 1.2 * 0.3; weight += 0.3 }
        if let s = sleep                       { sum += min(s / 8, 1) * 0.3;          weight += 0.3 }
        guard weight > 0 else { return nil }
        let score = Int((sum / weight * 100).rounded())
        return ReadinessResult(score: score, hrv: hrv, rhr: rhr, sleepHours: sleep)
    }

    private func average(_ id: HKQuantityTypeIdentifier, days: Int) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id),
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                          options: .discreteAverage) { _, stats, _ in
                let unit: HKUnit = (id == .heartRateVariabilitySDNN)
                    ? .secondUnit(with: .milli)
                    : HKUnit.count().unitDivided(by: .minute())
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func lastSleepHours() async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let start = Calendar.current.date(byAdding: .hour, value: -36, to: .now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let asleep: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                // Nur „asleep"-Intervalle (kein „inBed"), zeitlich sortiert.
                let intervals = ((results as? [HKCategorySample]) ?? [])
                    .filter { asleep.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) }
                    .sorted { $0.start < $1.start }
                guard !intervals.isEmpty else { cont.resume(returning: nil); return }

                // Überlappende/aneinandergrenzende Intervalle VEREINIGEN → verhindert
                // Doppelzählung, wenn mehrere Quellen (Uhr + iPhone + Drittapp) parallel schreiben.
                var merged: [(start: Date, end: Date)] = []
                for iv in intervals {
                    if var last = merged.last, iv.start <= last.end {
                        last.end = max(last.end, iv.end)
                        merged[merged.count - 1] = last
                    } else {
                        merged.append(iv)
                    }
                }
                // Nur die LETZTE zusammenhängende Schlafphase zählen (Sessions trennt eine Lücke > 3 h),
                // damit nicht zwei Nächte aus dem 36-h-Fenster summiert werden.
                var sessionStart = 0
                if merged.count > 1 {
                    for i in 1..<merged.count where merged[i].start.timeIntervalSince(merged[i-1].end) > 3*3600 {
                        sessionStart = i
                    }
                }
                let seconds = merged[sessionStart...].reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                cont.resume(returning: seconds > 0 ? seconds / 3600 : nil)
            }
            store.execute(query)
        }
    }

    // MARK: Schlaf-Details (Erholungs-Reiter)

    private static let asleepValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
    ]

    /// Letzte zusammenhängende Schlafphase mit Phasen-Aufteilung (Tief/REM/Kern/Wach).
    func lastNightSleep() async -> SleepSummary? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let start = Calendar.current.date(byAdding: .hour, value: -36, to: .now) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<SleepSummary?, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let samples = (results as? [HKCategorySample]) ?? []
                let asleep = samples.filter { Self.asleepValues.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) }.sorted { $0.start < $1.start }
                guard !asleep.isEmpty else { cont.resume(returning: nil); return }

                var merged: [(start: Date, end: Date)] = []
                for iv in asleep {
                    if var last = merged.last, iv.start <= last.end {
                        last.end = max(last.end, iv.end); merged[merged.count - 1] = last
                    } else { merged.append(iv) }
                }
                var sessionStart = 0
                if merged.count > 1 {
                    for i in 1..<merged.count where merged[i].start.timeIntervalSince(merged[i-1].end) > 3*3600 {
                        sessionStart = i
                    }
                }
                let session = Array(merged[sessionStart...])
                guard let winStart = session.first?.start, let winEnd = session.last?.end else {
                    cont.resume(returning: nil); return
                }
                func dur(_ vals: Set<Int>) -> Double {
                    samples.filter { vals.contains($0.value) && $0.endDate > winStart && $0.startDate < winEnd }
                        .reduce(0.0) { $0 + min($1.endDate, winEnd).timeIntervalSince(max($1.startDate, winStart)) }
                }
                let deep = dur([HKCategoryValueSleepAnalysis.asleepDeep.rawValue])
                let rem  = dur([HKCategoryValueSleepAnalysis.asleepREM.rawValue])
                let core = dur([HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue])
                let awake = dur([HKCategoryValueSleepAnalysis.awake.rawValue])
                let total = session.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
                cont.resume(returning: SleepSummary(
                    totalHours: total/3600, deepHours: deep/3600, remHours: rem/3600,
                    coreHours: core/3600, awakeHours: awake/3600, start: winStart, end: winEnd))
            }
            store.execute(q)
        }
    }

    /// Nächtliche Schlafdauern (Stunden) der letzten `days` Tage – für den 7-Tage-Schnitt.
    func sleepHoursHistory(days: Int = 7) async -> [Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<[Double], Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let asleep = ((results as? [HKCategorySample]) ?? [])
                    .filter { Self.asleepValues.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) }.sorted { $0.start < $1.start }
                guard !asleep.isEmpty else { cont.resume(returning: []); return }
                var merged: [(start: Date, end: Date)] = []
                for iv in asleep {
                    if var last = merged.last, iv.start <= last.end {
                        last.end = max(last.end, iv.end); merged[merged.count - 1] = last
                    } else { merged.append(iv) }
                }
                // In Sessions (Nächte) splitten: Lücke > 3 h trennt.
                var sessions: [Double] = []
                var acc = 0.0
                var prevEnd: Date?
                for iv in merged {
                    if let pe = prevEnd, iv.start.timeIntervalSince(pe) > 3*3600 { sessions.append(acc); acc = 0 }
                    acc += iv.end.timeIntervalSince(iv.start)
                    prevEnd = iv.end
                }
                sessions.append(acc)
                cont.resume(returning: sessions.map { $0/3600 }.filter { $0 >= 1.5 })
            }
            store.execute(q)
        }
    }

    // MARK: Gewichtsverlauf aus Apple Health

    /// Alle Gewichts-Messpunkte der letzten `days` Tage (für Verlauf + adaptiven Umsatz).
    func readWeightHistory(days: Int = 365) async -> [WeightSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { (cont: CheckedContinuation<[WeightSample], Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, results, _ in
                let samples = (results as? [HKQuantitySample]) ?? []
                let out = samples.map {
                    WeightSample(uuid: $0.uuid, date: $0.startDate,
                                 kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }
}

/// Gewichts-Messpunkt aus Apple Health (Sendable-DTO).
struct WeightSample: Sendable {
    let uuid: UUID
    let date: Date
    let kg: Double
}

/// Schlaf-Zusammenfassung einer Nacht (Stunden je Phase).
struct SleepSummary: Sendable {
    var totalHours: Double
    var deepHours: Double
    var remHours: Double
    var coreHours: Double
    var awakeHours: Double
    var start: Date?
    var end: Date?
}

/// Aktivitätsringe (Werte + Ziele).
struct ActivityRings: Sendable {
    var moveKcal: Double; var moveGoal: Double
    var exerciseMin: Double; var exerciseGoal: Double
    var standHours: Double; var standGoal: Double
}

/// Vereinfachter Erholungs-Score + Roh-Kennzahlen.
struct ReadinessResult: Sendable {
    var score: Int
    var hrv: Double?
    var rhr: Double?
    var sleepHours: Double?
}

/// Sendable-DTO einer aus Apple Health gelesenen Mahlzeit (absolute Werte der Korrelation).
struct ImportedMeal: Sendable {
    let hkUUID: UUID
    let name: String
    let date: Date
    let isOwn: Bool          // true = von unserer App geschrieben (ExternalUUID gesetzt) → überspringen
    var kcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var sugarG: Double?
    var sodiumMg: Double?
}

/// Eine datierte Schlafnacht (Stunden, Datum = Aufwachtag).
struct SleepNight: Sendable { let date: Date; let hours: Double }

/// Ein Tageswert einer Trend-Reihe (Datum = Tagesbeginn).
struct DayValue: Sendable, Identifiable { let date: Date; let value: Double; var id: Date { date } }

/// Aggregationsart einer Tagesreihe.
enum TrendStat: Sendable { case sum, average }

/// Sendable-Snapshot der aus Apple Health gelesenen Körperdaten.
struct BodyData: Sendable {
    var sex: Sex?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var bodyFatPercent: Double?
    var leanBodyMassKg: Double?

    var hasAny: Bool {
        sex != nil || age != nil || heightCm != nil || weightKg != nil
            || bodyFatPercent != nil || leanBodyMassKg != nil
    }
}
