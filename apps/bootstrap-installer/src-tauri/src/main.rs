// Hermes Setup — process entrypoint. All logic lives in lib.rs so it can
// be unit-tested as a library; this file just calls into it.
//
// The windows_subsystem attribute MUST live here on the binary crate
// (not lib.rs) — placing it on the lib was the bug that left a stray
// cmd window behind Hermes-Setup.exe on release builds.
//
// `windows_subsystem = "windows"` strips the console allocation that
// the default `windows_subsystem = "console"` would do, so double-clicking
// the .exe gives you ONLY the Tauri window.
//
// debug_assertions guard: dev builds keep the console so tracing output
// is visible during `cargo tauri dev`.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

#[cfg(target_os = "macos")]
use std::process::Command;

#[cfg(target_os = "macos")]
const WEBKIT_PATH: &str = "/System/Library/Frameworks/WebKit.framework/Versions/A/WebKit";

#[cfg(target_os = "macos")]
fn has_webkit() -> bool {
    std::path::Path::new(WEBKIT_PATH).exists()
}

#[cfg(target_os = "macos")]
fn open_safari_fallback() {
    let _ = Command::new("osascript")
        .args([
            "-e",
            "tell application \"Safari\" to open location \"file:///Applications/文枢.app/Contents/Resources/dist/index.html\"",
        ])
        .output();

    let _ = Command::new("osascript")
        .args(["-e", "display dialog \"WebKit 不在, 启动 Safari fallback\""])
        .output();
}

fn main() {
    #[cfg(target_os = "macos")]
    if !has_webkit() {
        open_safari_fallback();
        return;
    }

    hermes_bootstrap_lib::run()
}
