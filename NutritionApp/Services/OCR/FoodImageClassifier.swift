import Vision
import UIKit

// MARK: - Gemini-Bilderkennung (Cloud, optional)

/// Ergebnis der KI-Gerichtserkennung. Alle Nährwerte je 100 g.
struct GeminiFoodResult: Sendable {
    var name: String
    var portionGrams: Double?
    var portionLabel: String?
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
}

/// Cloud-Bilderkennung über Google Gemini Flash. Erkennt KONKRETE Gerichte auf Deutsch
/// und schätzt Nährwerte – deutlich besser als der generische On-Device-Klassifikator.
///
/// Datenschutz: das Foto wird zur Analyse an Google gesendet.
/// Der API-Key wird vom Nutzer in den Einstellungen eingetragen und nur lokal gespeichert.
enum GeminiFoodVision {

    /// UserDefaults-Schlüssel, unter dem der Nutzer seinen Gemini-API-Key ablegt.
    static let apiKeyDefaultsKey = "geminiAPIKey"

    /// Flash-Modell – günstig und im Gratis-Tier verfügbar. Bei Bedarf hier anpassen.
    static let model = "gemini-2.5-flash"

    enum VisionError: LocalizedError {
        case noKey, badImage, http(Int), empty, decode
        var errorDescription: String? {
            switch self {
            case .noKey:        return "kein API-Key hinterlegt"
            case .badImage:     return "Bild konnte nicht verarbeitet werden"
            case .http(let c):  return "Serverfehler \(c)"
            case .empty:        return "leere Antwort"
            case .decode:       return "Antwort nicht lesbar"
            }
        }
    }

    static var apiKey: String {
        (UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var isConfigured: Bool { !apiKey.isEmpty }

    /// Sendet ein JPEG an Gemini und liefert die Gericht-Schätzung zurück.
    /// `jpegData` wird bewusst außerhalb (MainActor) erzeugt → keine UIImage-Sendable-Probleme.
    static func recognize(jpegData: Data) async throws -> GeminiFoodResult {
        let key = apiKey
        guard !key.isEmpty else { throw VisionError.noKey }
        guard !jpegData.isEmpty else { throw VisionError.badImage }

        let prompt = """
        Du bist Ernährungsexperte. Analysiere das Foto und erkenne das wichtigste Gericht oder Lebensmittel.
        Antworte AUSSCHLIESSLICH mit JSON in genau diesem Format, ohne weiteren Text:
        {"name":"deutscher Name des Gerichts","portionLabel":"kurze Portionsbezeichnung","portionGrams":Zahl,"kcalPer100g":Zahl,"proteinPer100g":Zahl,"carbsPer100g":Zahl,"fatPer100g":Zahl}
        portionLabel = natürliche Einheit der sichtbaren Portion, z. B. "1 Hamburger", "1 Teller", "1 Glas", "1 Schüssel".
        portionGrams = geschätztes Gewicht genau dieser sichtbaren Portion in Gramm (NICHT 100, sondern realistisch fürs ganze Gericht).
        Nährwerte realistisch je 100 g. Wenn kein Essen erkennbar ist, gib {"name":""} zurück.
        """

        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg",
                                     "data": jpegData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.2,
                "responseMimeType": "application/json"
            ]
        ]

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw VisionError.noKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw VisionError.http(status) }

