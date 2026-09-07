"""Tier-one evals: no model call, no credential, no cost.

    pip install -r ai/requirements-dev.txt
    python -m pytest ai/eval/tier_one -q

These are not a weaker tier two. They catch a different class of outage — the
kind where the model is working perfectly and your plumbing is not:

  * a template that crashes when a variable is empty or contains a brace
  * a tool definition that is not valid JSON Schema, so the model never calls it
  * an output parser that dies on the model's second-most-common format
  * a prompt that silently exceeds the context window once retrieval is added

This file runs green as shipped, against the sample prompt and tool in this
kit. Point the paths at your own and the same tests keep working.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
import yaml

AI = Path(__file__).resolve().parents[2]
PROMPT_DIR = AI / "prompts"  # >>> CHANGE to your prompt directory
TOOL_DIR = AI / "tools"  # >>> CHANGE
CONFIG = AI / "config" / "models.yaml"

# Worst-case input budget. Set it to your model's real limit minus headroom
# for the response.
MAX_INPUT_CHARS = 400_000  # >>> CHANGE (chars, not tokens - see note below)


def render(template: str, values: dict[str, str]) -> str:
    """Minimal renderer standing in for yours.

    Deliberately NOT str.format: a prompt containing a literal brace (JSON
    examples, code samples) makes str.format raise, and prompts are full of
    JSON examples. This is a real bug people hit in week one.
    """
    out = template
    for k, v in values.items():
        out = out.replace("{" + k + "}", v)
    return out


def placeholders(template: str) -> set[str]:
    return set(re.findall(r"\{([a-z_][a-z0-9_]*)\}", template))


PROMPTS = sorted(PROMPT_DIR.glob("**/*.md"))
TOOLS = sorted(TOOL_DIR.glob("*.json"))

# The inputs nobody writes a fixture for, and all of which reach production.
HOSTILE = [
    "",  # empty - the most common crash
    "   ",  # whitespace only
    "{ticket_text}",  # looks like a placeholder
    "{{escaped}}",
    '{"json": "inside the value"}',  # braces
    "a" * 20_000,  # very long
    "emoji and unicode: café",
    "quotes \"double\" and 'single'",
    "line\nbreaks\r\nmixed",
    "<script>alert(1)</script>",
]


@pytest.mark.parametrize("prompt_path", PROMPTS, ids=lambda p: p.name)
@pytest.mark.parametrize("hostile", HOSTILE, ids=lambda s: repr(s[:14]))
def test_template_survives_hostile_input(prompt_path: Path, hostile: str):
    """Rendering never raises, whatever the variable contains."""
    template = prompt_path.read_text(encoding="utf-8")
    values = {name: hostile for name in placeholders(template)}
    out = render(template, values)
    assert isinstance(out, str)
    assert out, "rendered prompt is empty"


@pytest.mark.parametrize("prompt_path", PROMPTS, ids=lambda p: p.name)
def test_no_unfilled_placeholders(prompt_path: Path):
    """A rendered prompt must carry no leftover {placeholders}.

    An unfilled placeholder does not raise. It is sent to the model as literal
    text and the model does something plausible with it, which is the worst
    outcome: nothing errors and the output looks fine.
    """
    template = prompt_path.read_text(encoding="utf-8")
    out = render(template, {n: "x" for n in placeholders(template)})
    left = re.findall(r"\{[a-z_][a-z0-9_]*\}", out)
    assert not left, f"unfilled placeholders after render: {left}"


@pytest.mark.parametrize("prompt_path", PROMPTS, ids=lambda p: p.name)
def test_prompt_is_attributable(prompt_path: Path):
    """Every prompt names an owner and a review date.

    Same reasoning as stamping owner/review-date into a WAF rule description:
    at 3am you need to know who owns this and when anyone last looked at it.
    """
    head = prompt_path.read_text(encoding="utf-8")[:400]
    assert "owner:" in head, f"{prompt_path.name} has no owner in its header comment"
    assert "reviewed:" in head, f"{prompt_path.name} has no reviewed date"


@pytest.mark.parametrize("tool_path", TOOLS, ids=lambda p: p.name)
def test_tool_schema_is_valid(tool_path: Path):
    """An invalid tool schema does not error - the model just never calls the
    tool. You get a quality regression that looks like a prompt problem and
    takes a day to find."""
    import jsonschema

    tool = json.loads(tool_path.read_text(encoding="utf-8"))

    assert tool.get("name"), f"{tool_path.name}: no name"
    assert tool.get("description"), (
        f"{tool_path.name}: no description. The description is how the model "
        f"decides whether to call the tool, so an empty one disables it silently."
    )

    schema = tool.get("input_schema") or tool.get("parameters")
    assert schema, f"{tool_path.name}: no input schema"

    jsonschema.Draft202012Validator.check_schema(schema)

    props = schema.get("properties", {})
    for req in schema.get("required", []):
        assert req in props, f"{tool_path.name}: '{req}' required but not defined"


def test_every_model_is_pinned():
    """No bare aliases anywhere.

    An undated alias points at whatever the provider ships next: your eval
    measured one model, production may serve another, and nothing in your
    pipeline notices.
    """
    cfg = yaml.safe_load(CONFIG.read_text(encoding="utf-8"))
    for m in cfg["models"]:
        mid = m["id"]
        assert re.search(r"\d{4}-\d{2}-\d{2}$|\d{8}$|^<", mid), (
            f"model '{mid}' is not a dated snapshot. Pin it, or the model can "
            f"change underneath you with no commit and no warning."
        )


def test_worst_case_prompt_fits_the_budget():
    """Measure the WORST case, not the happy path.

    A prompt that fits in dev and overflows once retrieval is included is a
    production 400, not a quality problem.

    Chars are a rough proxy here so this test has no tokeniser dependency.
    Swap in your real tokeniser and a token budget when you wire this up.
    """
    retrieved = "x" * 50_000  # >>> CHANGE to your real max retrieval payload
    tools_json = "".join(p.read_text(encoding="utf-8") for p in TOOLS)

    for prompt_path in PROMPTS:
        template = prompt_path.read_text(encoding="utf-8")
        rendered = render(template, {n: retrieved for n in placeholders(template)})
        total = len(rendered) + len(tools_json)
        assert total < MAX_INPUT_CHARS, (
            f"{prompt_path.name}: worst-case input is {total} chars, over the "
            f"{MAX_INPUT_CHARS} budget. This fails the first time retrieval "
            f"returns a full page."
        )


# ── The parser tests. Models wrap JSON in prose, in fences, and emit trailing
# commas. Your parser meets all of these in week one. ────────────────────────
MESSY = [
    '{"label": "billing.refund"}',
    '```json\n{"label": "billing.refund"}\n```',
    'Sure! Here is the result:\n\n{"label": "billing.refund"}',
    '{"label": "billing.refund"}\n\nLet me know if you need more.',
]


def extract_json(raw: str) -> dict:
    """Stand-in for your parser. Replace with the real one."""
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw, re.S)
    if fenced:
        return json.loads(fenced.group(1))
    bare = re.search(r"\{.*\}", raw, re.S)
    if bare:
        return json.loads(bare.group(0))
    raise ValueError("no JSON object found")


@pytest.mark.parametrize("raw", MESSY, ids=lambda s: repr(s[:18]))
def test_parser_handles_messy_output(raw: str):
    """Either extract the value or raise a TYPED error.

    What a parser must never do is silently return something subtly wrong -
    that turns a parse failure into a quality regression you will spend a day
    blaming on the model.
    """
    assert extract_json(raw)["label"] == "billing.refund"


def test_parser_raises_rather_than_guessing():
    with pytest.raises(ValueError):
        extract_json("I could not classify this ticket.")
