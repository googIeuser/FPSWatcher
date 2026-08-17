use regex::Regex;
use serde::Serialize;
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::OnceLock;

static SF_AVERAGE_REGEX: OnceLock<Regex> = OnceLock::new();
static SF_TOTAL_REGEX: OnceLock<Regex> = OnceLock::new();
static SF_LAYER_REGEX: OnceLock<Regex> = OnceLock::new();
static SF_HISTOGRAM_REGEX: OnceLock<Regex> = OnceLock::new();
static GPU_KV_REGEX: OnceLock<Regex> = OnceLock::new();
static GPU_NUMBER_REGEX: OnceLock<Regex> = OnceLock::new();

#[inline]
fn sf_average_regex() -> &'static Regex {
    SF_AVERAGE_REGEX.get_or_init(|| {
        Regex::new(r"(?i)averageFPS\s*[=:]\s*([0-9]+(?:\.[0-9]+)?)").unwrap()
    })
}

#[inline]
fn sf_total_regex() -> &'static Regex {
    SF_TOTAL_REGEX.get_or_init(|| Regex::new(r"(?i)totalFrames\s*[=:]\s*([0-9]+)").unwrap())
}

#[inline]
fn sf_layer_regex() -> &'static Regex {
    SF_LAYER_REGEX.get_or_init(|| Regex::new(r"(?i)layerName\s*=\s*(.+)").unwrap())
}

#[inline]
fn sf_histogram_regex() -> &'static Regex {
    SF_HISTOGRAM_REGEX.get_or_init(|| Regex::new(r"([0-9]+)ms=([0-9]+)").unwrap())
}

#[inline]
fn gpu_kv_regex() -> &'static Regex {
    GPU_KV_REGEX.get_or_init(|| {
        Regex::new(r"(?m)^\s*([A-Za-z0-9_.-]+)\s*=\s*(.*?)\s*$").unwrap()
    })
}

#[inline]
fn gpu_number_regex() -> &'static Regex {
    GPU_NUMBER_REGEX.get_or_init(|| Regex::new(r"-?[0-9]+(?:\.[0-9]+)?").unwrap())
}

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct FpsStats {
    source: Option<String>,
    average_fps: Option<f64>,
    five_percent_low_fps: Option<f64>,
    one_percent_low_fps: Option<f64>,
    point_one_percent_low_fps: Option<f64>,
    median_fps: Option<f64>,
    minimum_instant_fps: Option<f64>,
    maximum_instant_fps: Option<f64>,
    frame_time_ms: Option<f64>,
    frame_time_p95_ms: Option<f64>,
    frame_time_p99_ms: Option<f64>,
    best_frame_time_ms: Option<f64>,
    worst_frame_time_ms: Option<f64>,
    frame_stability_score: Option<f64>,
    frame_pacing_score: Option<f64>,
    stutter25ms_count: Option<u64>,
    stutter50ms_count: Option<u64>,
    stutter100ms_count: Option<u64>,
    micro_stutter_count: Option<u64>,
    slow_frame_count: Option<u64>,
    frozen_frame_count: Option<u64>,
    total_frames: Option<u64>,
    matched_layer: Option<String>,
}

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct GpuStats {
    model: Option<String>,
    frequency_mhz: Option<f64>,
    min_frequency_mhz: Option<f64>,
    max_frequency_mhz: Option<f64>,
    governor: Option<String>,
    load_percent: Option<f64>,
}

fn c_string(input: *const c_char) -> String {
    if input.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(input) }
        .to_string_lossy()
        .into_owned()
}

fn into_raw_string(value: String) -> *mut c_char {
    CString::new(value.replace('\0', ""))
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

#[no_mangle]
pub extern "C" fn gw_free_string(pointer: *mut c_char) {
    if pointer.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(pointer));
    }
}

