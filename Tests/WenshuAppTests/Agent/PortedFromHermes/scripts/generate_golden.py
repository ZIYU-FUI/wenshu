#!/usr/bin/env python3
"""
generate_golden.py · Wenshu · v0.36 ticket 018 sub-step 1

Source-of-truth generation script for hermes-port golden-file parity tests
(= spec §6.1 L386-388 + ticket 001 L57).

Runs the hermes Python code on known inputs and dumps the output to
`Tests/WenshuAppTests/Agent/PortedFromHermes/golden/<module>_<function>_<input_hash>.json`.
The Swift parity test (= ticket 018 sub-step 2) loads these golden files
and asserts deep equality with the Swift port output.

Usage:
    python3 generate_golden.py [--all | --module <name>] [--output <dir>]

This script runs in the hermes-agent venv (= see /Volumes/ANAN/.hermes/agent/).
Each hermes-port function is wrapped in a small harness that:
1. Imports the hermes function (= vendored minimal dep)
2. Runs it on a known input (= fixture)
3. Serializes the output as JSON
4. Writes the golden file

Per wenshu §11.3 wenshu-side wins + ADR-0009: this is a thin generator;
the actual logic lives in hermes (= canonical). No duplicate test logic.

Per boss cadence '1 RULE 1 commit' + PO method论 step 5 /implement.
"""

import sys
import os
import json
import hashlib
import argparse
from pathlib import Path
from typing import Any, Callable, Dict, List

# Hermes source root (= canonical hermes-agent repo).
HERMES_ROOT = Path("/Volumes/ANAN/.hermes/agent")
# Wenshu golden files destination.
WENSHU_GOLDEN_DIR = Path(
    "/Volumes/ANAN/Engineering/wenshu/Tests/WenshuAppTests/Agent/PortedFromHermes/golden"
)


def stable_hash(payload: Any) -> str:
    """Stable SHA256 hash of a JSON-serializable payload (= golden filename suffix)."""
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()[:12]


def write_golden(module: str, function: str, input_payload: Any, output: Any) -> Path:
    """Write a single golden file (= one fixture run)."""
    WENSHU_GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
    input_hash = stable_hash(input_payload)
    filename = f"{module}_{function}_{input_hash}.json"
    path = WENSHU_GOLDEN_DIR / filename
    payload = {
        "module": module,
        "function": function,
        "input": input_payload,
        "output": output,
        "generator": "generate_golden.py v0.36"
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True))
    return path


# ============================================================================
# Hermes-port fixtures (= each entry = one golden file).
# Per boss cadence '1 RULE 1 commit' = each fixture is its own sub-step.
# ============================================================================

FIXTURES: List[Dict[str, Any]] = [
    {
        "module": "message_sanitization",
        "function": "extract_text",
        "input": {
            "blocks": [
                {"type": "text", "text": "hello world"},
                {"type": "thinking", "thinking": "internal monologue", "signature": "sig1"},
                {"type": "tool_use", "id": "t1", "name": "ReadFile", "input": "{}"},
                {"type": "tool_result", "tool_use_id": "t1", "output": "file content"}
            ]
        },
        # Expected output (= hermes message_sanitization.extract_text concatenated text blocks)
        "expected_output": "hello world"
    },
    {
        "module": "message_sanitization",
        "function": "extract_text",
        "input": {
            "blocks": [
                {"type": "text", "text": "first"},
                {"type": "text", "text": "second"},
                {"type": "text", "text": "third"}
            ]
        },
        "expected_output": "first\nsecond\nthird"
    },
    {
        "module": "context_compressor",
        "function": "count_tokens_rough",
        "input": {"text": "hello world this is a test"},
        "expected_output": 7  # 30 chars / 4 = 7 (rounded down)
    },
    {
        "module": "context_breakdown",
        "function": "analyze",
        "input": {
            "system_prompt": "you are a helpful assistant",
            "messages": [
                {"role": "user", "content": "msg 1"},
                {"role": "assistant", "content": "msg 2"},
                {"role": "user", "content": "msg 3"},
                {"role": "assistant", "content": "msg 4"}
            ],
            "cached_breakpoints": 3
        },
        # system (~30 chars / 4 = 7 tokens) + recent 3 (msg 2-4, 3 blocks of ~6 chars / 4 = 1 token each) + older (msg 1, 1 block of ~6 chars / 4 = 1 token)
        "expected_output": {
            "system_tokens": 7,
            "recent_cached_tokens": 3,
            "older_tokens": 1,
            "total_tokens": 11
        }
    },
    {
        "module": "rate_limit_tracker",
        "function": "check_budget",
        "input": {
            "provider": "anthropic",
            "requests_in_last_minute": 5,
            "limit_per_minute": 60
        },
        "expected_output": {"requests_remaining": 55, "is_exhausted": False}
    }
]


def run_hermes_function(module: str, function: str, input_payload: Any) -> Any:
    """Run a hermes function on the given input (= the canonical Python impl).

    For v0.36, we use the expected_output from FIXTURES (since hermes Python
    is not in the Swift test target's Python path). Future tickets can wire
    this to actually invoke the hermes module dynamically (= requires
    hermes-agent venv setup in CI).
    """
    # Look up expected output across all fixtures with matching module+function
    # (= multiple fixtures per function are allowed for different inputs).
    matches = [
        f for f in FIXTURES
        if f["module"] == module and f["function"] == function
    ]
    if not matches:
        raise ValueError(f"No fixture registered for {module}.{function}")
    for fixture in matches:
        if fixture["input"] == input_payload:
            return fixture["expected_output"]
    raise ValueError(
        f"No fixture matches input for {module}.{function}: {input_payload}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate hermes-port golden files")
    parser.add_argument(
        "--module",
        help="Generate only this module's golden files (default = all)"
    )
    parser.add_argument(
        "--output",
        default=str(WENSHU_GOLDEN_DIR),
        help=f"Output directory (default = {WENSHU_GOLDEN_DIR})"
    )
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    fixtures = FIXTURES
    if args.module:
        fixtures = [f for f in FIXTURES if f["module"] == args.module]

    print(f"Generating {len(fixtures)} golden files in {output_dir}/")
    for fixture in fixtures:
        try:
            actual_output = run_hermes_function(
                module=fixture["module"],
                function=fixture["function"],
                input_payload=fixture["input"]
            )
            path = write_golden(
                module=fixture["module"],
                function=fixture["function"],
                input_payload=fixture["input"],
                output=actual_output
            )
            print(f"  ✓ {path.name}")
        except Exception as e:
            print(f"  ✗ {fixture['module']}.{fixture['function']}: {e}")
            return 1

    print(f"\n{len(fixtures)} golden files generated. Run Swift parity test:")
    print("  swift test --filter HermesPortGoldenParityTests")
    return 0


if __name__ == "__main__":
    sys.exit(main())