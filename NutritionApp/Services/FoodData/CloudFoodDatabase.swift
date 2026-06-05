import Foundation
import CloudKit

/// Lese-Provider für die ZENTRALE Lebensmittel-Datenbank in der öffentlichen CloudKit-DB.
/// Apple-gehostet, kostenlos im Developer-Programm. Wird zentral (durch einen Befüll-Agenten)
/// gepflegt und wächst, OHNE dass die App neu gebaut werden muss.
///
/// WICHTIG: vorerst über `isConfigured` DEAKTIVIERT. Erst einschalten, wenn
///  1. die iCloud/CloudKit-Capability + der Container im Xcode-Target aktiv sind, und
///  2. der Record-Typ „Food" in der CloudKit-DB existiert und befüllt ist.
/// Solange aus = der Provider wird übersprungen, die App läuft unverändert weiter.
struct CloudFoodDatabase: FoodSearchProvider {

    /// Auf true setzen, sobald Container + Schema + Daten stehen (siehe CloudKit-Plan).
    static let isConfigured = true

    /// Record-Typ in der öffentlichen CloudKit-Datenbank.
    static let recordType = "Food"

    var sourceName: String { "Zentral" }
    var isEnabled: Bool { Self.isConfigured }

    func search(_ query: String) async throws -> [FoodSearchResult] {
        guard Self.isConfigured else { return [] }
        let q = query.folding(options: .diacriticInsensitive, locale: .current)
                     .lowercased().trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }

        // Tokens-Feld (Liste kleingeschriebener Suchbegriffe) ist in CloudKit zuverlässig
        // abfragbar: „tokens CONTAINS <wort>". Mehrwort-Anfragen: erstes Token serverseitig,
        // Rest clientseitig filtern.
        let words = q.split(separator: " ").map(String.init).filter { $0.count >= 2 }
        let primary = words.first ?? q
        let predicate = NSPredicate(format: "tokens CONTAINS %@", primary)
        let ckQuery = CKQuery(recordType: Self.recordType, predicate: predicate)

        let db = CKContainer.default().publicCloudDatabase
        let records: [CKRecord] = await withCheckedContinuation { cont in
            let op = CKQueryOperation(query: ckQuery)
            op.resultsLimit = 40
            var found: [CKRecord] = []
            if #available(iOS 15.0, *) {
                op.recordMatchedBlock = { _, result in
                    if case .success(let rec) = result { found.append(rec) }
                }
                op.queryResultBlock = { _ in cont.resume(returning: found) }
            } else {
                op.recordFetchedBlock = { found.append($0) }
                op.queryCompletionBlock = { _, _ in cont.resume(returning: found) }
            }
            db.add(op)
        }

        let extraWords = words.dropFirst()
        return records.compactMap { rec -> FoodSearchResult? in
            guard let name = rec["name"] as? String, !name.isEmpty else { return nil }
            // Mehrwort: nur Treffer behalten, die alle weiteren Wörter enthalten.
            if !extraWords.isEmpty {
                let toks = (rec["tokens"] as? [String]) ?? []
                let nameFold = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                let ok = extraWords.allSatisfy { w in toks.contains(w) || nameFold.contains(w) }
                guard ok else { return nil }
            }
            func d(_ key: String) -> Double? { (rec[key] as? Double) ?? (rec[key] as? NSNumber)?.doubleValue }
            return FoodSearchResult(
                id: "zentral:\(rec.recordID.recordName)",
                name: name,
                brand: rec["brand"] as? String,
                barcode: rec["barcode"] as? String,
                source: sourceName,
                kcalPer100g: d("kcal"),
                proteinPer100g: d("protein"),
                carbsPer100g: d("carbs"),
                fatPer100g: d("fat"),
                fiberPer100g: d("fiber"),
                sugarPer100g: d("sugar"),
                sodiumMgPer100g: d("sodiumMg")
            )
        }
    }
}
