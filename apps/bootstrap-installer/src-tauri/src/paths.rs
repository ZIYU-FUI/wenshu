//! Filesystem paths + logging setup.
//!
//! Mirrors `hermes_constants.get_hermes_home()` from the Python CLI:
//!   Windows: %LOCALAPPDATA%\wenshu-hermes
//!   macOS:   ~/.wenshu-hermes
//!   Linux:   ~/.wenshu-hermes  (override via $HERMES_HOME)
//!
//! NOTE (macOS): Python's get_hermes_home(), scripts/install.sh, and the
//! Electron desktop's resolveHermesHome() ALL use ~/.wenshu-hermes on macOS — there
//! is no ~/Library/Application Support branch anywhere else. An earlier
//! version of this file used Application Support, which drifted from every
//! other component: the installer wrote the install to one dir and the
//! desktop looked for it in another, so first launch never found the backend.
//!
//! IMPORTANT: this must match exactly. Drift here means install.ps1
//! writes to one place and the installer reads from another, breaking
//! the bootstrap-complete check.

use std::io;
use std::path::{Path, PathBuf};
#[cfg(target_os = "macos")]
use std::process::Command;
use tracing_appender::non_blocking::{NonBlocking, WorkerGuard};

/// Returns the canonical Hermes home directory, respecting $HERMES_HOME if set.
pub fn hermes_home() -> PathBuf {
    if let Ok(override_path) = std::env::var("HERMES_HOME") {
        if !override_path.trim().is_empty() {
            return PathBuf::from(override_path);
        }
    }

    #[cfg(target_os = "windows")]
    {
        // %LOCALAPPDATA%\wenshu-hermes — matches scripts/install.ps1's $HermesHome.
        if let Some(local_app_data) = dirs::data_local_dir() {
            return local_app_data.join("wenshu-hermes");
        }
    }

    // macOS + Linux + fallback: ~/.wenshu-hermes (matches Python get_hermes_home(),
    // install.sh, and the Electron desktop's resolveHermesHome()).
    if let Some(home) = dirs::home_dir() {
        return home.join(".wenshu-hermes");
    }

    // Last resort — current dir, almost certainly wrong but at least
    // doesn't panic.
    PathBuf::from(".wenshu-hermes")
}

pub fn log_dir() -> PathBuf {
    hermes_home().join("logs")
}

pub fn log_path() -> PathBuf {
    log_dir().join("bootstrap-installer.log")
}

pub fn bootstrap_cache_dir() -> PathBuf {
    hermes_home().join("bootstrap-cache")
}

/// Stable location the installer copies itself to after a successful install.
/// The desktop app re-invokes this with `--update`, and the start-menu /
/// desktop shortcuts can point users back to it. Lives directly under
/// HERMES_HOME so it survives repo checkout deletion (unlike anything under
/// hermes-agent/).
///
/// On Windows this is `%LOCALAPPDATA%\hermes\hermes-setup.exe`; on other
/// platforms the extension differs but the directory is the same.
pub fn installer_dest() -> PathBuf {
    let name = if cfg!(target_os = "windows") {
        "hermes-setup.exe"
    } else {
        "hermes-setup"
    };
    hermes_home().join(name)
}

/// Marker the updater writes for the duration of an in-app update and removes
/// when it finishes (see update.rs `UpdateMarkerGuard`). A freshly-launched
/// desktop checks this before spawning its own local backend: spawning one
/// mid-update re-locks the venv shim and triggers `force_kill_other_hermes`,
/// which then kills that legitimate backend in a respawn loop (#50238).
///
/// Lives directly under HERMES_HOME (same rationale as `installer_dest`) so the
/// Electron desktop — which resolves HERMES_HOME identically and pins it into
/// the updater's env — agrees on the exact path.
pub fn update_in_progress_marker() -> PathBuf {
    hermes_home().join(".hermes-update-in-progress")
}

