# Module `zone-baseline`

Reference module for Topics 7 & 9: thin typed interface, allow-listed
settings override door, outputs-as-contract.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_zone_setting.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone_setting) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_zones"></a> [zones](#input\_zones) | Map of zones this module manages. Key = short zone alias (used in outputs).<br/>Every DNS record created lives under `<subdomain>.<zone_name>` and its key<br/>must carry the `lab-` prefix — this is the lab's safety contract. | <pre>map(object({<br/>    zone_id   = string<br/>    zone_name = string<br/>    subdomain = optional(string, "lab")<br/><br/>    # Records keyed by their lab-prefixed leaf name, e.g. "lab-app".<br/>    records = optional(map(object({<br/>      type    = string<br/>      content = string<br/>      ttl     = optional(number, 1) # 1 = automatic<br/>      proxied = optional(bool, false)<br/>      comment = optional(string)<br/>    })), {})<br/><br/>    # Topic 9 — the override door: only keys on the allow-list may appear.<br/>    settings_overrides = optional(map(string), {})<br/><br/>    # Nested optional object with {} default (Topic 7 requirement): callers<br/>    # can omit it entirely and still get well-defined metadata.<br/>    metadata = optional(object({<br/>      owner       = optional(string, "platform-team")<br/>      cost_center = optional(string, "lab")<br/>    }), {})<br/><br/>    # ADDED IN v0.2.0 (optional => existing callers unaffected): set false for<br/>    # consumers that create records but must NOT adopt settings ownership —<br/>    # settings are a singleton and exactly one root owns them (Topic 9).<br/>    # Contract tests (Topic 24 tier two) are the canonical false-consumer.<br/>    manage_settings = optional(bool, true)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_record_fqdns"></a> [record\_fqdns](#output\_record\_fqdns) | Map of '<zone alias>/<record key>' => fully-qualified record name. This is the computed truth of where every lab record lives. |
| <a name="output_settings_applied"></a> [settings\_applied](#output\_settings\_applied) | Map of '<zone alias>/<setting>' => value actually applied (baseline merged with allow-listed overrides). Lets consumers assert the effective policy without knowing the merge rules. |
| <a name="output_zone_ids"></a> [zone\_ids](#output\_zone\_ids) | Map of zone alias => zone id, for downstream modules that must target the same zones. |
<!-- END_TF_DOCS -->
