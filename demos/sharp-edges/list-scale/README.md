# Sharp edge 3 — list scale: 500 resources vs 1 resource with 500 items

Same data, two shapes:

- `per-item/` — one `cloudflare_list` + **500 `cloudflare_list_item`
  resources**. Every plan refreshes 500 objects; every state operation
  carries 500 entries; adding item 501 diffs a 500-element resource graph.
- `bulk/` — one `cloudflare_list` with **an `items` collection of 500**.
  One object to refresh; adding an item is one in-place update.

Run `scripts/demo-32-list.sh` — it applies both shapes, times `terraform
plan` for each with a warm provider, prints the numbers (record them in the
runbook — they are the argument), then destroys both lists.

**The trade-off being taught:** per-item resources give per-item ownership
(different teams/modules can contribute items) at a brutal refresh cost;
the collection shape is fast but the whole list has ONE owner (see Topics
9/10 — same singleton story at a different altitude). At ~500 items the
choice makes itself.

**prevent_destroy note:** the bulk list carries `prevent_destroy = true` as
the lab's example of protecting expensive-to-recreate resources — the demo
script flips it off via a targeted var only for its own teardown.

**Reset:** the script destroys everything it created (both lists are
`lab-`-prefixed).