#[no_mangle]
pub extern "C" fn gw_parse_surfaceflinger(
    raw_pointer: *const c_char,
    package_pointer: *const c_char,
) -> *mut c_char {
    let raw = c_string(raw_pointer);
    let package_name = c_string(package_pointer);
    let stats = parse_frame_stats(&raw, &package_name);
    into_raw_string(serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string()))
}

#[no_mangle]
pub extern "C" fn gw_parse_gpu(
    raw_pointer: *const c_char,
    fallback_model_pointer: *const c_char,
) -> *mut c_char {
    let raw = c_string(raw_pointer);
    let fallback_model = c_string(fallback_model_pointer);
    let stats = parse_gpu(&raw, &fallback_model);
    into_raw_string(serde_json::to_string(&stats).unwrap_or_else(|_| "{}".to_string()))
}

#[no_mangle]
pub extern "C" fn gw_session_csv(json_pointer: *const c_char) -> *mut c_char {
    let input = c_string(json_pointer);
    let result = session_csv(&input).unwrap_or_default();
    into_raw_string(result)
}

fn parse_frame_stats(raw: &str, package_name: &str) -> FpsStats {
    let source = if raw.contains("__FPSWATCHER_SOURCE=gfxinfo") {
        "gfxinfo"
    } else {
        "surfaceflinger"
    };

    let mut result = if source == "gfxinfo" {
        parse_gfxinfo(raw)
    } else {
        parse_surfaceflinger(raw, package_name)
    };
    result.source = Some(source.to_string());
    result
}

fn parse_surfaceflinger(raw: &str, package_name: &str) -> FpsStats {
    let average_regex = sf_average_regex();
    let total_regex = sf_total_regex();
    let layer_regex = sf_layer_regex();
    let histogram_regex = sf_histogram_regex();

    let mut sections: Vec<&str> = raw.split("layerName =").collect();
    if sections.len() <= 1 {
        sections = vec![raw];
    }

    let mut best_section = raw;
    let mut best_score = i32::MIN;
    for section in sections {
        let mut score = 0;
        if !package_name.is_empty() && section.contains(package_name) {
            score += 100;
        }
        if average_regex.is_match(section) {
            score += 20;
        }
        if total_regex.is_match(section) {
            score += 10;
        }
        score += section.matches("ms=").count().min(20) as i32;
        if score > best_score {
            best_score = score;
            best_section = section;
        }
    }

    let average_fps = average_regex
        .captures(best_section)
        .and_then(|capture| capture.get(1))
        .and_then(|value| value.as_str().parse::<f64>().ok())
        .filter(|value| value.is_finite() && *value >= 0.0 && *value < 1000.0);

    let total_frames = total_regex
        .captures(best_section)
        .and_then(|capture| capture.get(1))
        .and_then(|value| value.as_str().parse::<u64>().ok());

    let matched_layer = layer_regex
        .captures(best_section)
        .and_then(|capture| capture.get(1))
        .map(|value| value.as_str().trim().to_string())
        .or_else(|| {
            if best_section != raw {
                best_section.lines().next().map(|line| line.trim().to_string())
            } else {
                None
            }
        });

    let mut histogram: Vec<(f64, u64)> = histogram_regex
        .captures_iter(best_section)
        .filter_map(|capture| {
            let ms = capture.get(1)?.as_str().parse::<f64>().ok()?;
            let count = capture.get(2)?.as_str().parse::<u64>().ok()?;
            (ms > 0.0 && ms < 5_000.0 && count > 0).then_some((ms, count))
        })
        .collect();
    histogram.sort_by(|a, b| a.0.total_cmp(&b.0));

    let histogram_total: u64 = histogram.iter().map(|entry| entry.1).sum();
    let mean_frame_time = weighted_mean_ms(&histogram);

    let p50 = percentile_ms(&histogram, histogram_total, 0.50);
    let p99 = percentile_ms(&histogram, histogram_total, 0.99);
    let best = histogram.first().map(|entry| entry.0);
    let worst = histogram.last().map(|entry| entry.0);
    FpsStats {
        source: None,
        average_fps: average_fps.or_else(|| mean_frame_time.map(|ms| 1000.0 / ms)),
        five_percent_low_fps: (histogram_total >= 20)
            .then(|| tail_low_fps(&histogram, histogram_total, 0.05))
            .flatten(),
        one_percent_low_fps: (histogram_total >= 100)
            .then(|| tail_low_fps(&histogram, histogram_total, 0.01))
            .flatten(),
        point_one_percent_low_fps: (histogram_total >= 1_000)
            .then(|| tail_low_fps(&histogram, histogram_total, 0.001))
            .flatten(),
        median_fps: p50.filter(|ms| *ms > 0.0).map(|ms| 1000.0 / ms),
        minimum_instant_fps: worst.filter(|ms| *ms > 0.0).map(|ms| 1000.0 / ms),
        maximum_instant_fps: best.filter(|ms| *ms > 0.0).map(|ms| (1000.0 / ms).min(1000.0)),
        frame_time_ms: mean_frame_time
            .or_else(|| average_fps.filter(|fps| *fps > 0.0).map(|fps| 1000.0 / fps)),
        frame_time_p95_ms: percentile_ms(&histogram, histogram_total, 0.95),
        frame_time_p99_ms: p99,
        best_frame_time_ms: best,
        worst_frame_time_ms: worst,
        frame_stability_score: mean_frame_time
            .zip(p99)
            .map(|(mean, tail)| (mean / tail * 100.0).clamp(0.0, 100.0)),
        frame_pacing_score: frame_pacing_score(&histogram, mean_frame_time),
        stutter25ms_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 25.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        stutter50ms_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 50.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        stutter100ms_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 100.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        micro_stutter_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 20.0 && *ms < 50.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        slow_frame_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 25.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        frozen_frame_count: Some(
            histogram
                .iter()
                .filter(|(ms, _)| *ms >= 700.0)
                .map(|(_, count)| *count)
                .sum(),
        ),
        total_frames: total_frames.or_else(|| (histogram_total > 0).then_some(histogram_total)),
        matched_layer,
    }
}

