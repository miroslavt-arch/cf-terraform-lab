#!/usr/bin/env python3
"""Topic 27 — drift report with author attribution.

Input:  a `terraform show -json` rendering of a drift plan (refresh-only).
Output: a markdown report naming each drifted resource AND the human who
        touched it, correlated from the Cloudflare audit log API.

Env:  CLOUDFLARE_AUDIT_TOKEN  (Account: audit logs read)
      CF_ACCOUNT_ID
Usage: python scripts/drift_report.py drift.json [--hours 24]
"""

import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

API = "https://api.cloudflare.com/client/v4"


def audit_events(account_id: str, token: str, hours: int):
    """Pull recent audit events (both v1 and v2 endpoints; first that works)."""
    since = (datetime.now(timezone.utc) - timedelta(hours=hours)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    endpoints = [
        f"{API}/accounts/{account_id}/logs/audit?since={urllib.parse.quote(since)}&limit=250",
        f"{API}/accounts/{account_id}/audit_logs?since={urllib.parse.quote(since)}&per_page=250",
    ]
    for url in endpoints:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = json.load(resp)
            result = body.get("result") or []
            if result:
                return result
        except Exception as exc:  # noqa: BLE001 - keep the demo resilient
            print(f"<!-- audit endpoint failed: {url.split('?')[0]} : {exc} -->")
    return []


def normalize(ev):
    """Flatten v1/v2 audit event shapes into one record."""
    actor = ev.get("actor") or {}
    action = ev.get("action") or {}
    resource = ev.get("resource") or {}
    return {
        "when": ev.get("when") or ev.get("occurred_at") or "?",
        "actor": actor.get("email") or actor.get("id") or "unknown-actor",
        "type": actor.get("type", "?"),
        "action": action.get("type") or action.get("description") or "?",
        "resource": resource.get("type") or "?",
        "resource_id": resource.get("id") or "?",
        "raw": ev,
    }


def drifted_resources(plan):
    out = []
    for rc in plan.get("resource_changes", []):
        change = rc.get("change", {})
        actions = change.get("actions", [])
        if actions and actions != ["no-op"]:
            out.append(
                {
                    "address": rc.get("address"),
                    "actions": actions,
                    "name": (change.get("before") or {}).get("name")
                    or (change.get("after") or {}).get("name")
                    or "",
                    "id": (change.get("before") or {}).get("id") or "",
                }
            )
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: drift_report.py <plan.json> [--hours N]")
    hours = 24
    if "--hours" in sys.argv:
        hours = int(sys.argv[sys.argv.index("--hours") + 1])

    with open(sys.argv[1], encoding="utf-8") as fh:
        plan = json.load(fh)

    drifted = drifted_resources(plan)
    print("## Drift report\n")
    if not drifted:
        print("No drift — the estate matches the code. ✅")
        return

    print(f"**{len(drifted)} resource(s) drifted from code truth:**\n")
    for d in drifted:
        print(f"- `{d['address']}` — actions: {', '.join(d['actions'])}")

    token = os.environ.get("CLOUDFLARE_AUDIT_TOKEN", "")
    account = os.environ.get("CF_ACCOUNT_ID", "")
    if not token or not account:
        print("\n_(no CLOUDFLARE_AUDIT_TOKEN / CF_ACCOUNT_ID — cannot attribute)_")
        return

    events = [normalize(e) for e in audit_events(account, token, hours)]
    print(f"\n### Who touched what (last {hours}h of audit log)\n")
    if not events:
        print("_audit log returned no events for the window_")
        return

    print("| when | actor | action | resource | id |")
    print("|---|---|---|---|---|")
    attributed = False
    ids = {d["id"] for d in drifted if d["id"]}
    for ev in events:
        # correlate: the event's resource id appears among drifted ids, or the
        # raw event mentions any drifted resource id/name
        blob = json.dumps(ev["raw"])
        hit = ev["resource_id"] in ids or any(i and i in blob for i in ids)
        mark = " ⬅ **matches drifted resource**" if hit else ""
        if hit:
            attributed = True
        print(
            f"| {ev['when']} | {ev['actor']} | {ev['action']} | "
            f"{ev['resource']} | {ev['resource_id']}{mark} |"
        )
    if attributed:
        print("\n**Attribution: the marked actor made the out-of-band change.**")
    else:
        print("\n_no direct id match — inspect the events above manually_")


if __name__ == "__main__":
    main()
