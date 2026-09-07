# Prompt inventory — the brownfield adoption worksheet

Fill this in **before** improving anything. The whole point of the exercise is
to establish what you have and what it currently does, so that later you can
prove what a change moved.

## Step 1 — find them

Prompts hide. Start here, then read the results rather than trusting the grep:

```bash
# string literals that look like instructions
grep -rn --include=*.py --include=*.ts --include=*.js \
  -iE '"(you are|your task|act as|respond (with|in)|answer the)' .

# common prompt-ish variable names
grep -rn -iE '\b(system_prompt|SYSTEM_PROMPT|prompt_template|instructions)\s*=' .

# f-strings and template literals spanning lines
grep -rn -E '(f"""|f\x27\x27\x27|`)' . | grep -iE 'you are|task|assistant'
```

Then check the places grep cannot reach: config tables in a database, feature
flags, an admin UI, a notebook, someone's Slack message.

## Step 2 — rank by blast radius

Traffic × consequence. Do not start with the ugliest one; start with the one
that would hurt most if it broke.

| id | where it lives | calls/day | consequence if wrong | model | pinned? | has eval? | owner |
|---|---|---:|---|---|---|---|---|
| `ticket-classify` | `api/tickets.py:212` | 10,400 | misrouted ticket, SLA breach | *(alias)* | **no** | no | support-eng |
| `refund-explain` | `api/billing.py:88` | 1,200 | wrong refund policy stated to customer | *(alias)* | **no** | no | billing |
| `digest-format` | `jobs/digest.py:40` | 3 | ugly internal email | *(alias)* | no | no | — |

Two things usually fall out of this table immediately:

- **Nothing is pinned.** That is the cheapest fix available and it is a
  one-line change per prompt. Do it before anything else.
- **The prompt everyone complains about is not the one carrying the risk.**
  `digest-format` is ugly and runs three times a day. `ticket-classify` is
  fine-looking and runs ten thousand times.

## Step 3 — extract, do not improve

Move each prompt to a versioned file. Application code references it by id.

```
prompts/
  ticket-classify/
    v1.md          <- byte-identical to what production runs today
    meta.yaml      <- model pin, decoding params, owner, last-reviewed
```

**Change nothing about the text.** This step must be behaviour-neutral, and it
must be reviewable as behaviour-neutral — a reviewer should be able to confirm
the string is identical.

If you improve while extracting, you lose the ability to attribute anything
that happens next.

## Step 4 — capture the baseline

Sample real production inputs. Record what the current system does with them.
That recording is your golden set.

```bash
python eval/capture_baseline.py \
  --prompt-id ticket-classify \
  --sample-from prod-logs --n 200 \
  --out eval/baseline/ticket-classify.json
```

**Include the outputs you think are wrong.** You are not recording what the
system *should* do. You are recording what it *does*, so that when you change
it you can see exactly what moved.

## Step 5 — the gate

Your eval harness, running the extracted prompt, must reproduce production
behaviour on that sample.

```bash
python eval/run.py --evalset eval/baseline/ticket-classify.json \
                   --model "$PINNED_MODEL" --samples 200 \
                   --require-reproduction 0.98
```

If it does not reproduce, **your harness is wrong, not the prompt.** Check in
this order — it is roughly the frequency order:

1. system message missing or different
2. temperature / top_p / max_tokens differ from production
3. retrieval config differs (different index, different k, different reranker)
4. tool definitions differ
5. the model is a different snapshot than production actually serves

Only once it reproduces should anyone edit a word. This is the exact analogue
of `plan == No changes` before you refactor a Terraform estate: until the
baseline holds, you have two descriptions of one system and no way to tell
which is true.

## Step 6 — now you may improve

With a frozen baseline and a reproducing harness, every subsequent change gets
a number. That is the whole payoff, and it is why the previous five steps are
worth doing in order.
