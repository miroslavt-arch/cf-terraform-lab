<!-- Topic 11 — BREAK-GLASS TEMPLATE.
Use for arming/disarming incident_mode ONLY. Pre-approved shape: reviewers
check the boxes, not the diff. Open with:
gh pr create --template break-glass.md -->

## 🚨 Break-glass: incident mode change

**Mode change:** `none` → `elevated | lockdown` (or back)

**Incident ticket / thread:**

**Declared by (on-call):**

### Pre-approved checklist — all boxes or no merge
- [ ] The ONLY change in this PR is `incident_mode` in tfvars / TF_VAR
- [ ] Plan output attached below shows only `enabled` flips on `lab_ir_*` rules
- [ ] No other resource is touched in the plan
- [ ] Reminder workflow will nag until mode returns to `none`

### Plan diff

```
(paste `scripts/arm-killswitch.sh` output here)
```

**Rollback:** re-run `scripts/arm-killswitch.sh none` and merge the revert PR.
