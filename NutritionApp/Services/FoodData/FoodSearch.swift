import Foundation

/// Einheitliches Suchergebnis quer über alle Datenquellen (Nährwerte pro 100 g).
struct FoodSearchResult: Sendable, Identifiable, Equatable {
    let id: String          // z. B. "off:<barcode>" oder "nix:<id>"
    let name: String
    let brand: String?
    let barcode: String?
    let source: String      // "Open Food Facts" | "Nutritionix"

    var kcalPer100g: Double? = nil
    var proteinPer100g: Double? = nil
    var carbsPer100g: Double? = nil
    var fatPer100g: Double? = nil
    var saturatedFatPer100g: Double? = nil
    var fiberPer100g: Double? = nil
    var sugarPer100g: Double? = nil
    var sodiumMgPer100g: Double? = nil

    /// Herstellerdeklarierte Portionsgröße in Gramm (z. B. „1 Riegel = 20,7 g"), falls bekannt.
    var servingSizeG: Double? = nil

    /// Mikronährstoffe je 100 g (Schlüssel laut NutrientCatalog), v. a. aus USDA.
    var micros: [String: Double] = [:]

    /// Manche Quellen (Nutritionix) liefern Nährwerte erst bei Auswahl → bis dahin nil.
    var hasNutrients: Bool { kcalPer100g != nil }
}

/// Abstraktion über eine Lebensmittel-Datenquelle. Sendable, damit parallel abfragbar.
protocol FoodSearchProvider: Sendable {
    var sourceName: String { get }
    var isEnabled: Bool { get }
    func search(_ query: String) async throws -> [FoodSearchResult]
    /// Füllt fehlende Nährwerte nach (Default: Ergebnis ist bereits vollständig).
    func hydrate(_ result: FoodSearchResult) async throws -> FoodSearchResult
}

extension FoodSearchProvider {
    func hydrate(_ result: FoodSearchResult) async throws -> FoodSearchResult { result }
}

/// Aggregiert mehrere Provider: fragt alle aktiven parallel ab und führt die Treffer zusammen.
struct FoodSearchService: Sendable {
    let providers: [any FoodSearchProvider]

    static let shared = FoodSearchService(providers: [
        LocalFoodDatabase(),      // generische Grundnahrungsmittel zuerst (sofort, offline, DE+EN)
        CloudFoodDatabase(),      // zentrale CloudKit-DB (aktiv, sobald CloudFoodDatabase.isConfigured = true)
        OpenFoodFactsClient(),
        USDAClient(),
        NutritionixClient()
    ])

    func search(_ query: String) async -> [FoodSearchResult] {
        await withTaskGroup(of: [FoodSearchResult].self) { group in
            for provider in providers where provider.isEnabled {
                group.addTask { (try? await provider.search(query)) ?? [] }
            }
            var merged: [FoodSearchResult] = []
            for await partial in group { merged.append(contentsOf: partial) }

            // 1) RELEVANZ zur Suchanfrage zuerst – sonst versinkt der exakte Treffer
            //    („Corny Protein soft“) unter alphabetisch früheren Fremdtreffern.
            let qLower = query.lowercased().trimmingCharacters(in: .whitespaces)
            let qWords = qLower.split(separator: " ").map(String.init)
            func relevance(_ r: FoodSearchResult) -> Int {
                let name = r.name.lowercased()
                if name == qLower { return 1000 }                 // exakter Name
                var s = 0
                if name.hasPrefix(qLower) { s += 500 }            // beginnt mit Eingabe
                else if name.contains(qLower) { s += 250 }        // enthält ganze Eingabe
                let matched = qWords.filter { name.contains($0) }.count
                s += matched * 60                                 // je getroffenem Wort
                if !qWords.isEmpty, matched == qWords.count { s += 120 }  // alle Wörter da
                return s
            }
            // 2) Quelle nur noch als Gleichstand-Tiebreak (Basis-Grundnahrung leicht bevorzugt).
            func rank(_ r: FoodSearchResult) -> Int {
                switch r.source { case "Basis": return 0; case "Zentral": return 1; default: return 2 }
            }
            return merged.sorted {
                let a = relevance($0), b = relevance($1)
                if a != b { return a > b }
                if $0.hasNutrients != $1.hasNutrients { return $0.hasNutrients }
                if rank($0) != rank($1) { return rank($0) < rank($1) }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    func hydrate(_ result: FoodSearchResult) async throws -> FoodSearchResult {
        guard let provider = providers.first(where: { $0.sourceName == result.source }) else { return result }
        return try await provider.hydrate(result)
    }
}
