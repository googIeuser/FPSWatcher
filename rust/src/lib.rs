use regex::Regex;
use serde::Serialize;
use serde_json::Value;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct FpsStats {
    average_fps: Option<f64>,
    p90_fps: Option<f64>,
    p99_fps: Option<f64>,
    frame_time_ms: Option<f64>,
    total_frames: Option<u64>,
    matched_layer: Option<String>,
}

#[derive(Debug, Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct GpuStats {
    model: Option<String>,
    frequency_mhz: Option<f64>,
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
    let stats = parse_surfaceflinger(&raw, &package_name);
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

fn parse_surfaceflinger(raw: &str, package_name: &str) -> FpsStats {
    let average_regex = Regex::new(r"(?i)averageFPS\s*[=:]\s*([0-9]+(?:\.[0-9]+)?)").unwrap();
    let total_regex = Regex::new(r"(?i)totalFrames\s*[=:]\s*([0-9]+)").unwrap();
    let layer_regex = Regex::new(r"(?i)layerName\s*=\s*(.+)").unwrap();
    let histogram_regex = Regex::new(r"([0-9]+)ms=([0-9]+)").unwrap();

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

    let mut histogram: Vec<(u64, u64)> = histogram_regex
        .captures_iter(best_section)
        .filter_map(|capture| {
            let ms = capture.get(1)?.as_str().parse::<u64>().ok()?;
            let count = capture.get(2)?.as_str().parse::<u64>().ok()?;
            Some((ms, count))
        })
        .collect();
    histogram.sort_by_key(|entry| entry.0);

    let histogram_total: u64 = histogram.iter().map(|entry| entry.1).sum();
    let p90_fps = percentile_fps(&histogram, histogram_total, 0.90);
    let p99_fps = percentile_fps(&histogram, histogram_total, 0.99);

    FpsStats {
        average_fps,
        p90_fps,
        p99_fps,
        frame_time_ms: average_fps.filter(|fps| *fps > 0.0).map(|fps| 1000.0 / fps),
        total_frames: total_frames.or_else(|| (histogram_total > 0).then_some(histogram_total)),
        matched_layer,
    }
}

fn percentile_fps(histogram: &[(u64, u64)], total: u64, percentile: f64) -> Option<f64> {
    if total == 0 {
        return None;
    }
    let target = (total as f64 * percentile).ceil() as u64;
    let mut cumulative = 0_u64;
    for (ms, count) in histogram {
        cumulative = cumulative.saturating_add(*count);
        if cumulative >= target {
            return (*ms > 0).then_some(1000.0 / *ms as f64);
        }
    }
    None
}

fn parse_gpu(raw: &str, fallback_model: &str) -> GpuStats {
    let key_value_regex = Regex::new(r"(?m)^\s*([A-Za-z0-9_.-]+)\s*=\s*(.*?)\s*$").unwrap();
    let number_regex = Regex::new(r"-?[0-9]+(?:\.[0-9]+)?").unwrap();

    let mut model = (!fallback_model.trim().is_empty()).then(|| fallback_model.trim().to_string());
    let mut frequency_mhz = None;
    let mut load_percent = None;

    for capture in key_value_regex.captures_iter(raw) {
        let key = capture.get(1).map(|v| v.as_str().to_ascii_lowercase()).unwrap_or_default();
        let value = capture.get(2).map(|v| v.as_str().trim()).unwrap_or_default();
        if model.is_none() && matches!(key.as_str(), "model" | "renderer" | "gpu") && !value.is_empty() {
            model = Some(value.to_string());
        }
        if frequency_mhz.is_none() && (key.contains("freq") || key.contains("clock")) {
            frequency_mhz = first_number(value, &number_regex).map(normalize_frequency_mhz);
        }
        if load_percent.is_none() && (key.contains("load") || key.contains("util") || key.contains("busy")) {
            load_percent = parse_load(value, &number_regex);
        }
    }

    if frequency_mhz.is_none() {
        for line in raw.lines().filter(|line| line.to_ascii_lowercase().contains("freq")) {
            if let Some(value) = first_number(line, &number_regex) {
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
            if let Some(value) = parse_load(line, &number_regex) {
                load_percent = Some(value);
                break;
            }
        }
    }

    GpuStats {
        model,
        frequency_mhz: frequency_mhz.filter(|value| value.is_finite() && *value >= 0.0),
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
        "foregroundPackage",
        "accessMode",
        "fps",
        "p90Fps",
        "p99Fps",
        "frameTimeMs",
        "totalFrames",
        "cpuUsage",
        "cpuFrequencyMhz",
        "appPid",
        "appCpuUsage",
        "appRamMb",
        "socTemperatureC",
        "gpuModel",
        "gpuFrequencyMhz",
        "gpuLoad",
        "ramUsedMb",
        "ramTotalMb",
        "batteryLevel",
        "batteryTemperatureC",
        "batteryPowerW",
        "batteryCharging",
        "batteryCurrentMa",
        "batteryVoltageV",
        "thermalStatus",
        "refreshRateHz",
        "rxKbps",
        "txKbps",
        "storageUsedGb",
        "storageTotalGb",
    ];

    let mut output = String::new();
    output.push_str(&headers.join(","));
    output.push('\n');
    for row in rows {
        let values: Vec<String> = headers
            .iter()
            .map(|header| csv_cell(row.get(*header)))
            .collect();
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
    fn parses_surfaceflinger_histogram() {
        let input = r#"
layerName = SurfaceView[com.game/app]
averageFPS = 60.0
totalFrames = 100
presentToPresent histogram is as below:
16ms=90 33ms=9 66ms=1
"#;
        let result = parse_surfaceflinger(input, "com.game");
        assert_eq!(result.average_fps, Some(60.0));
        assert!(result.p90_fps.is_some());
        assert!(result.p99_fps.is_some());
    }

    #[test]
    fn parses_gpu_busy_pair() {
        let result = parse_gpu("freq=800000000\nload=30 100", "Adreno");
        assert_eq!(result.frequency_mhz, Some(800.0));
        assert_eq!(result.load_percent, Some(30.0));
    }
}
