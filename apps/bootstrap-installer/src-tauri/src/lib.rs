//! Wenshu Setup — Tauri entrypoint.
//!
//! Spawns a single window pointed at the React frontend (apps/bootstrap-installer/src/).
//! All install-time work lives in `bootstrap.rs` and is invoked through the Tauri
//! commands registered at the bottom of `run()`.
//!
//! The Windows-subsystem strip lives on the binary crate (src/main.rs), not
//! here — a crate-level attribute on a lib doesn't propagate to the linker
//! flags of the executable that consumes it.

mod bootstrap;
mod events;
mod install_script;
mod paths;
mod powershell;
mod update;

use std::sync::Arc;
use tokio::sync::Mutex;

/// How the installer was invoked. Resolved once from the process args in
/// `run()` and exposed to the frontend via `get_mode` so it can route to the
/// install flow (first-run onboarding) or the update flow (driven by the
/// desktop app handing off via `Wenshu-Setup.exe --update`).
///
/// Bare launch (double-click, first-run) => Install.
/// `--update` (spawned by the desktop's "Update" button) => Update.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum AppMode {
    Install,
    Update,
}

impl AppMode {
    /// Resolve the mode from an argument iterator. Anything containing the
    /// `--update` flag selects Update; otherwise Install. Kept arg-iterator
    /// generic (not reading `std::env` directly) so it's unit-testable.
    pub fn from_args<I, S>(args: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        for a in args {
            if a.as_ref() == "--update" {
                return AppMode::Update;
            }
        }
        AppMode::Install
    }
}

/// Returns true when the args request a forced installer UI (repair/reinstall)
/// via `--reinstall` or `--repair`, which overrides the macOS launcher
/// fast-path so a broken install can be repaired. Arg-iterator generic so it's
/// unit-testable, mirroring `AppMode::from_args`. Independent of mode selection:
/// these flags never flip Install<->Update.
pub fn force_setup_from_args<I, S>(args: I) -> bool
where
    I: IntoIterator<Item = S>,
    S: AsRef<str>,
{
    args.into_iter()
        .any(|a| a.as_ref() == "--reinstall" || a.as_ref() == "--repair")
}

/// Process-wide install state, shared across Tauri commands.
///
/// The bootstrap is a one-shot, single-tenant process — we only need one
/// of these per window. `Arc<Mutex<...>>` lets command handlers grab it
/// without lifetime gymnastics.
pub struct AppState {
    pub bootstrap: Mutex<Option<bootstrap::BootstrapHandle>>,
    /// How this process was launched (install vs update). Immutable for the
    /// lifetime of the process; read by the `get_mode` command.
    pub mode: AppMode,
}

impl AppState {
    fn new(mode: AppMode) -> Self {
        Self {
            bootstrap: Mutex::new(None),
            mode,
        }
    }
}