fn parse_gfxinfo(raw: &str) -> FpsStats {
    let mut durations_ms = Vec::<f64>::new();

    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') || !trimmed.contains(',') {
            continue;
        }

        let mut parts = trimmed.splitn(18, ',');

        let flag = match parts.next().and_then(|v| v.trim().parse::<i64>().ok()) {
            Some(0) => 0i64,
            _ => continue,
        };
        let _ = flag;

        let intended_vsync = match parts.next().and_then(|v| v.trim().parse::<i64>().ok()) {
            Some(v) => v,
            None => continue,
        };

        let mut field_index = 2usize;
        let frame_completed = loop {
            match parts.next() {
                Some(v) if field_index == 16 => {
                    break match v.trim().parse::<i64>().ok() {
                        Some(v) => v,
                        None => continue,
                    }
                }
                Some(_) => field_index += 1,
                None => continue,
            }
        };

        if frame_completed <= intended_vsync {
            continue;
        }
        let duration_ms = (frame_completed - intended_vsync) as f64 / 1_000_000.0;
        if duration_ms.is_finite() && duration_ms > 0.0 && duration_ms < 5_000.0 {
            durations_ms.push(duration_ms);
        }
    }

    durations_ms.sort_by(|a, b| a.total_cmp(b));
    let total = durations_ms.len() as u64;
    let mean = if durations_ms.is_empty() {
        None
    } else {
        Some(durations_ms.iter().sum::<f64>() / durations_ms.len() as f64)
    };

    let histogram: Vec<(f64, u64)> = {
        let mut hist: Vec<(f64, u64)> = Vec::new();
        for &ms in &durations_ms {
            if let Some(last) = hist.last_mut() {
                if (last.0 - ms).abs() < f64::EPSILON {
                    last.1 += 1;
                    continue;
                }
            }
            hist.push((ms, 1));
        }
        hist
    };

    let p50 = percentile_ms(&histogram, total, 0.50);
    let p99 = percentile_ms(&histogram, total, 0.99);
    let best = durations_ms.first().copied();
    let worst = durations_ms.last().copied();
    FpsStats {
        source: None,
        average_fps: mean.map(|ms| 1000.0 / ms).map(|fps| fps.clamp(0.0, 1000.0)),
        five_percent_low_fps: (total >= 20)
            .then(|| tail_low_fps(&histogram, total, 0.05))
            .flatten(),
        one_percent_low_fps: (total >= 100)
            .then(|| tail_low_fps(&histogram, total, 0.01))
            .flatten(),
        point_one_percent_low_fps: (total >= 1_000)
            .then(|| tail_low_fps(&histogram, total, 0.001))
            .flatten(),
        median_fps: p50.filter(|ms| *ms > 0.0).map(|ms| 1000.0 / ms),
        minimum_instant_fps: worst.filter(|ms| *ms > 0.0).map(|ms| 1000.0 / ms),
        maximum_instant_fps: best
            .filter(|ms| *ms > 0.0)
            .map(|ms| (1000.0 / ms).min(1000.0)),
        frame_time_ms: mean,
        frame_time_p95_ms: percentile_ms(&histogram, total, 0.95),
        frame_time_p99_ms: p99,
        best_frame_time_ms: best,
        worst_frame_time_ms: worst,
        frame_stability_score: mean
            .zip(p99)
            .map(|(avg, tail)| (avg / tail * 100.0).clamp(0.0, 100.0)),
        frame_pacing_score: frame_pacing_score(&histogram, mean),
        stutter25ms_count: Some(durations_ms.iter().filter(|ms| **ms >= 25.0).count() as u64),
        stutter50ms_count: Some(durations_ms.iter().filter(|ms| **ms >= 50.0).count() as u64),
        stutter100ms_count: Some(
            durations_ms.iter().filter(|ms| **ms >= 100.0).count() as u64,
        ),
        micro_stutter_count: Some(
            durations_ms
                .iter()
                .filter(|ms| **ms >= 20.0 && **ms < 50.0)
                .count() as u64,
        ),
        slow_frame_count: Some(durations_ms.iter().filter(|ms| **ms >= 25.0).count() as u64),
        frozen_frame_count: Some(
            durations_ms.iter().filter(|ms| **ms >= 700.0).count() as u64,
        ),
        total_frames: (total > 0).then_some(total),
        matched_layer: None,
    }
}

