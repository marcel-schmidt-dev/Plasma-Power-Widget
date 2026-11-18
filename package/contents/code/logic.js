// Reine Funktionen für das Widget. Wird von QML (import "../code/logic.js")
// und von Node (tests/logic.test.js) geladen, darum kein ".pragma library".

var EMOJI = { cpu: "🖥️", gpu: "🎮", power: "⚡", temp: "🌡️" };

var DASH = "–";
var MAX_DT_NS = 10e9;   // längere Abstände (z. B. nach Suspend) ergeben keinen Wert
var MAX_WATTS = 1000;   // alles darüber ist ein Zähler-Reset, kein Messwert

var KEYS = {
  ts_ns: "tsNs",
  cpu_energy_uj: "cpuEnergyUj",
  cpu_energy_max_uj: "cpuEnergyMaxUj",
  cpu_temp_mc: "cpuTempMc",
  gpu_power_uw: "gpuPowerUw",
  gpu_temp_mc: "gpuTempMc",
};

function parseReading(text) {
  var r = { tsNs: null, cpuEnergyUj: null, cpuEnergyMaxUj: null, cpuTempMc: null,
            gpuPowerUw: null, gpuTempMc: null, cpuNoPerm: false };
  String(text || "").split("\n").forEach(function (line) {
    var i = line.indexOf("=");
    if (i < 0) return;
    var key = line.slice(0, i).trim();
    var value = line.slice(i + 1).trim();
    if (!(key in KEYS)) return;
    if (key === "cpu_energy_uj" && value === "noperm") {
      r.cpuNoPerm = true;
      return;
    }
    r[KEYS[key]] = /^\d+$/.test(value) ? Number(value) : null;
  });
  return r;
}

function cpuWatts(prev, cur) {
  if (!prev || !cur) return null;
  if (prev.cpuEnergyUj === null || cur.cpuEnergyUj === null) return null;
  if (prev.tsNs === null || cur.tsNs === null) return null;
  var dt = cur.tsNs - prev.tsNs;
  if (dt <= 0 || dt > MAX_DT_NS) return null;
  var delta = cur.cpuEnergyUj - prev.cpuEnergyUj;
  if (delta < 0) {
    if (cur.cpuEnergyMaxUj === null) return null;
    delta += cur.cpuEnergyMaxUj;
  }
  var watts = (delta / 1e6) / (dt / 1e9);
  return watts > MAX_WATTS ? null : watts;
}

function toWatts(uw) { return uw === null || uw === undefined ? null : uw / 1e6; }
function toCelsius(mc) { return mc === null || mc === undefined ? null : mc / 1000; }

function pushSample(arr, value, maxLen) {
  var out = arr.concat([value]);
  return out.length > maxLen ? out.slice(out.length - maxLen) : out;
}

function peak(arr) {
  var best = null;
  arr.forEach(function (v) {
    if (v !== null && v !== undefined && (best === null || v > best)) best = v;
  });
  return best;
}

function isNum(v) { return typeof v === "number" && isFinite(v); }
function formatWatts(v) { return isNum(v) ? Math.round(v) + " W" : DASH; }
function formatTemp(v) { return isNum(v) ? Math.round(v) + "°" : DASH; }
function formatTempLong(v) { return isNum(v) ? Math.round(v) + " °C" : DASH; }

function panelLines(s) {
  return [
    EMOJI.cpu + " " + EMOJI.power + formatWatts(s.cpuW) + " " + EMOJI.temp + formatTemp(s.cpuC),
    EMOJI.gpu + " " + EMOJI.power + formatWatts(s.gpuW) + " " + EMOJI.temp + formatTemp(s.gpuC),
  ];
}

function panelText(s) { return panelLines(s).join(" │ "); }

if (typeof module !== "undefined") {
  module.exports = { EMOJI: EMOJI, parseReading: parseReading, cpuWatts: cpuWatts,
                     toWatts: toWatts, toCelsius: toCelsius, pushSample: pushSample,
                     peak: peak, formatWatts: formatWatts, formatTemp: formatTemp, formatTempLong: formatTempLong,
                     panelText: panelText, panelLines: panelLines };
}