/// Frontend → Rust: which flow should the UI render?
#[tauri::command]
fn get_mode(state: tauri::State<'_, Arc<AppState>>) -> AppMode {
    state.mode
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Tracing → bootstrap-installer.log under WENSHU_HOME/logs/ so install
    // failures leave a trail for support. Console output also goes here in
    // debug builds.
    let _guard = paths::init_logging();

    // WO-001AO (8/26 system-prerequisites bug v4): on a fresh install the
    // prerequisites stage can hang silently for 2+ minutes on captive-portal
    // / filtered-DNS networks because install.sh's `curl -LsSf
    // https://astral.sh/uv/install.sh` has no `--max-time`. A `tracing` info
    // line here gives support (and the bootstrap-installer.log forensic
    // trail) an immediate "we entered the installer, WENSHU_HOME is at X"
    // anchor — without it, a 2-minute silent hang leaves zero breadcrumbs
    // and the support reply is "we don't know where it hung".
    let wenshu_home_for_diag = paths::wenshu_home();
    tracing::info!(
        wenshu_home = %wenshu_home_for_diag.display(),
        "wenshu setup diagnostics: WENSHU_HOME resolved"
    );
    if let Some(parent) = wenshu_home_for_diag.parent() {
        let probe = parent.join(".wenshu-setup-write-probe");
        match std::fs::write(&probe, b"ok") {
            Ok(()) => {
                let _ = std::fs::remove_file(&probe);
                tracing::info!(
                    probe = %probe.display(),
                    "WENSHU_HOME parent is writable"
                );
            }
            Err(err) => {
                tracing::error!(
                    probe = %probe.display(),
                    error = %err,
                    "WENSHU_HOME parent is NOT writable — installer UI will fail to start.                      Move 文枢.app to a writable Applications folder, or chmod+chown its parent."
                );
            }
        }
    }

    let mode = AppMode::from_args(std::env::args().skip(1));
    // Escape hatch: `--reinstall`/`--repair` forces the installer UI even when
    // 文枢 is already installed, so users can re-run setup to repair a broken
    // install instead of the launcher fast path silently relaunching the app.
    let force_setup = force_setup_from_args(std::env::args().skip(1));
    tracing::info!(?mode, force_setup, "文枢 installer starting");

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_shell::init())
        .manage(Arc::new(AppState::new(mode)))
        .setup(move |app| {
            use tauri::Manager;
            eprintln!("[wenshu-setup] setup entered: mode={mode:?}, force_setup={force_setup}");
            tracing::info!(?mode, force_setup, "setup 回调已触发");
            // Launcher fast path (macOS only): a bare ("Install") launch when
            // 文枢 is already installed should NOT show the installer or
            // rebuild — it should just open the app, so the /Applications
            // "文枢" doubles as a normal launcher (first run installs, every
            // later run launches instantly). The window is kept hidden until
            // here via `"visible": false` so this path never flashes a window.
            //
            // Gated to macOS deliberately: on Windows/Linux the installer keeps
            // its existing behavior (Windows users relaunch via the Start
            // Menu/Desktop "文枢" shortcuts that install.ps1 creates, and a
            // reliable detached relaunch there needs the DETACHED_PROCESS +
            // startup-grace handling used by launch_wenshu_desktop — out of
            // scope here). So this is a pure no-op on non-macOS.
            //
            // `--reinstall`/`--repair` opts out so a broken install can be
            // repaired by re-running setup instead of launching the bad app.
            if cfg!(target_os = "macos") && mode == AppMode::Install && !force_setup {
                let install_root = paths::wenshu_home().join("wenshu-agent");
                let managed_uv = paths::wenshu_home().join("bin").join("uv");
                // WO-001AO: refuse to fast-path when managed uv is missing.
                // The 8/26 hang proved the launcher silently skipping
                // re-install when uv disappeared left the user in a broken
                // state — they'd double-click /Applications/文枢.app and
                // get nothing. If uv is gone, treat the install as broken
                // and show the installer UI so prerequisites can re-run.
                let uv_present = managed_uv.is_file();
                if bootstrap::wenshu_is_installed(&install_root) && uv_present {
                    // WO-001BI R120: stale-check before fast-path. The
                    // installed .app was built from whatever commit was
                    // HEAD when pnpm build last ran. If the user (or a
                    // prior `wenshu update`) has since advanced the source
                    // repo under `$WENSHU_HOME/wenshu-agent`, the .app on
                    // disk is older than the source — fast-pathing into
                    // it silently strands the user on the old self-update
                    // code (R117 feedback, 8/31). Compare the bundled
                    // install-stamp.json commit against the source repo's
                    // current HEAD; if they differ, refuse the fast-path
                    // and route through the R113 update flow (which
                    // rebuilds the .app, copies it into place, then the
                    // user's NEXT launch of /Applications/文枢.app picks
                    // up the fresh build via this same fast-path). The
                    // user's CURRENT launch gets the installer UI with
                    // update stages, mirrors what `--update` mode already
                    // does.
                    let app_bundle = bootstrap::resolve_wenshu_desktop_app(&install_root);
                    let install_stamp = app_bundle
                        .as_ref()
                        .and_then(|b| paths::load_install_stamp_from_bundle(b));
                    let repo_head = paths::repo_head_commit(&install_root);
                    let stale = paths::installed_commit_is_stale(
                        install_stamp.as_ref(),
                        repo_head.as_deref(),
                    );
                    if stale {
                        let stamp_commit = install_stamp.as_ref().map(|s| s.commit.clone());
                        tracing::warn!(
                            app_bundle = ?app_bundle.as_ref().map(|p| p.display().to_string()),
                            stamp_commit = ?stamp_commit,
                            repo_head = ?repo_head,
                            "R120: 已安装的 .app 落后于源码仓库 — 拒绝快速通道,改走更新流程"
                        );
                        // Fire the R113 update flow async; emitting the
                        // `manifest` event from start_update flips the
                        // frontend's `route` to 'progress' so the user
                        // lands on the existing update UI (same UX as a
                        // desktop-launched --update handoff).
                        let app_for_update = app.handle().clone();
                        tauri::async_runtime::spawn(async move {
                            if let Err(err) = update::start_update(app_for_update).await {
                                tracing::error!(?err, "R120 stale-path: start_update 失败");
                            }
                        });
                        // Fall through to the UI-display block below —
                        // do NOT exit, the user needs to see (and
                        // survive) the update progress. exit(0) here
                        // would race the spawned update task.
                    } else {
                        match bootstrap::spawn_installed_desktop(&install_root) {
                            Ok(()) => {
                                // Brief grace so the spawned app is registered
                                // before we exit (mirrors launch_wenshu_desktop).
                                std::thread::sleep(std::time::Duration::from_millis(200));
                                tracing::info!("wenshu 已安装 — 已重新启动桌面端,安装程序即将退出");
                                app.handle().exit(0);
                                return Ok(());
                            }
                            Err(err) => {
                                tracing::warn!(?err, "重新启动桌面端失败,显示安装程序界面");
                            }
                        }
                    }
                } else if !uv_present {
                    tracing::warn!(
                        managed_uv = %managed_uv.display(),
                        "managed uv 缺失 — 拒绝启动快速通道,显示安装程序界面"
                    );
                }
            }
            // First run / repair install, or Update mode: reveal the UI.
            match app.get_webview_window("main") {
                Some(win) => {
                    if let Err(err) = win.show() {
                        tracing::error!(?err, "无法显示主安装窗口");
                    }
                }
                None => {
                    tracing::error!("找不到主安装 WebView,安装程序界面将不显示");
                }
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Mode (install vs update)
            get_mode,
            // Bootstrap lifecycle
            bootstrap::start_bootstrap,
            bootstrap::cancel_bootstrap,
            bootstrap::get_bootstrap_status,
            // Update lifecycle
            update::start_update,
            // Hand-off
            bootstrap::launch_wenshu_desktop,
            // Diagnostics
            paths::get_log_path,
            paths::get_wenshu_home,
            paths::open_log_dir,
        ])
        .run(tauri::generate_context!())
        .expect("error while running 文枢 Setup");
}