fn weighted_mean_ms(histogram: &[(f64, u64)]) -> Option<f64> {
    let count: u64 = histogram.iter().map(|entry| entry.1).sum();
    if count == 0 {
        return None;
    }
    let sum = histogram
        .iter()
        .map(|(ms, frames)| *ms * *frames as f64)
        .sum::<f64>();
    Some(sum / count as f64)
}

fn frame_pacing_score(histogram: &[(f64, u64)], mean: Option<f64>) -> Option<f64> {
    let mean = mean.filter(|value| *value > 0.0)?;
    let total: u64 = histogram.iter().map(|entry| entry.1).sum();
    if total == 0 {
        return None;
    }
    let variance = histogram
        .iter()
        .map(|(ms, count)| {
            let diff = *ms - mean;
            diff * diff * *count as f64
        })
        .sum::<f64>()
        / total as f64;
    let coefficient = variance.sqrt() / mean;
    Some((100.0 / (1.0 + coefficient * 2.0)).clamp(0.0, 100.0))
}

fn percentile_ms(histogram: &[(f64, u64)], total: u64, percentile: f64) -> Option<f64> {
    if total == 0 {
        return None;
    }
    let target = (total as f64 * percentile).ceil() as u64;
    let mut cumulative = 0_u64;
    for (ms, count) in histogram {
        cumulative = cumulative.saturating_add(*count);
        if cumulative >= target {
            return Some(*ms);
        }
    }
    histogram.last().map(|entry| entry.0)
}

