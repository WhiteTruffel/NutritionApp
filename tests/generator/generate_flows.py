#!/usr/bin/env python3
"""Generate Maestro flows for NutritionApp via DeepSeek (OpenRouter).

Reads generator/test_matrix.yaml, sends each case to deepseek/deepseek-chat-v3.1
with the project conventions and the proven reference flow as example, writes
one YAML per case to flows/generated/.

API key: macOS keychain (service "openrouter") or env OPENROUTER_API_KEY.
One-time setup:  security add-generic-password -U -s openrouter -a nutrition-app-testing -w
Run:             python3 generate_flows.py
Stdlib only, no pip installs needed.
"""
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent                       # .../nutrition-app-testing
FLOWS = ROOT / "flows"
OUT = FLOWS / "generated"
REFERENCE = FLOWS / "caffeine_history_regression.yaml"
MATRIX = HERE / "test_matrix.yaml"
MODEL = "deepseek/deepseek-chat-v3.1"
URL = "https://openrouter.ai/api/v1/chat/completions"

IDS = """screen.fluids, fluids.drink.<Name> (Espresso, Doppio, Lungo,
Filterkaffee, Cappuccino, Latte, Flat White, Americano, Cold Brew, Schwarztee,
Gruentee, Mate, Cola, Energydrink, Eistee), fluids.entry.water,
fluids.entry.caffeine, fluids.entry.delete, fluids.caffeineHistory.open,
fluids.caffeine.activeValue, fluids.undo, fluids.water.add200,
fluids.water.add250, fluids.water.add500, fluids.water.addCustom,
dashboard.addKaffee, dashboard.addWasser250, dashboard.addWasser500,
overview.quick.essen, overview.quick.kaffee, overview.quick.wasser,
logWeight, openGoals.
TOTE IDs, NIEMALS verwenden (SwiftUI exponiert sie nicht): tab.heute,
tab.tagebuch, tab.trinken, tab.naehrstoffe, tab.koerper (tabItem-Limitation),
fluids.water.customField (TextField im System-Alert)."""


