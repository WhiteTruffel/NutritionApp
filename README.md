# NutritionApp

Ein iOS-Ernährungs- und Gesundheits-Tracker (SwiftUI · SwiftData · HealthKit · Vision · Gemini),
im Stil von MyFitnessPal / Cronometer / MacroFactor, mit Whoop-/Bevel-Elementen.

## Features
- **Erfassung:** Suche (Open Food Facts, USDA, zentrale CloudKit-DB), Barcode-Scan,
  Etikett-OCR (Vision), Gericht-Foto inkl. Multi-Erkennung (Gemini), Text→KI,
  gespeicherte Mahlzeiten/Rezepte, Schnelleintrag.
- **Heute:** Drei-Ringe-Übersicht (Ernährung · Belastung · Erholung) mit Drill-down,
  Schnellerfassung und Mini-Statistiken.
- **Trinken:** Wasser-Pacing (Ziel nach Gewicht) + Koffein-Pharmakokinetik (Abbaukurve,
  „im-Körper"-Historie, Undo).
- **Körper:** Erholung (Schlaf, HRV/Ruhepuls, Achtsamkeit) getrennt von Belastung
  (Training, Bewegung, Schritte); Gewicht inkl. Körperzusammensetzung + Verlauf.
- **Weiteres:** Mikronährstoffe (RDA), adaptiver Stoffwechsel, Intervallfasten,
  Wochenrückblick + Korrelations-Insights, Apple-Health-Sync.

## Setup
1. Xcode 16+ / iOS 18+ (entwickelt gegen iOS 26 SDK).
2. `NutritionApp.xcodeproj` öffnen, eigenes Signing-Team wählen.
3. Optional in den App-Einstellungen eigene API-Keys (USDA, Google Gemini) hinterlegen –
   diese werden nur lokal (UserDefaults) gespeichert, nichts davon liegt im Repo.

## Architektur
- `App/` – Einstieg, ModelContainer, Theme, Root-Tabs
- `Features/` – Views je Bereich (AddFood, Dashboard, Overview, Fluids, Recovery, …)
- `Models/` – SwiftData-Modelle + Domänenlogik (Kalorienrechner, Koffein-Kinetik, …)
- `Services/` – HealthKit, OCR, Food-Datenquellen (OFF/USDA/CloudKit)

## Mitwirken
Feature-Branches + Pull Requests gegen `main`. Keine Secrets committen
(`.gitignore` schließt `*.pem`, `*.p8`, Keys und Xcode-User-Daten aus).