fn tail_low_fps(histogram: &[(f64, u64)], total: u64, tail_fraction: f64) -> Option<f64> {
    if total == 0 {
        return None;
    }
    let mut remaining = ((total as f64 * tail_fraction).ceil() as u64).max(1);
    let mut weighted_ms = 0.0;
    let mut selected = 0_u64;
    for (ms, count) in histogram.iter().rev() {
        if remaining == 0 {
            break;
        }
        let take = (*count).min(remaining);
        weighted_ms += *ms * take as f64;
        selected += take;
        remaining -= take;
    }
    if selected == 0 || weighted_ms <= 0.0 {
        None
    } else {
        Some(1000.0 / (weighted_ms / selected as f64))
    }
}

fn parse_gpu(raw: &str, fallback_model: &str) -> GpuStats {
    let key_value_regex = gpu_kv_regex();
    let number_regex = gpu_number_regex();

    let mut model = (!fallback_model.trim().is_empty()).then(|| fallback_model.trim().to_string());
    let mut frequency_mhz = None;
    let mut min_frequency_mhz = None;
    let mut max_frequency_mhz = None;
    let mut governor = None;
    let mut load_percent = None;

    for capture in key_value_regex.captures_iter(raw) {
        let key = capture
            .get(1)
            .map(|v| v.as_str().to_ascii_lowercase())
            .unwrap_or_default();
        let value = capture.get(2).map(|v| v.as_str().trim()).unwrap_or_default();
        if model.is_none() && matches!(key.as_str(), "model" | "renderer" | "gpu") && !value.is_empty() {
            model = Some(value.to_string());
        }
        if max_frequency_mhz.is_none() && (key.contains("maxfreq") || key.contains("max_freq")) {
            max_frequency_mhz = first_number(value, number_regex).map(normalize_frequency_mhz);
        } else if min_frequency_mhz.is_none()
            && (key.contains("minfreq") || key.contains("min_freq"))
        {
            min_frequency_mhz = first_number(value, number_regex).map(normalize_frequency_mhz);
        } else if frequency_mhz.is_none() && (key.contains("freq") || key.contains("clock")) {
            frequency_mhz = first_number(value, number_regex).map(normalize_frequency_mhz);
        }
        if governor.is_none() && key.contains("governor") && !value.is_empty() {
            governor = Some(value.to_string());
        }
        if load_percent.is_none()
            && (key.contains("load") || key.contains("util") || key.contains("busy"))
        {
            load_percent = parse_load(value, number_regex);
        }
    }

    if frequency_mhz.is_none() {
        for line in raw.lines().filter(|line| {
            let lower = line.to_ascii_lowercase();
            (lower.contains("freq") || lower.contains("clock")) && !lower.contains("max")
        }) {
            if let Some(value) = first_number(line, number_regex) {
                frequency_mhz = Some(normalize_frequency_mhz(value));
                break;
            }
        }
    }

    if load_percent.is_none() {
        for line in raw.lines().filter(|line| {
            let lower = line.to_ascii_lowercase();
            lower.contains("load") || lower.contains("busy") || lower.contains("util")
        }) {
            if let Some(value) = parse_load(line, number_regex) {
                load_percent = Some(value);
                break;
            }
        }
    }

    GpuStats {
        model,
        frequency_mhz: frequency_mhz.filter(|value| value.is_finite() && *value >= 0.0),
        min_frequency_mhz: min_frequency_mhz
            .filter(|value| value.is_finite() && *value >= 0.0),
        max_frequency_mhz: max_frequency_mhz
            .filter(|value| value.is_finite() && *value >= 0.0),
        governor,
        load_percent: load_percent.map(|value| value.clamp(0.0, 100.0)),
    }
}

fn first_number(value: &str, regex: &Regex) -> Option<f64> {
    regex
        .find(value)
        .and_then(|matched| matched.as_str().parse::<f64>().ok())
}

