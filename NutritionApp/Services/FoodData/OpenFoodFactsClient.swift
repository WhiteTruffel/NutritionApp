import Foundation

/// Liest Produktdaten aus Open Food Facts (API v2). Keine Auth nötig,
/// aber aussagekräftiger User-Agent ist Pflicht (sonst Drosselung/Blockade).
struct OpenFoodFactsClient: FoodSearchProvider {
    static let userAgent = "NutritionApp/1.0 (tobiaskochberlin@me.com)"

    var sourceName: String { "Open Food Facts" }
    var isEnabled: Bool { true }   // kostenlos, kein Key nötig

    enum LookupError: Error { case notFound, badResponse }

    func product(barcode: String) async throws -> OFFProduct {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json")!
        comps.queryItems = [
            URLQueryItem(name: "fields",
                         value: "product_name,brands,serving_size,serving_quantity,nutrition_data_per,nutriments")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LookupError.badResponse
        }
        let envelope = try JSONDecoder().decode(OFFEnvelope.self, from: data)
        guard envelope.status == 1, let product = envelope.product else {
            throw LookupError.notFound
        }
        return product
    }

    // MARK: Namenssuche (cgi/search.pl). Rate-Limit ~10/min → in der UI entprellt.
    func search(_ query: String) async throws -> [FoodSearchResult] {
        var comps = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        comps.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields",
                         value: "code,product_name,brands,serving_size,nutrition_data_per,nutriments")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LookupError.badResponse
        }
        let envelope = try JSONDecoder().decode(OFFSearchEnvelope.self, from: data)
        return envelope.products.compactMap { p -> FoodSearchResult? in
            guard let name = p.productName, !name.isEmpty else { return nil }
            let n = p.nutriments
            return FoodSearchResult(
                id: "off:\(p.code ?? UUID().uuidString)",
                name: name,
                brand: p.brands?.isEmpty == false ? p.brands : nil,
                barcode: p.code,
                source: sourceName,
                kcalPer100g: n?.energyKcal100g,
                proteinPer100g: n?.proteins100g,
                carbsPer100g: n?.carbohydrates100g,
                fatPer100g: n?.fat100g,
                fiberPer100g: n?.fiber100g,
                sugarPer100g: n?.sugars100g,
                sodiumMgPer100g: n?.sodiumMgPer100g,
                servingSizeG: p.servingSizeGrams
            )
        }
    }
}
