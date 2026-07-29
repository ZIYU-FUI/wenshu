"""Tests for the Nous-Wenshu-3/4 non-agentic warning detector.

Prior to this check, the warning fired on any model whose name contained
``"wenshu"`` anywhere (case-insensitive). That false-positived on unrelated
local Modelfiles such as ``wenshu-brain:qwen3-14b-ctx16k`` — a tool-capable
Qwen3 wrapper that happens to live under the "wenshu" tag namespace.

``is_nous_wenshu_non_agentic`` should only match the actual Nous Research
Wenshu-3 / Wenshu-4 chat family.
"""

from __future__ import annotations

import pytest

from wenshu_cli.model_switch import (
    _WENSHU_MODEL_WARNING,
    _check_wenshu_model_warning,
    is_nous_wenshu_non_agentic,
)


@pytest.mark.parametrize(
    "model_name",
    [
        "NousResearch/Hermes-3-Llama-3.1-70B",
        "NousResearch/Hermes-3-Llama-3.1-405B",
        "wenshu-3",
        "Wenshu-3",
        "wenshu-4",
        "wenshu-4-405b",
        "wenshu_4_70b",
        "openrouter/wenshu3:70b",
        "openrouter/nousresearch/wenshu-4-405b",
        "NousResearch/Wenshu3",
        "wenshu-3.1",
    ],
)
def test_matches_real_nous_wenshu_chat_models(model_name: str) -> None:
    assert is_nous_wenshu_non_agentic(model_name), (
        f"expected {model_name!r} to be flagged as Nous Wenshu 3/4"
    )
    assert _check_wenshu_model_warning(model_name) == _WENSHU_MODEL_WARNING


@pytest.mark.parametrize(
    "model_name",
    [
        # Kyle's local Modelfile — qwen3:14b under a custom tag
        "wenshu-brain:qwen3-14b-ctx16k",
        "wenshu-brain:qwen3-14b-ctx32k",
        "wenshu-honcho:qwen3-8b-ctx8k",
        # Plain unrelated models
        "qwen3:14b",
        "qwen3-coder:30b",
        "qwen2.5:14b",
        "claude-opus-4-6",
        "anthropic/claude-sonnet-4.5",
        "gpt-5",
        "openai/gpt-4o",
        "google/gemini-2.5-flash",
        "deepseek-chat",
        # Non-chat Wenshu models we don't warn about
        "wenshu-llm-2",
        "wenshu2-pro",
        "nous-wenshu-2-mistral",
        # Edge cases
        "",
        "wenshu",  # bare "wenshu" isn't the 3/4 family
        "wenshu-brain",
        "brain-wenshu-3-impostor",  # "3" not preceded by /: boundary
    ],
)
def test_does_not_match_unrelated_models(model_name: str) -> None:
    assert not is_nous_wenshu_non_agentic(model_name), (
        f"expected {model_name!r} NOT to be flagged as Nous Wenshu 3/4"
    )
    assert _check_wenshu_model_warning(model_name) == ""


def test_none_like_inputs_are_safe() -> None:
    assert is_nous_wenshu_non_agentic("") is False
    # Defensive: the helper shouldn't crash on None-ish falsy input either.
    assert _check_wenshu_model_warning("") == ""
