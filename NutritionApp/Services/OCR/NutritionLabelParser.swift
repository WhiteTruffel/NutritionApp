import Foundation
import CoreGraphics

/// Aus einer erkannten Nährwerttabelle extrahierte Werte (pro 100 g).
struct ParsedLabel: Sendable {
    var kcalPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var saltPer100g: Double?

    /// Natrium aus Salz (Salz ≈ Natrium × 2,5).
    var sodiumMgPer100g: Double? { saltPer100g.map { ($0 / 2.5) * 1000 } }

    var hasAny: Bool {
        kcalPer100g != nil || proteinPer100g != nil || carbsPer100g != nil || fatPer100g != nil
    }
}

/// Heuristischer Parser für deutsche (und einfache englische) Nährwertangaben.
/// Bewusst defensiv: Treffer sind Vorschläge, der Nutzer prüft/korrigiert in der Maske.
enum NutritionLabelParser {

    static func parse(_ lines: [String]) -> ParsedLabel {
        var label = ParsedLabel()

        for raw in lines {
            let line = raw.lowercased()

            // Energie: Zahl bei "kcal" (egal ob davor oder dahinter).
            if label.kcalPer100g == nil, line.contains("kcal"), let v = kcalValue(in: line) {
                label.kcalPer100g = v
            }

            // Jede Zeile kann MEHRERE Felder belegen (z. B. „Kohlenhydrate 60 g davon Zucker 1,1 g").
            // Daher unabhängige Prüfungen + Zahl JEWEILS direkt nach dem Schlüsselwort, nicht die
            // Zeilen-erste Zahl. So wird Zucker nicht fälschlich mit dem Kohlenhydrat-Wert belegt.
            if label.sugarPer100g == nil, line.contains("zucker") || line.contains("sugar") {
                label.sugarPer100g = number(after: ["zucker", "sugar"], in: line)
            }
            if label.fiberPer100g == nil, line.contains("ballaststoff") || line.contains("fibre") || line.contains("fiber") {
                label.fiberPer100g = number(after: ["ballaststoff", "fibre", "fiber"], in: line)
            }
            if label.proteinPer100g == nil, line.contains("eiwei") || line.contains("protein") {
                label.proteinPer100g = number(after: ["eiwei", "protein"], in: line)
            }
            if label.saltPer100g == nil, line.contains("salz") || line.contains("salt") {
                label.saltPer100g = number(after: ["salz", "salt"], in: line)
            }
            if label.carbsPer100g == nil, line.contains("kohlenhydrat") || line.contains("carbohydrate") {
                label.carbsPer100g = number(after: ["kohlenhydrat", "carbohydrate"], in: line)
            }
            // Gesamtfett: „gesättigte/saturated/Fettsäuren"-Zeilen ausschließen.
            if label.fatPer100g == nil, line.contains("fett") || line.contains("fat"),
               !line.contains("gesätt"), !line.contains("saturated"), !line.contains("fettsäure") {
                label.fatPer100g = number(after: ["fett", "fat"], in: line)
            }
        }
        return label
    }

    /// Räumliche Variante: nutzt die Position jedes Textstücks. Findet zu einem Nährwert-Namen
    /// die Zahl, die rechts daneben auf gleicher Höhe steht – auch bei zweispaltigen Etiketten.
    static func parse(_ tokens: [TextToken]) -> ParsedLabel {
        var label = ParsedLabel()

        for t in tokens where t.text.lowercased().contains("kcal") {
            if let v = kcalValue(in: t.text.lowercased()) { label.kcalPer100g = v; break }
        }

        func value(_ keywords: [String], exclude: [String] = []) -> Double? {
            for t in tokens {
                let low = t.text.lowercased()
                guard keywords.contains(where: { low.contains($0) }) else { continue }
                if exclude.contains(where: { low.contains($0) }) { continue }
                // 1) Zahl direkt nach dem Schlüsselwort auf demselben Stück (einspaltig)?
                if let v = number(after: keywords, in: low) { return v }
                // 2) sonst nächstgelegene Zahl rechts daneben auf gleicher Höhe (zweispaltig).
                let yTol = max(0.02, t.rect.height * 0.8)
                var best: (x: CGFloat, v: Double)?
                for n in tokens {
                    guard n.rect != t.rect else { continue }
                    guard abs(n.rect.midY - t.rect.midY) < yTol else { continue }
                    guard n.rect.minX >= t.rect.maxX - 0.02 else { continue }
                    guard let v = numbers(in: n.text).first else { continue }
                    if best == nil || n.rect.minX < best!.x { best = (n.rect.minX, v) }
                }
                if let b = best { return b.v }
            }
            return nil
        }

        label.proteinPer100g = value(["eiwei", "protein"])
        label.carbsPer100g   = value(["kohlenhydrat", "carbohydrate"])
        label.sugarPer100g   = value(["zucker", "sugar"])
        label.fatPer100g     = value(["fett", "fat"], exclude: ["gesätt", "saturated", "fettsäure"])
        label.fiberPer100g   = value(["ballaststoff", "fibre", "fiber"])
        label.saltPer100g    = value(["salz", "salt"])
        return label
    }

    /// Erste Zahl, die NACH einem der Schlüsselwörter in der Zeile steht.
    private static func number(after keywords: [String], in line: String) -> Double? {
        for kw in keywords {
            if let r = line.range(of: kw) {
                if let v = numbers(in: String(line[r.upperBound...])).first { return v }
            }
        }
        return nil
    }

    // MARK: Hilfen

    /// Alle Zahlen einer Zeile (deutsches Komma wird zu Punkt).
    private static func numbers(in s: String) -> [Double] {
        var result: [Double] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                if let d = Double(current.replacingOccurrences(of: ",", with: ".")) { result.append(d) }
                current = ""
            }
        }
        for ch in s {
            if ch.isNumber || ch == "," || ch == "." { current.append(ch) }
            else { flush() }
        }
        flush()
        return result
    }

    /// kcal-Wert: bevorzugt die letzte Zahl VOR „kcal" (z. B. „1560 kJ / 370 kcal" → 370),
    /// sonst die erste Zahl danach (z. B. „kcal 370").
    private static func kcalValue(in line: String) -> Double? {
        guard let range = line.range(of: "kcal") else { return nil }
        if let before = numbers(in: String(line[line.startIndex..<range.lowerBound])).last { return before }
        return numbers(in: String(line[range.upperBound...])).first
    }
}
