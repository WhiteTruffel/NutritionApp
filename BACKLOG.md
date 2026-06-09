# NutritionApp – Backlog

Stand: TestFlight Build 1.1 (18). Erledigte Punkte sind abgehakt; offene Punkte
gruppiert nach Thema. Sobald wir zu zweit arbeiten, wandern offene Punkte nach
und nach in GitHub Issues.

## Erledigt (Auswahl)
- [x] BL1 Etikett-Foto liest alle Nährwerte
- [x] BL2 Barcode nicht gefunden → selbst anlegen (+ zentrale DB)
- [x] BL4 Trinken-Reiter: Wasser-Pacing + Koffein-Kinetik
- [x] BL5 Schritte aus Apple Health
- [x] BL6 Drei-Ringe-Übersicht mit Drill-down
- [x] BL8 Mahlzeiten/Rezepte (1-Tap-Logging)
- [x] BL9 Tag/Mahlzeit kopieren
- [x] BL11 Text → KI zerlegt Mahlzeit
- [x] BL12 Multi-Item-Tellerfoto
- [x] BL18 Wochenrückblick
- [x] BL19 Korrelations-Insights (Koffein/Kalorien ↔ Schlaf)
- [x] BL22 Intervallfasten-Timer
- [x] BL31 Getränkevarianten + Wasser-Pacing
- [x] BL32 Heute-Screen lebendiger (Header, Schnellerfassung, Mini-Stats)
- [x] BL33 Eintrag leicht rückgängig machen (Tester-Feedback)
- [x] BL34 Historische „Koffein im Körper"-Ansicht (Tester-Feedback)
- [x] Belastung/Erholung sauber getrennt; Gewicht-Details + Historie

## Offen – Erfassung
- [ ] BL10 Sprach-Logging (Voice)
- [ ] BL13 Rezept-Import aus URL

## Offen – Apple-Integration
- [ ] BL14 Home-/Sperrbildschirm-Widgets
- [ ] BL15 Apple-Watch-App (Schnell-Logging, Komplikationen)
- [ ] BL16 Siri Shortcuts / App Intents
- [ ] BL17 Smarte, adaptive Erinnerungen (inkl. Koffein-Cutoff)

## Offen – Insights & Ernährung
- [ ] BL20 Geglätteter Gewichtstrend + Prognose
- [ ] BL21 Logging-Streak / Konsistenz (nicht wertend)
- [ ] BL23 Mikronährstoffe Richtung Cronometer ausbauen
- [ ] BL24 Coaching-Ton & sinnvolle Defaults

## Offen – Reife & Release
- [ ] BL25 Onboarding-Flow
- [ ] BL26 Unit-Tests (Koffein-Kinetik, Etikett-Parser)
- [ ] BL27 App-Store-Release vorbereiten (Screenshots, Datenschutz, Privacy Policy)
- [ ] BL28 Daten-Export & DSGVO-Löschung

## Offen – Backend / zentrale DB
- [ ] BL7 Laufender Datendienst befüllt zentrale Food-DB (Mac mini / Cloud)
- [ ] BL29 „Nicht gefunden"-Barcodes sammeln & nachpflegen
- [ ] BL30 Crowd-Beiträge in die zentrale DB (mit Review)

## Offen – HRV
- [ ] BL35 17 fehlende Sprachdateien (.lproj) ergänzen, damit die Auswahl wirklich 19 Sprachen abdeckt. Aktuell sind nur EN und DE übersetzt; die übrigen Sprachen fallen zur Laufzeit auf Englisch zurück.
- [ ] BL36 Echte Kamera-PPG-Messung auf einem echten Gerät testen und das Peak-Detection-Tuning gegen reale Aufnahmen prüfen (der Simulator hat keine Kamera).
- [ ] BL37 Frequenzbereich (LF/HF, Total Power) mit echter PSD implementieren. Bisher bewusst nur gated, keine erfundenen Werte.

## Geparkt
- [ ] UI2–UI4 XCUITest-Bundle + UI-Tests
