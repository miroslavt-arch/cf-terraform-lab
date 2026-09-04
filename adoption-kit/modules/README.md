# Module patterns

This kit does not ship a module you can drop in — your provider, your naming,
your compliance rules. What it ships is the **shape**, in
[`../examples/variables-with-validation.tf`](../examples/variables-with-validation.tf).

## The five things that make a module a contract

**1. One typed `map(object)` with `optional()` defaults.** Not a dozen loose
variables. Callers pass what they mean; adding a field later is additive rather
than breaking.

**2. Validation blocks carrying YOUR rules.** The type system knows what
Terraform allows. Only you know what your organisation allows. Naming
conventions, bounded sets, allow-lists — all of it belongs here, where it costs
a second to enforce.

**3. Error messages that teach.** Name the allowed set, and say *why*:

> `Record type must be one of A, AAAA, CNAME, TXT, MX. Anything more exotic
> (SRV, CAA, ...) is deliberately out of scope for this module: they need extra
> fields this interface does not model, and silently ignoring those fields is
> worse than refusing.`

A message that only says "invalid input" teaches nobody anything. Writing the
sentence is the work.

**4. Outputs as contract.** Export what callers need to assert on. If your
module has a guarantee — "this root manages no settings" — export the thing
that proves it, so a test can check behaviour rather than reaching inside.

**5. Consume by TAG, never by branch or path.**

```hcl
source = "git::https://github.com/ORG/REPO.git//modules/zones?ref=v1.2.0"
```

A relative path or a branch means your environment changes when somebody else
pushes. A tag makes upgrading a deliberate commit: visible in a diff,
reviewable, revertible. This is the cheapest possible fix for environments
drifting under you, and almost nobody does it.

## Allow-lists, not deny-lists

Every bounded set in your validation should be an allow-list. A deny-list
silently permits everything you did not think of when you wrote it — and the
thing you did not think of is, by definition, the thing that surprises you.

## When to split a module

Split when two callers need genuinely different behaviour and you are about to
add a boolean to switch between them. One or two such flags is fine
(`manage_settings` earns its place because it guards a singleton). Four or five
means you have two modules wearing a trench coat.