#[cfg(test)]
mod tests {
    use super::{force_setup_from_args, AppMode};

    #[test]
    fn bare_args_are_install() {
        assert_eq!(AppMode::from_args(Vec::<String>::new()), AppMode::Install);
        assert_eq!(AppMode::from_args(["--foo", "bar"]), AppMode::Install);
    }

    #[test]
    fn update_flag_selects_update() {
        assert_eq!(AppMode::from_args(["--update"]), AppMode::Update);
        assert_eq!(
            AppMode::from_args(["--something", "--update", "--else"]),
            AppMode::Update
        );
    }

    #[test]
    fn reinstall_and_repair_flags_force_setup() {
        assert!(force_setup_from_args(["--reinstall"]));
        assert!(force_setup_from_args(["--repair"]));
        assert!(force_setup_from_args(["--foo", "--repair", "--bar"]));
    }

    #[test]
    fn bare_or_unrelated_args_do_not_force_setup() {
        assert!(!force_setup_from_args(Vec::<String>::new()));
        assert!(!force_setup_from_args(["--foo", "bar"]));
        // --update must not be mistaken for a force-setup flag.
        assert!(!force_setup_from_args(["--update"]));
    }

    #[test]
    fn force_setup_flags_do_not_affect_mode_selection() {
        // The repair flags must never flip Install<->Update.
        assert_eq!(AppMode::from_args(["--reinstall"]), AppMode::Install);
        assert_eq!(AppMode::from_args(["--repair"]), AppMode::Install);
        assert_eq!(
            AppMode::from_args(["--update", "--reinstall"]),
            AppMode::Update
        );
    }
}