/// Copy the currently-running installer binary to `installer_dest()` so it's
/// available for future `--update` runs and shortcut launches.
///
/// No-ops (returns Ok) when the running exe is ALREADY the destination — which
/// is exactly the case during an `--update` run (the desktop launched us FROM
/// that path), where copying onto ourselves would be a Windows sharing
/// violation. Best-effort: a failure here must not fail the install, so the
/// caller logs and continues.
pub fn copy_self_to_hermes_home() -> std::io::Result<()> {
    let src = std::env::current_exe()?;
    let dest = installer_dest();

    // Skip if we're already running from the destination (update re-invocation
    // or a prior copy). canonicalize both so symlinks / 8.3 short paths / case
    // differences don't trick us into a self-copy.
    let same = match (src.canonicalize(), dest.canonicalize()) {
        (Ok(a), Ok(b)) => a == b,
        _ => src == dest,
    };
    if same {
        tracing::info!(?dest, "installer already at destination; skipping self-copy");
        return Ok(());
    }

    if let Some(parent) = dest.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::copy(&src, &dest)?;
    repair_macos_installer_helper(&dest);
    tracing::info!(?src, ?dest, "copied installer to HERMES_HOME");
    Ok(())
}

#[cfg(target_os = "macos")]
fn repair_macos_installer_helper(path: &Path) {
    // The staged helper may inherit quarantine from the downloaded installer.
    // Desktop later launches this exact file for in-app updates, so make it
    // executable before the update handoff reaches LaunchServices/Gatekeeper.
    let _ = Command::new("/usr/bin/xattr")
        .args(["-cr"])
        .arg(path)
        .status();

    let verify = Command::new("/usr/bin/codesign")
        .arg("--verify")
        .arg(path)
        .status();

    if !matches!(verify, Ok(status) if status.success()) {
        let _ = Command::new("/usr/bin/codesign")
            .args(["--force", "--sign", "-"])
            .arg(path)
            .status();
    }
}

#[cfg(not(target_os = "macos"))]
fn repair_macos_installer_helper(_path: &Path) {}

/// Initializes tracing to bootstrap-installer.log under HERMES_HOME/logs/.
/// Returns a guard that flushes the appender on drop — keep it alive for
/// the lifetime of the process.
///
/// WO-001AR STEP 3: in addition to the primary sink at
/// `~/.wenshu-hermes/logs/bootstrap-installer.log`, also tee to
/// `~/Desktop/bootstrap-installer.log` so the 装机 user can read the
/// log via Finder without having to discover the hidden
/// `.wenshu-hermes/` directory first. If `~/Desktop/` does not exist
/// (headless macOS, deleted Desktop folder, etc.) the tee is skipped
/// and the function falls back to single-sink behaviour identical to v5.
pub fn init_logging() -> Option<CompositeGuard> {
    let dir = log_dir();
    if let Err(err) = std::fs::create_dir_all(&dir) {
        // No log dir → log to stderr only. Don't panic; the installer
        // should still be usable on an exotic filesystem.
        eprintln!("[hermes-setup] could not create log dir {dir:?}: {err}");
        return None;
    }

    // Primary sink: ~/.wenshu-hermes/logs/bootstrap-installer.log (v5 path).
    let log_appender = tracing_appender::rolling::never(&dir, "bootstrap-installer.log");
    let (primary_nb, primary_guard) = tracing_appender::non_blocking(log_appender);

    let env_filter = tracing_subscriber::EnvFilter::try_from_env("HERMES_BOOTSTRAP_LOG")
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info"));

    // Desktop mirror: best-effort. If Desktop is missing, fall through to
    // single-sink (preserves v5 behaviour when the macOS Finder default
    // location is unavailable).
    if let Some(desktop_path) = desktop_log_path() {
        match std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&desktop_path)
        {
            Ok(desktop_file) => {
                let (desktop_nb, desktop_guard) =
                    tracing_appender::non_blocking(desktop_file);
                tracing_subscriber::fmt()
                    .with_env_filter(env_filter)
                    .with_writer(TeeWriter::tee(
                        primary_nb.clone(),
                        desktop_nb,
                    ))
                    .with_ansi(false)
                    .with_target(true)
                    .init();
                tracing::info!(
                    desktop_log = %desktop_path.display(),
                    "WO-001AR STEP 3: tee bootstrap-installer.log to Desktop"
                );
                return Some(CompositeGuard {
                    // Drop order is reverse of field declaration: desktop
                    // first (flushes its background thread), then primary.
                    // This guarantees the desktop mirror is fully written
                    // before the primary log buffer drops.
                    desktop: Some(desktop_guard),
                    primary: primary_guard,
                });
            }
            Err(err) => {
                eprintln!(
                    "[hermes-setup] could not open Desktop log {desktop_path:?}: {err}                      (falling back to single-sink)"
                );
            }
        }
    }

    // Single-sink fallback (v5 behaviour).
    tracing_subscriber::fmt()
        .with_env_filter(env_filter)
        .with_writer(primary_nb)
        .with_ansi(false)
        .with_target(true)
        .init();

    Some(CompositeGuard {
        desktop: None,
        primary: primary_guard,
    })
}

