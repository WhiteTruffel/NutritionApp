import Foundation

/// Kommerzielle Datenquelle (größerer Marken-/Restaurant-Katalog).
/// AKTIVIERUNG: eigene Zugangsdaten unter https://developer.nutritionix.com anlegen
/// und unten appID + appKey eintragen. Solange leer, ist der Provider inaktiv
/// (FoodSearchService überspringt ihn) – Open Food Facts läuft trotzdem.
struct NutritionixClient: FoodSearchProvider {

    // ▼▼▼ HIER deine Nutritionix-Zugangsdaten eintragen ▼▼▼
    static let appID  = ""   // x-app-id
    static let appKey = ""   // x-app-key
    // ▲▲▲ ----------------------------------------- ▲▲▲

    private static let base = "https://trackapi.nutritionix.com/v2"

    var sourceName: String { "Nutritionix" }
    var isEnabled: Bool { !Self.appID.isEmpty && !Self.appKey.isEmpty }

    // MARK: Suche (Instant-Endpoint → common + branded, je max. 20)

    func search(_ query: String) async throws -> [FoodSearchResult] {
        guard isEnabled else { return [] }
        var comps = URLComponents(string: "\(Self.base)/search/instant")!
        comps.queryItems = [URLQueryItem(name: "query", value: query)]
        var req = URLRequest(url: comps.url!)
        applyAuth(&req)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let decoded = try JSONDecoder().decode(NixInstantResponse.self, from: data)

        var results: [FoodSearchResult] = []
        for b in decoded.branded ?? [] {
            guard let name = b.food_name, let id = b.nix_item_id else { continue }
            results.append(FoodSearchResult(id: "nix:item:\(id)", name: name,
                                            brand: b.brand_name, barcode: nil, source: sourceName))
        }
        for c in decoded.common ?? [] {
            guard let name = c.food_name else { continue }
            results.append(FoodSearchResult(id: "nix:common:\(name)", name: name,
                                            brand: nil, barcode: nil, source: sourceName))
        }
        return results
    }

    // MARK: Nährwerte nachladen (branded → item, common → natural/nutrients)

    func hydrate(_ result: FoodSearchResult) async throws -> FoodSearchResult {
        guard isEnabled else { return result }
        let food: NixFood?
        if result.id.hasPrefix("nix:item:") {
            food = try await fetchItem(nixItemID: String(result.id.dropFirst("nix:item:".count)))
        } else {
            food = try await fetchNatural(query: result.name)
        }
        guard let f = food, let grams = f.serving_weight_grams, grams > 0 else { return result }

        func per100(_ v: Double?) -> Double? { v.map { $0 / grams * 100 } }
        var r = result
        r.kcalPer100g      = per100(f.nf_calories)
        r.proteinPer100g   = per100(f.nf_protein)
        r.carbsPer100g     = per100(f.nf_total_carbohydrate)
        r.fatPer100g       = per100(f.nf_total_fat)
        r.fiberPer100g     = per100(f.nf_dietary_fiber)
        r.sugarPer100g     = per100(f.nf_sugars)
        r.sodiumMgPer100g  = per100(f.nf_sodium)   // nf_sodium ist bereits in mg
        return r
    }

    // MARK: Intern

    private func applyAuth(_ req: inout URLRequest) {
        req.setValue(Self.appID, forHTTPHeaderField: "x-app-id")
        req.setValue(Self.appKey, forHTTPHeaderField: "x-app-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func fetchItem(nixItemID: String) async throws -> NixFood? {
        var comps = URLComponents(string: "\(Self.base)/search/item")!
        comps.queryItems = [URLQueryItem(name: "nix_item_id", value: nixItemID)]
        var req = URLRequest(url: comps.url!)
        applyAuth(&req)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(NixNutrientsResponse.self, from: data).foods?.first
    }

    private func fetchNatural(query: String) async throws -> NixFood? {
        var req = URLRequest(url: URL(string: "\(Self.base)/natural/nutrients")!)
        req.httpMethod = "POST"
        applyAuth(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(NixNutrientsResponse.self, from: data).foods?.first
    }
}

// MARK: - Decodables (Feldnamen entsprechen exakt den Nutritionix-JSON-Keys)

private struct NixInstantResponse: Decodable {
    let common: [NixCommonItem]?
    let branded: [NixBrandedItem]?
}

private struct NixCommonItem: Decodable {
    let food_name: String?
}

private struct NixBrandedItem: Decodable {
    let food_name: String?
    let brand_name: String?
    let nix_item_id: String?
}

private struct NixNutrientsResponse: Decodable {
    let foods: [NixFood]?
}

private struct NixFood: Decodable {
    let food_name: String?
    let brand_name: String?
    let nf_calories: Double?
    let nf_protein: Double?
    let nf_total_carbohydrate: Double?
    let nf_total_fat: Double?
    let nf_dietary_fiber: Double?
    let nf_sugars: Double?
    let nf_sodium: Double?
    let serving_weight_grams: Double?
}
