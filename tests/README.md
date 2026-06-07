# UI-Test-Suite (Maestro)

Automatisierte UI-Tests für die NutritionApp. Stand 06.06.2026: 21 generierte Flows plus 1 handgebauter Regressionsflow, alle grün (Bestätigungslauf 16m31s, iPhone 17 Pro Simulator, iOS 26.5).

## Struktur

- `flows/caffeine_history_regression.yaml`: handgebauter Regressionsflow für den ursprünglichen Koffein-Crash (loggen, Historie öffnen, in der App löschen, Historie erneut: kein Crash).
- `flows/generated/`: 21 generierte Flows in 5 Gruppen: Smoke-Tests aller Tabs, Wasser-Logging inkl. Grenzwerte (0 ml, 99999 ml), Koffein und Getränkevarianten inkl. Stress-Test, Cross-Tab-Konsistenz und Persistenz, Crash-Regression inkl. App-übergreifendem Apple-Health-Delete.
- `probes/probe_health.yaml`: Kalibrier-Flow für die Apple-Health-Navigation (nicht Teil der Suite).
- `generator/generate_flows.py`: erzeugt Flows aus `generator/test_matrix.yaml` per DeepSeek über OpenRouter. Der System-Prompt im Skript enthält alle Plattform-Regeln (Pflichtlektüre vor Flow-Änderungen). API-Key kommt aus der macOS-Keychain (Service `openrouter`) oder `OPENROUTER_API_KEY`; Kosten pro Komplett-Generierung: Größenordnung Zehntel-Cent.

## Voraussetzungen

1. Maestro CLI (getestet mit 2.6.0) und Java 17.
2. Gebooteter iOS-Simulator mit installierter App (`com.tobiaskoch.NutritionApp`).
3. EINMALIG manuell: Health-Berechtigung in der App erteilen. Die Flows verwenden bewusst kein `clearState`, weil das die Berechtigung resettet und das System-Health-Sheet für Maestro nicht bedienbar ist.

## Suite laufen lassen

```
export PATH="$PATH:$HOME/.maestro/bin"
maestro test tests/flows/generated
```

Einzelflow: `maestro test tests/flows/generated/<name>.yaml`. Debug-Artefakte (Screenshots, Kommando-Protokolle) jedes Laufs liegen unter `~/.maestro/tests/<timestamp>/`.

## Flows neu generieren

```
cd tests/generator
python3 generate_flows.py            # alle Fälle
python3 generate_flows.py <case_id>  # einzelne Fälle
```

Generierte Flows sind kalibrierungsbedürftig: nach jeder Generierung gegen die Regel-Liste im System-Prompt prüfen (u.a. kein `clearState`, Tab-Wechsel nur per Punkt-Koordinaten, Pre-Clean-Pflicht, Swipe vor jedem Delete-Tap, deutsche Zahlformat-Regex).

## Wichtigste Plattform-Erkenntnisse (Kurzfassung)

1. Tab-Identifier in SwiftUI-`tabItem` sind tot; Tabs werden per absoluten Punkt-Koordinaten geschaltet (Heute 62,822 / Tagebuch 130,822 / Trinken 198,822 / Nährstoffe 269,822 / Körper 340,822).
2. Inaktive Tabs bleiben als Geister in der Hierarchie: nur echtes Scrollen beweist einen Screen.
3. Die schwebende iOS-26-Tab-Bar stiehlt Taps auf die Lösch-Buttons der Tagesliste: vor jedem Delete-Tap wird gescrollt.
4. Textfelder in System-Alerts exponieren keine IDs: `inputText` direkt ins autofokussierte Feld.
5. Apple Health (iOS 26) hat keinen Browse-Tab und restauriert seinen Navigationszustand über Neustarts; der Health-Flow poppt deshalb erst zur Summary-Root und navigiert über Show All Health Data.
