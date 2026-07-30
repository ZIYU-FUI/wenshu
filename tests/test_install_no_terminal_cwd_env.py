"""Regression checks for R60 installer-generated .env files."""

import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_EXAMPLE = ROOT / ".env.example"


def test_install_sh_filters_terminal_cwd_from_fresh_env(tmp_path: Path) -> None:
    output = tmp_path / ".env"
    subprocess.run(
        [
            "awk",
            "!/^[[:space:]#]*TERMINAL_CWD[[:space:]]*=/",
            str(ENV_EXAMPLE),
        ],
        check=True,
        stdout=output.open("wb"),
    )
    assert "TERMINAL_CWD" not in output.read_text()

    source = (ROOT / "scripts/install.sh").read_text()
    assert "terminal.cwd in config.yaml" in source
    assert "awk '!/^[[:space:]#]*TERMINAL_CWD" in source


def test_install_ps1_filters_terminal_cwd_from_fresh_env() -> None:
    lines = ENV_EXAMPLE.read_text().splitlines()
    ps_filter = re.compile(r"^\s*#?\s*TERMINAL_CWD\s*=", re.IGNORECASE)
    generated = "\n".join(line for line in lines if not ps_filter.search(line))
    assert "TERMINAL_CWD" not in generated

    source = (ROOT / "scripts/install.ps1").read_text()
    assert "terminal.cwd in config.yaml" in source
    assert "Where-Object { $_ -notmatch '^\\s*#?\\s*TERMINAL_CWD\\s*=' }" in source