fn normalize_frequency_mhz(value: f64) -> f64 {
    if value >= 10_000_000.0 {
        value / 1_000_000.0
    } else if value >= 10_000.0 {
        value / 1_000.0
    } else {
        value
    }
}

fn parse_load(value: &str, regex: &Regex) -> Option<f64> {
    let numbers: Vec<f64> = regex
        .find_iter(value)
        .filter_map(|matched| matched.as_str().parse::<f64>().ok())
        .collect();
    match numbers.as_slice() {
        [busy, total, ..] if *total > 0.0 && !value.contains('%') => Some(busy / total * 100.0),
        [single, ..] => Some(*single),
        _ => None,
    }
}

fn session_csv(input: &str) -> Result<String, serde_json::Error> {
    let rows: Vec<Value> = serde_json::from_str(input)?;
    let headers = [
        "timestamp",
        "sampleIntervalMs",
        "foregroundPackage",
        "foregroundIsGame",
        "eventType",
        "eventLabel",
        "accessMode",
        "fpsSource",
        "fps",
        "fivePercentLowFps",
        "onePercentLowFps",
        "pointOnePercentLowFps",
        "medianFps",
        "minimumInstantFps",
        "maximumInstantFps",
        "frameTimeMs",
        "frameTimeP95Ms",
        "frameTimeP99Ms",
        "bestFrameTimeMs",
        "worstFrameTimeMs",
        "frameStabilityScore",
        "framePacingScore",
        "performanceStabilityScore",
        "stutter25msCount",
        "stutter50msCount",
        "stutter100msCount",
        "microStutterCount",
        "slowFrameCount",
        "frozenFrameCount",
        "estimatedDroppedFrames",
        "missedVsyncCount",
        "refreshRateMismatch",
        "fpsRefreshRatio",
        "totalFrames",
        "frameWindowFrames",
        "cpuUsage",
        "cpuFrequencyMhz",
        "cpuFrequencyMinMhz",
        "cpuFrequencyMaxMhz",
        "cpuPolicyMinMhz",
        "cpuPolicyMaxMhz",
        "cpuPolicyAverageMaxMhz",
        "cpuCoreFrequenciesMhz",
        "cpuCoreUsagePercent",
        "cpuGovernor",
        "cpuClusterSummary",
        "cpuThrottlePercent",
        "cpuThrottled",
        "appPid",
        "appCpuUsage",
        "appRamMb",
        "appRssMb",
        "appNativeHeapMb",
        "appGraphicsMb",
        "appThreadCount",
        "appNice",
        "appCpuset",
        "appUclampMin",
        "appUclampMax",
        "appCpuAffinity",
        "appSchedulerPolicy",
        "graphicsApi",
        "gameModeInfo",
        "socTemperatureC",
        "cpuTemperatureC",
        "gpuTemperatureC",
        "thermalThrottling",
        "thermalStabilityScore",
        "gpuModel",
        "gpuVendor",
        "gpuSource",
        "gpuFrequencyMhz",
        "gpuFrequencyMinMhz",
        "gpuFrequencyMaxMhz",
        "gpuGovernor",
        "gpuLoad",
        "gpuThrottlePercent",
        "gpuThrottled",
        "ramUsedMb",
        "ramTotalMb",
        "ramAvailableMb",
        "swapUsedMb",
        "swapTotalMb",
        "zramUsedMb",
        "memoryPressureAvg10",
        "batteryLevel",
        "batteryTemperatureC",
        "batteryPowerW",
        "batteryPowerSource",
        "batteryCharging",
        "batteryCurrentMa",
        "batteryVoltageV",
        "batteryChargeCounterMah",
        "batteryDrainPercentPerHour",
        "batteryDrainMahPerHour",
        "estimatedGamingMinutes",
        "fpsPerWatt",
        "thermalStatus",
        "refreshRateHz",
        "networkType",
        "rxKbps",
        "txKbps",
        "networkPingMs",
        "networkJitterMs",
        "networkPacketLossPercent",
        "networkProbeTarget",
        "wifiRssiDbm",
        "wifiLinkSpeedMbps",
        "wifiFrequencyMhz",
        "wifiStandard",
        "cellularNetworkType",
        "cellularSignalSummary",
        "windowWidthPx",
        "windowHeightPx",
        "storageUsedGb",
        "storageTotalGb",
        "collectorLatencyMs",
        "monitorCpuUsage",
        "monitorRamMb",
    ];

    let estimated_capacity = rows.len() * headers.len() * 10 + headers.len() * 30;
    let mut output = String::with_capacity(estimated_capacity);
    output.push_str(&headers.join(","));
    output.push('\n');
    for row in &rows {
        let values: Vec<String> = headers.iter().map(|header| csv_cell(row.get(*header))).collect();
        output.push_str(&values.join(","));
        output.push('\n');
    }
    Ok(output)
}

