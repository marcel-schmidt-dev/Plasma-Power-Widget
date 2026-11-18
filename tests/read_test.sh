#!/usr/bin/env bash
# Testet package/contents/code/read.sh gegen nachgebaute /sys-Bäume.
set -u
cd "$(dirname "$0")/.." || exit 1
SCRIPT=package/contents/code/read.sh
FAILS=0
TMP=$(mktemp -d)
trap 'chmod -R u+rwx "$TMP"; rm -rf "$TMP"' EXIT

# put <root> <relpath> <value>
put() { mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "$3" > "$1/$2"; }

rapl() { put "$1" sys/class/powercap/intel-rapl:0/energy_uj "$2"
         put "$1" sys/class/powercap/intel-rapl:0/max_energy_range_uj 65532610987; }

# expect <case> <root> <exact line>...
expect() {
  local name=$1 root=$2; shift 2
  local out; out=$(sh "$SCRIPT" "$root"); local rc=$?
  if [ $rc -ne 0 ]; then echo "FAIL [$name] exit $rc"; FAILS=$((FAILS+1)); fi
  for line in "$@"; do
    if ! grep -qxE -- "$line" <<<"$out"; then
      echo "FAIL [$name] erwartet: $line"; printf "    %s\n" "$out"
      FAILS=$((FAILS+1))
    fi
  done
}

# ryzen + dgpu
R=$TMP/ryzen; rapl "$R" 5000000
put "$R" sys/class/hwmon/hwmon0/name k10temp
put "$R" sys/class/hwmon/hwmon0/temp1_input 62125
put "$R" sys/class/hwmon/hwmon3/name amdgpu
put "$R" sys/class/hwmon/hwmon3/power1_average 120000000
put "$R" sys/class/hwmon/hwmon3/temp1_input 70000
put "$R" sys/class/hwmon/hwmon3/device/mem_info_vram_total 17163091968
expect ryzen+dgpu "$R" 'ts_ns=[0-9]+' 'cpu_energy_uj=5000000' 'cpu_energy_max_uj=65532610987' \
  'cpu_temp_mc=62125' 'gpu_power_uw=120000000' 'gpu_temp_mc=70000'

# igpu ohne VRAM-Datei + dgpu
G=$TMP/igpu; rapl "$G" 1
put "$G" sys/class/hwmon/hwmon1/name amdgpu
put "$G" sys/class/hwmon/hwmon1/power1_average 15000000
put "$G" sys/class/hwmon/hwmon2/name amdgpu
put "$G" sys/class/hwmon/hwmon2/power1_average 200000000
put "$G" sys/class/hwmon/hwmon2/device/mem_info_vram_total 8573157376
expect igpu+dgpu "$G" 'gpu_power_uw=200000000'

# dgpu vor igpu in der Reihenfolge
D=$TMP/order; rapl "$D" 1
put "$D" sys/class/hwmon/hwmon1/name amdgpu
put "$D" sys/class/hwmon/hwmon1/power1_average 200000000
put "$D" sys/class/hwmon/hwmon1/device/mem_info_vram_total 8573157376
put "$D" sys/class/hwmon/hwmon2/name amdgpu
put "$D" sys/class/hwmon/hwmon2/power1_average 15000000
put "$D" sys/class/hwmon/hwmon2/device/mem_info_vram_total 536870912
expect dgpu-zuerst "$D" 'gpu_power_uw=200000000'

# power1_input statt power1_average
P=$TMP/pinput; rapl "$P" 1
put "$P" sys/class/hwmon/hwmon4/name amdgpu
put "$P" sys/class/hwmon/hwmon4/power1_input 95000000
expect power1_input "$P" 'gpu_power_uw=95000000'

# kein Leserecht auf RAPL
if [ "$(id -u)" -ne 0 ]; then
  N=$TMP/noperm; rapl "$N" 5000000
  chmod 000 "$N/sys/class/powercap/intel-rapl:0/energy_uj"
  expect noperm "$N" 'cpu_energy_uj=noperm'
else
  echo "SKIP [noperm] läuft als root"
fi

# keine Sensoren
E=$TMP/empty; mkdir -p "$E/sys"
expect leer "$E" 'cpu_energy_uj=' 'cpu_energy_max_uj=' 'cpu_temp_mc=' 'gpu_power_uw=' 'gpu_temp_mc='

if [ $FAILS -eq 0 ]; then echo OK; else echo "$FAILS Fehler"; exit 1; fi
