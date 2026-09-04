#!/usr/bin/env python3
"""Tier-one evals: no model call, no credential, no cost, runs in seconds.

These are not a weaker version of tier two. They catch a different and
surprisingly large class of production outage — the kind where the model is
working perfectly and your plumbing is not:

  * a template that crashes when a variable is empty or contains a brace
  * a tool definition that is not valid JSON Schema, so the model never calls it
  * an output parser that dies on the model's second-most-common format
  * a prompt that silently exceeds the context window once retrieval is included

Run with:  python -m pytest eval/tier_one -q

ADAPTING THIS: replace the imports and the fixtures. The four test classes are
the shape worth keeping.
"""

import json
import re
from pathlib import Path

import pytest

# >>> CHANGE these to your project's modules.
# from myapp.prompts import render, load_prompt
# from myapp.tools import TOOL_DEFINITIONS
# from myapp.parsing import parse_response

PROMPT_DIR = Path("prompts")  # >>> CHANGE
TOOL_DIR = Path("tools")  # >>> CHANGE
MAX_INPUT_TOKENS = 100_000  # >>> CHANGE to your model's real budget


# ─────────────────────────────────────────────────────────────────────────────
# 1. TEMPLATES RENDER — including the inputs nobody tests
#
# The bugs here are always the same three: empty string, a brace, and unicode.
# All three reach production because the happy-path fixture has none of them.
# ─────────────────────────────────────────────────────────────────────────────
HOSTILE_INPUTS = [
    "",  # empty — the most common crash
    " ",  # whitespace only
    "{not_a_variable}",  # braces, if you use str.format
    "{{escaped}}",
    "a" * 50_000,  # very long
    "emoji 🙂 and ünïcödé",
    'quotes "double" and \'single\'',
    "line\nbreaks\r\nmixed",
    "<script>alert(1)</script>",  # markup, in case you interpolate into HTML
]


@pytest.mark.parametrize("prompt_path", sorted(PROMPT_DIR.glob("**/*.md")))
@pytest.mark.parametrize("hostile", HOSTILE_INPUTS)
def test_template_renders_with_hostile_input(prompt_path, hostile):
    """Every template survives every hostile input without raising."""
    # template = load_prompt(prompt_path)
    # out = render(template, {v: hostile for v in template.variables})
    # assert isinstance(out, str) and out
    pytest.skip("wire this to your render function")  # >>> CHANGE


@pytest.mark.parametrize("prompt_path", sorted(PROMPT_DIR.glob("**/*.md")))
def test_no_unfilled_placeholders(prompt_path):
    """A rendered prompt must contain no leftover {placeholders}.

    An unfilled placeholder does not raise. It gets sent to the model as
    literal text, and the model does something plausible with it — which is
    the worst outcome, because nothing errors and the output looks fine.
    """
    # out = render(load_prompt(prompt_path), sample_context())
    # leftovers = re.findall(r"\{[a-z_]+\}", out)
    # assert not leftovers, f"unfilled placeholders: {leftovers}"
    pytest.skip("wire this to your render function")  # >>> CHANGE


# ─────────────────────────────────────────────────────────────────────────────
# 2. TOOL DEFINITIONS ARE VALID SCHEMA
#
# An invalid tool schema does not error. The model simply never calls the tool,
# and you get a quality regression that looks like a prompt problem and takes
# a day to find.
# ─────────────────────────────────────────────────────────────────────────────
@pytest.mark.parametrize("tool_path", sorted(TOOL_DIR.glob("*.json")))
def test_tool_schema_is_valid(tool_path):
    import jsonschema

    tool = json.loads(tool_path.read_text(encoding="utf-8"))

    assert tool.get("name"), f"{tool_path} has no name"
    assert tool.get("description"), (
        f"{tool_path} has no description — the description is how the model "
        f"decides whether to call it, so an empty one silently disables the tool"
    )

    schema = tool.get("input_schema") or tool.get("parameters")
    assert schema, f"{tool_path} has no input schema"

    # Raises if the schema itself is malformed.
    jsonschema.Draft202012Validator.check_schema(schema)

    # Every declared required field must actually exist in properties.
    props = schema.get("properties", {})
    for req in schema.get("required", []):
        assert req in props, f"{tool_path}: '{req}' is required but not defined"


# ─────────────────────────────────────────────────────────────────────────────
# 3. THE PARSER SURVIVES REAL OUTPUT — including the messy shapes
#
# Models wrap JSON in prose. They wrap it in fences. They emit a trailing
# comma. Your parser meets all of these in week one.
# ─────────────────────────────────────────────────────────────────────────────
MESSY_RESPONSES = [
    '{"label": "billing.refund"}',  # clean
    '```json\n{"label": "billing.refund"}\n```',  # fenced
    'Sure! Here is the result:\n\n{"label": "billing.refund"}',  # preamble
    '{"label": "billing.refund"}\n\nLet me know if you need more.',  # postamble
    '{"label": "billing.refund",}',  # trailing comma
    "{'label': 'billing.refund'}",  # single quotes
]


@pytest.mark.parametrize("raw", MESSY_RESPONSES)
def test_parser_handles_messy_output(raw):
    """The parser either extracts the value or raises a TYPED error.

    What it must never do is return something subtly wrong. A parser that
    silently returns None on unexpected input turns a parse failure into a
    quality regression you will attribute to the model.
    """
    # try:
    #     result = parse_response(raw)
    #     assert result.label == "billing.refund"
    # except ParseError:
    #     pass  # explicit failure is fine; silent wrongness is not
    pytest.skip("wire this to your parser")  # >>> CHANGE


# ─────────────────────────────────────────────────────────────────────────────
# 4. THE CONTEXT FITS
#
# A prompt that fits in dev and overflows once retrieval is included is a
# production 400, not a quality problem. Measure the WORST case: max retrieved
# chunks, longest system prompt, full tool definitions.
# ─────────────────────────────────────────────────────────────────────────────
def test_worst_case_context_fits():
    # tokens = count_tokens(
    #     system_prompt()
    #     + render(load_prompt("main.md"), max_context_fixture())
    #     + json.dumps(TOOL_DEFINITIONS)
    # )
    # assert tokens < MAX_INPUT_TOKENS, (
    #     f"worst-case input is {tokens} tokens, over the {MAX_INPUT_TOKENS} budget. "
    #     f"This fails in production the first time retrieval returns a full page."
    # )
    pytest.skip("wire this to your tokeniser")  # >>> CHANGE
