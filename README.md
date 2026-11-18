# Plasma-Power-Widget

KDE-Plasma-6-Widget, das Leistung und Temperatur von **AMD-CPU (Ryzen)** und **AMD-GPU (Radeon)** anzeigt.

```
Panel:  🖥️ ⚡45 W 🌡️62° │ 🎮 ⚡120 W 🌡️70°
```

Ein Klick öffnet ein Popup mit Verlaufsgraphen (Watt und °C) für die letzten Minuten und dem Spitzenwert.

| Emoji | Bedeutung |
|---|---|
| 🖥️ | CPU |
| 🎮 | GPU |
| ⚡ | Leistung (Watt) |
| 🌡️ | Temperatur |

`–` heißt: Wert nicht verfügbar (Sensor fehlt oder kein Leserecht).

## Voraussetzungen

- KDE Plasma 6 (getestet für 6.8)
- AMD Ryzen und Radeon (Treiber `amdgpu`, Sensor `k10temp` oder `zenpower`)
- Eine Emoji-Schrift für farbige Emojis, z. B. **Noto Color Emoji** (Arch: `noto-fonts-emoji`)

## Installation

```bash
git clone https://github.com/marcel-schmidt-dev/Plasma-Power-Widget.git
cd Plasma-Power-Widget
kpackagetool6 -t Plasma/Applet -i package
sudo ./install-permissions.sh
```

Danach Rechtsklick aufs Panel, „Widgets hinzufügen…“ und „Power Widget“ auf das Panel ziehen.

**Update:** `git pull && kpackagetool6 -t Plasma/Applet -u package`, danach Plasma neu starten (`systemctl --user restart plasma-plasmashell`) oder ab- und wieder anmelden.

**Deinstallation:**

```bash
kpackagetool6 -t Plasma/Applet -r de.marcelschmidt.plasmapowerwidget
sudo ./uninstall-permissions.sh
```

## Einstellungen

Rechtsklick aufs Widget → „Power Widget einrichten…“: Aktualisierung (1–10 s, Standard 1 s), Verlaufsdauer (1–10 Min., Standard 2 Min.) und Schriftgröße im Panel (100–200 %, Standard 100 %). In einem waagerechten Panel wird die Schrift auf die Panelhöhe begrenzt, damit nichts abgeschnitten wird.

## Warum `sudo ./install-permissions.sh`?

Die CPU-Leistung kommt aus dem RAPL-Energiezähler (`/sys/class/powercap/intel-rapl:0/energy_uj`, heißt auch auf AMD so). Den darf seit 2020 nur root lesen. Das Skript legt die Regel `/etc/tmpfiles.d/plasma-power-widget.conf` an, die den Zähler bei jedem Start für alle lesbar macht.

**Risiko:** Der Kernel hat den Zugriff wegen der Seitenkanal-Lücke [PLATYPUS (CVE-2020-8694)](https://platypusattack.com/) gesperrt. Ein Programm, das bereits auf dem Rechner läuft, könnte aus sehr feinen Messungen des Energieverbrauchs Rückschlüsse auf geheime Daten anderer Programme ziehen. Für einen privaten Desktop ist das in der Regel vertretbar, auf Mehrbenutzer-Systemen oder Servern nicht. Ohne das Skript funktioniert alles außer den CPU-Watt.

## Entwicklung

```
package/                 Plasmoid (wird installiert)
  metadata.json
  contents/code/read.sh  liest sysfs, gibt key=value aus
  contents/code/logic.js Parsen, Rechnen, Formatieren (reine Funktionen)
  contents/ui/           main.qml, Graph.qml, configGeneral.qml
tests/                   Node- und Shell-Tests
```

Tests:

```bash
npm test                      # logic.js
bash tests/read_test.sh       # read.sh gegen nachgebaute /sys-Bäume
bash tests/permissions_test.sh
shellcheck *.sh tests/*.sh package/contents/code/read.sh
```

Ausprobieren ohne Panel: `plasmoidviewer -a package` (Paket `plasma-sdk`).
