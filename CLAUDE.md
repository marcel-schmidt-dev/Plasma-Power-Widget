# Plasma-Power-Widget

Plasma-6-Plasmoid (reines QML): Watt und Temperatur von CPU/GPU (AMD, Intel, NVIDIA) im Panel, Klick öffnet Verlaufsgraphen.

- **Zielsystem ist nicht der Entwicklungsrechner.** Dort: Plasma 6.8, AMD Ryzen + Radeon (zweiter Plasma-PC: Intel + NVIDIA). Hier: Omarchy/Hyprland, Intel + NVIDIA, kein Plasma. Echte Werte und das Aussehen prüft der Nutzer am Zielsystem.
- Spec und Plan im Vault: `~/Notes/CoffinNotes/Projekte/Plasma-Power-Widget/Pläne/`.

## Aufbau
- `package/contents/code/read.sh` – liest sysfs (RAPL, hwmon `k10temp`/`zenpower`/`coretemp`, `amdgpu`), Sensoren nur über hwmon-`name`; NVIDIA über `nvidia-smi` (Vorrang vor amdgpu). Optionaler ROOT-Parameter für Tests, `NVIDIA_SMI` ersetzt `nvidia-smi` (mit ROOT ohne `NVIDIA_SMI` kein Aufruf).
- `package/contents/code/logic.js` – reine Funktionen, von QML und Node geladen. Kein `.pragma library` (Node kann das nicht parsen). Emojis zentral in `EMOJI`.
- `package/contents/ui/main.qml` – startet `read.sh` per `Plasma5Support.DataSource` (Engine `executable`).
- `install-permissions.sh` – tmpfiles-Regel, macht `energy_uj` lesbar.

## Befehle
| Zweck | Befehl |
|---|---|
| Logik-Tests | `npm test` |
| Skript-Tests | `bash tests/read_test.sh && bash tests/permissions_test.sh` |
| shellcheck | `mise x shellcheck@latest -- shellcheck *.sh tests/*.sh package/contents/code/read.sh` |
| QML-Syntax | `/usr/lib/qt6/bin/qmllint package/contents/ui/*.qml` (Import-Warnungen zu `org.kde.*` sind hier normal) |