fn csv_cell(value: Option<&Value>) -> String {
    let text = match value {
        None | Some(Value::Null) => String::new(),
        Some(Value::String(value)) => value.clone(),
        Some(other) => other.to_string(),
    };
    format!("\"{}\"", text.replace('"', "\"\""))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_surfaceflinger_lows() {
        let input = r#"
__FPSWATCHER_SOURCE=surfaceflinger
layerName = SurfaceView[com.game/app]
averageFPS = 60.0
totalFrames = 1000
presentToPresent histogram is as below:
8ms=100 16ms=880 33ms=15 66ms=5
"#;
        let result = parse_frame_stats(input, "com.game");
        assert_eq!(result.average_fps, Some(60.0));
        assert!(result.one_percent_low_fps.is_some());
        assert!(result.point_one_percent_low_fps.is_some());
        assert_eq!(result.source.as_deref(), Some("surfaceflinger"));
    }

    #[test]
    fn parses_gpu_busy_pair() {
        let result = parse_gpu("freq=800000000\nmax_freq=1000000000\nload=30 100", "Adreno");
        assert_eq!(result.frequency_mhz, Some(800.0));
        assert_eq!(result.max_frequency_mhz, Some(1000.0));
        assert_eq!(result.load_percent, Some(30.0));
    }

    #[test]
    fn frame_pacing_score_is_bounded() {
        let histogram = vec![(8.0, 80), (9.0, 15), (25.0, 5)];
        let score = frame_pacing_score(&histogram, weighted_mean_ms(&histogram)).unwrap();
        assert!((0.0..=100.0).contains(&score));
    }

    #[test]
    fn parses_gpu_governor_and_limits() {
        let result = parse_gpu(
            "cur_freq=800000000\nmin_freq=200000000\nmax_freq=1000000000\ngovernor=msm-adreno-tz\nload=75%",
            "Adreno",
        );
        assert_eq!(result.frequency_mhz, Some(800.0));
        assert_eq!(result.min_frequency_mhz, Some(200.0));
        assert_eq!(result.max_frequency_mhz, Some(1000.0));
        assert_eq!(result.governor.as_deref(), Some("msm-adreno-tz"));
        assert_eq!(result.load_percent, Some(75.0));
    }

    #[test]
    fn withholds_lows_until_enough_frames_exist() {
        let input = r#"
__FPSWATCHER_SOURCE=surfaceflinger
layerName = SurfaceView[com.game/app]
averageFPS = 60.0
presentToPresent histogram is as below:
16ms=80 33ms=10
"#;
        let result = parse_frame_stats(input, "com.game");
        assert!(result.one_percent_low_fps.is_none());
        assert!(result.point_one_percent_low_fps.is_none());
    }

    #[test]
    fn regex_are_compiled_once() {
        let _r1 = sf_average_regex();
        let _r2 = sf_average_regex();
        assert!(std::ptr::eq(_r1 as *const _, _r2 as *const _));
    }
}