        // Gemini-Hülle auspacken: candidates[0].content.parts[0].text
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw VisionError.empty
        }
        return try parseJSON(text)
    }

    /// Robustes Parsen: entfernt evtl. ```-Codezäune und liest die Felder tolerant.
    static func parseJSON(_ text: String) throws -> GeminiFoodResult {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let d = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
            throw VisionError.decode
        }
        func num(_ key: String) -> Double? {
            if let v = obj[key] as? Double { return v }
            if let v = obj[key] as? Int { return Double(v) }
            if let v = obj[key] as? NSNumber { return v.doubleValue }
            if let v = obj[key] as? String { return Double(v.replacingOccurrences(of: ",", with: ".")) }
            return nil
        }
        let portionLabel = (obj["portionLabel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GeminiFoodResult(
            name: (obj["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            portionGrams: num("portionGrams"),
            portionLabel: (portionLabel?.isEmpty == false) ? portionLabel : nil,
            kcalPer100g: num("kcalPer100g"),
            proteinPer100g: num("proteinPer100g"),
            carbsPer100g: num("carbsPer100g"),
            fatPer100g: num("fatPer100g")
        )
    }

    /// Erkennt ALLE Komponenten eines Tellerfotos einzeln (BL12) – z. B. Reis + Hähnchen + Salat.
    static func recognizeMulti(jpegData: Data) async throws -> [GeminiFoodResult] {
        let key = apiKey
        guard !key.isEmpty else { throw VisionError.noKey }
        guard !jpegData.isEmpty else { throw VisionError.badImage }

        let prompt = """
        Du bist Ernährungsexperte. Erkenne ALLE einzelnen Lebensmittel/Komponenten auf dem Foto getrennt.
        Antworte AUSSCHLIESSLICH mit einem JSON-Array, ohne weiteren Text. Jedes Element:
        {"name":"deutscher Name","portionGrams":Zahl,"kcalPer100g":Zahl,"proteinPer100g":Zahl,"carbsPer100g":Zahl,"fatPer100g":Zahl}
        portionGrams = geschätztes Gewicht genau dieser sichtbaren Komponente in Gramm.
        Nährwerte realistisch je 100 g. Wenn kein Essen erkennbar ist, gib [] zurück.
        """
        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": jpegData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": ["temperature": 0.2, "responseMimeType": "application/json"]
        ]
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw VisionError.noKey }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw VisionError.http(status) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let txt = parts.first?["text"] as? String else {
            throw VisionError.empty
        }
        return parseJSONArray(txt)
    }

    /// Zerlegt eine Freitext-Mahlzeit ("2 Eier und ein Toast") per KI in einzelne Lebensmittel (BL11).
    static func recognizeText(_ text: String) async throws -> [GeminiFoodResult] {
        let key = apiKey
        guard !key.isEmpty else { throw VisionError.noKey }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }

        let prompt = """
        Du bist Ernährungsexperte. Zerlege die folgende Mahlzeitsbeschreibung in einzelne Lebensmittel.
        Antworte AUSSCHLIESSLICH mit einem JSON-Array, ohne weiteren Text. Jedes Element:
        {"name":"deutscher Name","portionGrams":Zahl,"kcalPer100g":Zahl,"proteinPer100g":Zahl,"carbsPer100g":Zahl,"fatPer100g":Zahl}
        portionGrams = geschätzte Menge dieses Lebensmittels laut Beschreibung (Gramm bzw. ml).
        Nährwerte realistisch je 100 g. Wenn nichts erkennbar ist, gib [] zurück.
        Beschreibung: "\(clean)"
        """

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.2, "responseMimeType": "application/json"]
        ]
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw VisionError.noKey }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else { throw VisionError.http(status) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let txt = parts.first?["text"] as? String else {
            throw VisionError.empty
        }
        return parseJSONArray(txt)
    }

    /// Parst ein JSON-Array von Lebensmitteln (tolerant, entfernt Codezäune).
    static func parseJSONArray(_ text: String) -> [GeminiFoodResult] {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(of: "```json", with: "")
                 .replacingOccurrences(of: "```", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let d = s.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj in
            func num(_ key: String) -> Double? {
                if let v = obj[key] as? Double { return v }
                if let v = obj[key] as? Int { return Double(v) }
                if let v = obj[key] as? NSNumber { return v.doubleValue }
                if let v = obj[key] as? String { return Double(v.replacingOccurrences(of: ",", with: ".")) }
                return nil
            }
            let name = (obj["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return GeminiFoodResult(name: name, portionGrams: num("portionGrams"), portionLabel: nil,
                                    kcalPer100g: num("kcalPer100g"), proteinPer100g: num("proteinPer100g"),
                                    carbsPer100g: num("carbsPer100g"), fatPer100g: num("fatPer100g"))
        }
    }
}

/// On-device Bilderkennung (Apple Vision, gratis & privat). Liefert die wahrscheinlichsten
/// Bildkategorien eines Fotos – als grober „Was ist das?"-Tipp, der die DB-Suche füttert.
/// Bewusst nur eine Schätzung: keine Markenprodukte, keine Portionsgröße.
enum FoodImageClassifier {

    static func classify(from data: Data,
                         orientation: CGImagePropertyOrientation = .up) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNClassifyImageRequest { req, _ in
                    let observations = (req.results as? [VNClassificationObservation]) ?? []
                    // Nur hinreichend zuverlässige Labels, die besten zuerst.
                    let labels = observations
                        .filter { $0.hasMinimumRecall(0.1, forPrecision: 0.7) }
                        .prefix(5)
                        .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                    cont.resume(returning: Array(labels))
                }
                let handler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: [])
                }
            }
        }
    }
}
