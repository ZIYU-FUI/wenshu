from pathlib import Path


def test_windows_native_install_path_docs_match_installer() -> None:
    doc = Path("website/docs/user-guide/windows-native.md").read_text()
    install = Path("scripts/install.ps1").read_text()

    assert "%LOCALAPPDATA%\\wenshu\\wenshu-agent\\venv\\Scripts" in doc
    assert "Get-Command wenshu        # should print C:\\Users\\<you>\\AppData\\Local\\wenshu\\wenshu-agent\\venv\\Scripts\\wenshu.exe" in doc
    assert '$wenshuBin = "$InstallDir\\venv\\Scripts"' in install
