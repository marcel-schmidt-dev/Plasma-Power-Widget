#!/bin/sh
# Liest Leistung und Temperatur von CPU (AMD/Intel) und GPU (AMD/NVIDIA).
# Aufruf: read.sh [ROOT]   (ROOT nur für Tests, sonst leer = echtes /sys)
# NVIDIA_SMI=<pfad> ersetzt nvidia-smi (Tests); mit ROOT ohne NVIDIA_SMI kein Aufruf.
# Ausgabe: key=value-Zeilen; fehlende Werte bleiben leer. Exit-Code immer 0.

ROOT=${1:-}
HWMON="$ROOT/sys/class/hwmon"
RAPL="$ROOT/sys/class/powercap/intel-rapl:0"

# Erste Zeile einer Datei, leer wenn nicht vorhanden oder nicht lesbar.
val() {
  [ -r "$1" ] || return 0
  read -r v < "$1" 2>/dev/null && printf '%s' "$v"
}

cpu_energy=""
if [ -e "$RAPL/energy_uj" ]; then
  if [ -r "$RAPL/energy_uj" ]; then cpu_energy=$(val "$RAPL/energy_uj"); else cpu_energy=noperm; fi
fi
cpu_energy_max=$(val "$RAPL/max_energy_range_uj")

cpu_temp=""
gpu_dir=""
gpu_vram=-1
for h in "$HWMON"/hwmon*; do
  [ -d "$h" ] || continue
  case $(val "$h/name") in
    k10temp|zenpower|coretemp)
      [ -z "$cpu_temp" ] && cpu_temp=$(val "$h/temp1_input")
      ;;
    amdgpu)
      vram=$(val "$h/device/mem_info_vram_total")
      vram=${vram:-0}
      if [ "$vram" -gt "$gpu_vram" ] 2>/dev/null; then gpu_vram=$vram; gpu_dir=$h; fi
      ;;
  esac
done

gpu_power=""
gpu_temp=""
if [ -n "$gpu_dir" ]; then
  gpu_power=$(val "$gpu_dir/power1_average")
  [ -z "$gpu_power" ] && gpu_power=$(val "$gpu_dir/power1_input")
  gpu_temp=$(val "$gpu_dir/temp1_input")
fi

# NVIDIA (proprietärer Treiber, kein hwmon): hat Vorrang vor amdgpu.
smi=${NVIDIA_SMI:-}
if [ -z "$smi" ] && [ -z "$ROOT" ] && command -v nvidia-smi >/dev/null 2>&1; then smi=nvidia-smi; fi
if [ -n "$smi" ]; then
  # timeout: ein hängender Treiber darf die CPU-Werte nicht blockieren
  nv=$(timeout 2 "$smi" --query-gpu=power.draw,temperature.gpu --format=csv,noheader,nounits 2>/dev/null |
    awk -F, 'NR == 1 {
      for (i = 1; i <= 2; i++) { gsub(/^[ \t]+|[ \t\r]+$/, "", $i); ok[i] = ($i ~ /^[0-9]+(\.[0-9]+)?$/) }
      p = ok[1] ? sprintf("%d", $1 * 1e6 + 0.5) : ""
      t = ok[2] ? sprintf("%d", $2 * 1000 + 0.5) : ""
      if (ok[1] || ok[2]) print p "," t
    }')
  if [ -n "$nv" ]; then
    gpu_power=${nv%,*}
    gpu_temp=${nv#*,}
  fi
fi

printf 'ts_ns=%s\n' "$(date +%s%N)"
printf 'cpu_energy_uj=%s\n' "$cpu_energy"
printf 'cpu_energy_max_uj=%s\n' "$cpu_energy_max"
printf 'cpu_temp_mc=%s\n' "$cpu_temp"
printf 'gpu_power_uw=%s\n' "$gpu_power"
printf 'gpu_temp_mc=%s\n' "$gpu_temp"
exit 0
