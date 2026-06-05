import Foundation

/// USDA FoodData Central – kostenlose, sehr genaue Datenbank (v. a. Grund-/US-Lebensmittel).
/// Läuft sofort mit "DEMO_KEY" (stark limitiert). Für regulären Betrieb einen eigenen,
/// kostenlosen Key auf https://fdc.nal.usda.gov/api-key-signup.html holen und unten eintragen.
struct USDAClient: FoodSearchProvider {

    /// UserDefaults-Schlüssel, unter dem der Nutzer seinen eigenen USDA-Key ablegt.
    static let apiKeyDefaultsKey = "usdaAPIKey"

    /// Nutzer-Key aus den Einstellungen; sonst DEMO_KEY (30/Std., 50/Tag – stark limitiert).
    static var apiKey: String {
        let k = (UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return k.isEmpty ? "DEMO_KEY" : k
    }

    private static let base = "https://api.nal.usda.gov/fdc/v1"

    var sourceName: String { "USDA" }
    var isEnabled: Bool { !Self.apiKey.isEmpty }

    func search(_ query: String) async throws -> [FoodSearchResult] {
        guard isEnabled else { return [] }
        var comps = URLComponents(string: "\(Self.base)/foods/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "20"),
            URLQueryItem(name: "dataType", value: "Branded,Foundation,SR Legacy"),
            URLQueryItem(name: "api_key", value: Self.apiKey)
        ]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 12

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        let decoded = try JSONDecoder().decode(FDCSearchResponse.self, from: data)

        return decoded.foods?.compactMap { food -> FoodSearchResult? in
            guard let name = food.description, !name.isEmpty else { return nil }
            // FDC liefert Nährwerte je 100 g; Zuordnung über die USDA-Nummern.
            func value(_ number: String) -> Double? {
                food.foodNutrients?.first { $0.nutrientNumber == number }?.value
            }
            // Mikronährstoffe (Vitamine/Mineralstoffe/Fett-Detail) einsammeln.
            var micros: [String: Double] = [:]
            for n in food.foodNutrients ?? [] {
                if let num = n.nutrientNumber, let v = n.value,
                   let def = NutrientCatalog.byUsdaNumber[num] {
                    micros[def.key] = v
                }
            }
            return FoodSearchResult(
                id: "usda:\(food.fdcId.map(String.init) ?? UUID().uuidString)",
                name: name.capitalizedFirst,
                brand: food.brandName ?? food.brandOwner,
                barcode: food.gtinUpc,
                source: sourceName,
                kcalPer100g: value("208"),
                proteinPer100g: value("203"),
                carbsPer100g: value("205"),
                fatPer100g: value("204"),
                saturatedFatPer100g: value("606"),
                fiberPer100g: value("291"),
                sugarPer100g: value("269"),
                sodiumMgPer100g: value("307"),   // bereits in mg
                micros: micros
            )
        } ?? []
    }

    /// Beim Auswählen den vollständigen Datensatz (`/food/{id}`) laden – erst dort stehen
    /// die kompletten Vitamine/Mineralstoffe. Füllt fehlende Makros + alle Mikros nach.
    func hydrate(_ result: FoodSearchResult) async throws -> FoodSearchResult {
        guard result.source == sourceName,
              let fdcId = result.id.split(separator: ":").last.map(String.init),
              Int(fdcId) != nil else { return result }
        var comps = URLComponents(string: "\(Self.base)/food/\(fdcId)")!
        comps.queryItems = [URLQueryItem(name: "api_key", value: Self.apiKey)]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let detail = try? JSONDecoder().decode(FDCFoodDetail.self, from: data) else { return result }

        func value(_ number: String) -> Double? {
            detail.foodNutrients?.first { $0.nutrient?.number == number }?.amount
        }
        var r = result
        r.kcalPer100g     = r.kcalPer100g     ?? value("208")
        r.proteinPer100g  = r.proteinPer100g  ?? value("203")
        r.carbsPer100g    = r.carbsPer100g    ?? value("205")
        r.fatPer100g      = r.fatPer100g      ?? value("204")
        r.saturatedFatPer100g = r.saturatedFatPer100g ?? value("606")
        r.fiberPer100g    = r.fiberPer100g    ?? value("291")
        r.sugarPer100g    = r.sugarPer100g    ?? value("269")
        r.sodiumMgPer100g = r.sodiumMgPer100g ?? value("307")

        var micros = r.micros
        for n in detail.foodNutrients ?? [] {
            if let num = n.nutrient?.number, let v = n.amount,
               let def = NutrientCatalog.byUsdaNumber[num] {
                micros[def.key] = v
            }
        }
        r.micros = micros
        return r
    }
}

// MARK: - Decodables

private struct FDCSearchResponse: Decodable {
    let foods: [FDCFood]?
}

private struct FDCFood: Decodable {
    let fdcId: Int?
    let description: String?
    let brandName: String?
    let brandOwner: String?
    let gtinUpc: String?
    let foodNutrients: [FDCNutrient]?
}

private struct FDCNutrient: Decodable {
    let nutrientNumber: String?
    let value: Double?
}

// Detail-Endpunkt `/food/{id}`: Nährstoffe als { nutrient: { number }, amount }.
private struct FDCFoodDetail: Decodable {
    let foodNutrients: [FDCDetailNutrient]?
}
private struct FDCDetailNutrient: Decodable {
    let nutrient: FDCNutrientInfo?
    let amount: Double?
}
private struct FDCNutrientInfo: Decodable {
    let number: String?
}

private extension String {
    /// "GRANOLA, OATS" → "Granola, oats" (FDC-Namen sind oft komplett groß).
    var capitalizedFirst: String {
        guard self == uppercased() else { return self }
        return prefix(1).uppercased() + dropFirst().lowercased()
    }
}