def api_key() -> str:
    key = os.environ.get("OPENROUTER_API_KEY", "").strip()
    if key:
        return key
    try:
        key = subprocess.run(
            ["security", "find-generic-password", "-s", "openrouter", "-w"],
            capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        key = ""
    if not key:
        sys.exit("No API key. Run once:\n  security add-generic-password -U "
                 "-s openrouter -a nutrition-app-testing -w\n(paste the "
                 "OpenRouter key when prompted) or export OPENROUTER_API_KEY.")
    return key


def parse_matrix(text: str):
    """Minimal YAML-subset parser for our matrix (id + folded goal)."""
    cases, cur = [], None
    for line in text.splitlines():
        if re.match(r"\s*-\s+id:\s*(\S+)", line):
            cur = {"id": re.match(r"\s*-\s+id:\s*(\S+)", line).group(1), "goal": ""}
            cases.append(cur)
        elif cur is not None and re.match(r"\s+goal:", line):
            cur["goal"] = ""
        elif cur is not None and line.strip() and not line.strip().startswith("#"):
            cur["goal"] += line.strip() + " "
    return [c for c in cases if c["goal"].strip()]


SYSTEM = """Du schreibst Maestro-UI-Test-Flows (YAML) fuer die iOS-App
NutritionApp (appId com.tobiaskoch.NutritionApp, UI ist DEUTSCH).

HARTE REGELN (aus schmerzhafter Erfahrung, nicht verhandelbar):
1. NIEMALS clearState verwenden (setzt Health-Berechtigung zurueck, das
   System-Sheet ist fuer Maestro nicht bedienbar). JEDER Flow startet mit
   launchApp + stopApp: true (frischer Prozess, landet IMMER auf Heute-Tab,
   oben, ohne Sheets). Plain launchApp ist VERBOTEN: es resumed nur und
   erbt Tab/Scroll/Navigation des Vorgaengers, was zu Geister-Taps fuehrt
   (IDs inaktiver Tabs stehen mit Frames in der Hierarchie, Maestro tappt
   dann blind auf die Koordinaten des aktiven Screens).
2. Jeder Flow beginnt mit launchApp, waitForAnimationToEnd, dann
   extendedWaitUntil auf "Trinken" (timeout 30000), dann PUNKT-TAP auf das
   benoetigte Tab (siehe Regel 9), waitForAnimationToEnd, dann den Screen
   per SCROLL beweisen, nie per Text-Assert: auf dem Trinken-Screen
   scrollUntilVisible fluids.water.add250 direction UP (assertVisible
   "Getränk hinzufügen" ist VERBOTEN: positions-flaky, Geister-Treffer).
   WICHTIG: launchApp resumed auf dem LETZTEN Tab,
   nie annehmen dass man auf Heute startet. Text-Taps auf Tab-Namen sind
   verboten (treffen unsichtbare Hierarchie-Elemente, No-Op). assertVisible
   auf screen.* IDs beweist NICHT den aktiven Tab (TabView haelt inaktive
   Tabs in der Hierarchie); nur sichtbare Texte beweisen den Screen.
3. Die Tagesliste ("Heute") liegt UNTER dem Fold: vor jedem Zugriff auf
   fluids.entry.* mit scrollUntilVisible (direction DOWN) hinscrollen;
   zurueck nach oben mit scrollUntilVisible direction UP auf das Ziel.
4. JEDER Flow, der Eintraege erzeugt oder auf Eintraege assertet, beginnt
   nach dem Trinken-Prolog mit dem Pre-Clean-Muster (PFLICHT, sonst erben
   Flows die Reste vorher gescheiterter Flows): scrollUntilVisible auf
   fluids.entry.delete (optional: true, timeout 10000), dann repeat
   (times: 8, while visible fluids.entry.delete) mit swipe direction UP
   (duration 300) + waitForAnimationToEnd + tapOn fluids.entry.delete
   index 0 + waitForAnimationToEnd. Danach scrollUntilVisible
   fluids.water.add250 UP (zurueck nach oben). Auch das Aufraeumen am Ende
   ist IMMER dieses repeat-Muster, nie ein einzelner Delete-Tap.
5. Espresso & Co. erzeugen ZWEI Eintraege (Koffein UND Wasser). Loeschen
   heisst also meist mehrfach loeschen.
5b. VOR JEDEM Tap auf fluids.entry.delete IMMER zuerst:
   swipe direction UP (duration 300) + waitForAnimationToEnd.
   Grund: die Papierkorb-Icons liegen am rechten Rand direkt UEBER dem
   Koerper-Tab; die schwebende iOS-26-Tab-Bar stiehlt Taps in der
   Ueberlappungszone und die App springt unbemerkt auf Koerper. Der Swipe
   parkt die Liste in der sicheren Zone. Immer index 0 tappen.
6. Nur diese accessibility IDs existieren: {ids}
7. Deutsche Texte mit Regex-Punkt fuer Umlaute matchen, z.B.
   "Koffein im K.*rper".
9. TABS: Die Tab-IDs sind TOT, Text-Taps treffen falsche Duplikate,
   Prozent-Taps registrieren nicht zuverlaessig. Tabs AUSSCHLIESSLICH per
   ABSOLUTEM Punkt-Tap (Koordinaten aus maestro hierarchy, iPhone 17 Pro):
   Heute = tapOn point "62,822", Tagebuch = "130,822", Trinken = "198,822",
   Naehrstoffe = "269,822", Koerper = "340,822". Nach jedem Tab-Wechsel
   waitForAnimationToEnd. launchApp resumed auf dem LETZTEN Tab, nie einen
   Start-Tab annehmen. Nach Wechsel auf Trinken: scrollUntilVisible
   fluids.water.add250 direction UP (positioniert oben).
10. Freie Wasser-Eingabe: tapOn fluids.water.addCustom oeffnet einen
   System-Alert, dessen Textfeld automatisch fokussiert ist: direkt
   inputText verwenden (KEIN tapOn auf ein Feld), dann tapOn "Hinzufügen"
   (Abbrechen heisst "Abbrechen"). Es gibt KEIN "OK".
11. ZAHLENFORMAT: die App formatiert DEUTSCH mit Tausenderpunkt
   (99999 wird "99.999 ml"). Asserts auf grosse Zahlen immer als Regex,
   z.B. "99.?999 ml".
12. APPLE HEALTH (iOS 26, kalibriert 2026_06_06): es gibt KEINEN
   Browse-Tab (nur Summary, Sharing, Suche). Health restauriert nach
   Neustart den Navigationszustand: nach launchApp com.apple.Health
   (stopApp true) IMMER zweimal tapOn point "69,824" (Summary-Tab,
   poppt zur Root). Erststart-Onboarding davor abfangen: repeat (times 6,
   while notVisible "Summary") mit optionalen Taps auf "Continue", "Next",
   "Not Now", "Done". Pfad zu den Daten: scrollUntilVisible + tapOn
   "Show All Health Data", dann scrollUntilVisible + tapOn "Caffeine"
   (o.a. Datentyp), dann "Show All Data", dann "Edit", dann "Delete All",
   dann optionale Bestaetigung ("Delete All", "Delete"). Health-UI ist
   ENGLISCH (Simulator), App-UI DEUTSCH.
8. Antworte AUSSCHLIESSLICH mit dem YAML-Inhalt. Kein Markdown, keine
   Erklaerung, keine ```-Zaeune. Erste Zeile: ein #-Kommentar mit dem
   Testziel, dann appId, dann ---, dann die Steps.

Hier ein REFERENZ-FLOW, der gruen laeuft, exakt diesen Stil kopieren:

{reference}"""


def main():
    key = api_key()
    reference = REFERENCE.read_text(encoding="utf-8")
    cases = parse_matrix(MATRIX.read_text(encoding="utf-8"))
    only = set(sys.argv[1:])
    if only:
        cases = [c for c in cases if c["id"] in only]
    if not cases:
        sys.exit("No cases matched.")
    OUT.mkdir(parents=True, exist_ok=True)
    system = SYSTEM.format(ids=IDS, reference=reference)
    total_in = total_out = 0
    for c in cases:
        body = json.dumps({
            "model": MODEL,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content":
                    f"Schreibe den Maestro-Flow fuer diesen Testfall "
                    f"(Dateiname {c['id']}.yaml):\n{c['goal'].strip()}"},
            ],
            "temperature": 0.1,
        }).encode()
        req = urllib.request.Request(URL, data=body, headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "X-Title": "nutrition-app-testing flow generator",
        })
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                resp = json.load(r)
        except Exception as e:
            print(f"FAIL  {c['id']}: {e}")
            continue
        text = resp["choices"][0]["message"]["content"].strip()
        text = re.sub(r"^```[a-z]*\n?|\n?```$", "", text).strip()  # safety net
        u = resp.get("usage", {})
        total_in += u.get("prompt_tokens", 0)
        total_out += u.get("completion_tokens", 0)
        target = OUT / f"{c['id']}.yaml"
        if "appId:" not in text.splitlines()[0] and "appId:" not in text:
            (OUT / f"{c['id']}.rejected.txt").write_text(text, encoding="utf-8")
            print(f"REJECT {c['id']}: no appId, saved as .rejected.txt")
            continue
        header = "# GENERATED by DeepSeek via OpenRouter, review before trusting.\n"
        target.write_text(header + text + "\n", encoding="utf-8")
        print(f"OK    {target.name}  ({u.get('completion_tokens', '?')} tokens out)")
    print(f"\nTokens: {total_in} in / {total_out} out "
          f"(DeepSeek v3.1, Groessenordnung Zehntel-Cent insgesamt)")
    print(f"Run them:  maestro test \"{OUT}\"")


if __name__ == "__main__":
    main()
