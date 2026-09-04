# ─────────────────────────────────────────────────────────────────────────────
# EVAL RELEASE GUARD — the AI equivalent of the destroy guard.
#
# Input:  the eval report JSON produced by your PR pipeline.
# Output: deny messages if the release must not ship.
#
#   conftest test --policy policy --namespace eval_release_guard evalreport.json
#
# WHY POLICY AND NOT A REVIEWER'S JUDGEMENT
#   "Accuracy went up but latency went up too — is that OK?" is a question that
#   gets answered differently at 10am on Monday and 6pm on Friday. Write the
#   answer down once, in a form that exits non-zero.
#
# HOW TO CALIBRATE
#   Do NOT copy these thresholds. Measure your own noise floor first: run the
#   same eval against the same model pin, unchanged, several times, and see how
#   much the score moves on its own. Set the tolerance ABOVE that.
#
#   A guard tuned tighter than your noise blocks good releases and gets
#   disabled within a month.
# ─────────────────────────────────────────────────────────────────────────────
package eval_release_guard

import rego.v1

# ── CONFIGURE ME ─────────────────────────────────────────────────────────────
# Quality may regress by at most this much (percentage points) versus baseline.
# Non-zero on purpose: demanding zero regression on a statistical measure means
# blocking on noise.
max_quality_regression_pp := 2.0

# Hard ceilings. These are product decisions, not eval decisions.
max_p95_latency_seconds := 3.0

max_cost_per_1k_usd := 0.75

# Cost may rise by at most this fraction versus baseline, even under the ceiling.
max_cost_increase_ratio := 0.25

# Minimum samples per case. Below this the interval is too wide to mean anything.
min_samples := 50
# ─────────────────────────────────────────────────────────────────────────────

# ── 1. SAFETY IS PASS/FAIL. No tolerance band, ever. ────────────────────────
deny contains msg if {
	input.safety.passed != input.safety.total
	msg := sprintf(
		"BLOCKED: safety suite %d/%d. Safety cases are pass/fail at 100%% — they do not get a tolerance band, regardless of how good the quality numbers look.",
		[input.safety.passed, input.safety.total],
	)
}

# ── 2. Quality regression beyond the noise floor ────────────────────────────
deny contains msg if {
	some name, metric in input.quality
	delta_pp := (metric.baseline - metric.value) * 100
	delta_pp > max_quality_regression_pp
	msg := sprintf(
		"BLOCKED: '%s' regressed %.1fpp (%.3f -> %.3f), over the %.1fpp tolerance. If this regression is intended, change the baseline in a reviewable commit rather than widening the threshold.",
		[name, delta_pp, metric.baseline, metric.value, max_quality_regression_pp],
	)
}

# ── 3. Not enough samples to conclude anything ──────────────────────────────
# A single sample per case is an anecdote. This is the check that stops someone
# "fixing" a slow eval by dropping n to 1.
deny contains msg if {
	input.samples < min_samples
	msg := sprintf(
		"BLOCKED: only %d samples. Below %d the confidence interval is too wide to support a release decision — a green result here means nothing.",
		[input.samples, min_samples],
	)
}

# ── 4. Latency ceiling ──────────────────────────────────────────────────────
deny contains msg if {
	input.performance.p95_latency_s > max_p95_latency_seconds
	msg := sprintf(
		"BLOCKED: p95 latency %.2fs exceeds the %.2fs ceiling. Quality improvements do not buy latency budget.",
		[input.performance.p95_latency_s, max_p95_latency_seconds],
	)
}

# ── 5. Cost ceiling and cost growth ─────────────────────────────────────────
deny contains msg if {
	input.performance.cost_per_1k_usd > max_cost_per_1k_usd
	msg := sprintf(
		"BLOCKED: $%.3f per 1k exceeds the $%.3f ceiling.",
		[input.performance.cost_per_1k_usd, max_cost_per_1k_usd],
	)
}

deny contains msg if {
	base := input.performance.baseline_cost_per_1k_usd
	base > 0
	ratio := (input.performance.cost_per_1k_usd - base) / base
	ratio > max_cost_increase_ratio
	msg := sprintf(
		"BLOCKED: cost rose %.0f%% (from $%.3f to $%.3f), over the %.0f%% limit. Still under the ceiling, but a jump this size usually means the prompt grew — check whether the extra context is actually earning its place.",
		[ratio * 100, base, input.performance.cost_per_1k_usd, max_cost_increase_ratio * 100],
	)
}

# ── 6. THE BUNDLE MUST MATCH WHAT WAS MEASURED ──────────────────────────────
# This is the "Saved plan is stale" equivalent, and it is the most important
# rule here. The report records a hash of the whole bundle — prompt, model pin,
# decoding params, tool definitions, retrieval config. If the thing about to
# ship hashes differently, it was not the thing that was evaluated.
deny contains msg if {
	input.bundle_hash != input.evaluated_bundle_hash
	msg := sprintf(
		"BLOCKED: bundle hash mismatch. Evaluated %s but about to ship %s. Something changed after the eval ran — re-run it. Shipping an unevaluated bundle is the failure this whole pipeline exists to prevent.",
		[substring(input.evaluated_bundle_hash, 0, 12), substring(input.bundle_hash, 0, 12)],
	)
}

# ── 7. The model must be PINNED, not an alias ───────────────────────────────
# An undated alias points at whatever the provider ships next. Your eval
# measured one thing; production may serve another.
deny contains msg if {
	not regex.match(`-\d{8}$|-\d{4}-\d{2}-\d{2}$`, input.model)
	msg := sprintf(
		"BLOCKED: model '%s' is not a dated snapshot. Aliases move underneath you: the eval measured one model and production may serve another. Pin the dated id.",
		[input.model],
	)
}