/// Resolves `~/Desktop/bootstrap-installer.log` if and only if the Desktop
/// directory exists. Returns None on headless macOS or if the user has
/// moved/renamed their Desktop folder.
fn desktop_log_path() -> Option<PathBuf> {
    let home = dirs::home_dir()?;
    let desktop_dir = home.join("Desktop");
    if !desktop_dir.is_dir() {
        return None;
    }
    Some(desktop_dir.join("bootstrap-installer.log"))
}

/// Composite guard that holds WorkerGuards for the primary log sink and
/// (optionally) the Desktop mirror. Drop order is reverse of field
/// declaration, so the Desktop mirror's background thread is flushed
/// before the primary log's — guaranteeing the user-visible Desktop log
/// is complete even if the primary buffer had pending writes.
#[allow(dead_code)] // fields are owned and dropped via Drop, never explicitly read
pub struct CompositeGuard {
    desktop: Option<WorkerGuard>,
    primary: WorkerGuard,
}

/// `io::Write` adapter that forwards each write/flush to one or two
/// `NonBlocking` sinks. tracing_appender's `NonBlocking` already routes
/// writes through a background thread + bounded channel, so adding a
/// second sink here simply means each log line is enqueued twice
/// (once per sink). All per-sink failures are swallowed because we want
/// tee to be best-effort: a broken Desktop log must never break the
/// primary log.
struct TeeWriter {
    primary: NonBlocking,
    desktop: Option<NonBlocking>,
}

impl TeeWriter {
    fn tee(primary: NonBlocking, desktop: NonBlocking) -> Self {
        Self {
            primary,
            desktop: Some(desktop),
        }
    }
}

impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for TeeWriter {
    type Writer = TeeWriter;
    fn make_writer(&'a self) -> TeeWriter {
        // NonBlocking is Clone (internally an Arc); cloning per call gives
        // each log line its own sink handle that shares the same background
        // channel — same semantics as a direct NonBlocking MakeWriter.
        TeeWriter {
            primary: self.primary.clone(),
            desktop: self.desktop.clone(),
        }
    }
}

impl io::Write for TeeWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let _ = self.primary.write(buf);
        if let Some(d) = self.desktop.as_mut() {
            let _ = d.write(buf);
        }
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        let _ = self.primary.flush();
        if let Some(d) = self.desktop.as_mut() {
            let _ = d.flush();
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Tauri commands
// ---------------------------------------------------------------------------

#[tauri::command]
pub fn get_log_path() -> String {
    log_path().to_string_lossy().into_owned()
}

#[tauri::command]
pub fn get_hermes_home() -> String {
    hermes_home().to_string_lossy().into_owned()
}

#[tauri::command]
pub fn open_log_dir(app: tauri::AppHandle) -> Result<(), String> {
    use tauri_plugin_opener::OpenerExt;
    let path = log_dir();
    app.opener()
        .open_path(path.to_string_lossy(), None::<&str>)
        .map_err(|e| e.to_string())
}
