# Static Pack Reference

Packs are labels and human review aids only. They are not bundles to install or load, do not require every member, do not authorize members, do not override quarantine, do not prove availability, do not expand mission permission, and are not runtime resolver input.

| Pack | Reference members | Purpose |
|---|---:|---|
| TSF_DEV_CORE | 4 | Potential development-core metadata review |
| TSF_RESEARCH_ARTIFACT | 8 | Potential public-research and artifact metadata review |
| TSF_PRODUCT_DESIGN | 4 | Project-specific product/design metadata review |
| TSF_GAME_STUDIO | 2 | Project-specific browser-game metadata review |
| TSF_SENSITIVE_CONNECTORS | 13 | Sensitivity classification pool, not a bundle to load |

Every pack declares:

```text
auto_select: false
auto_install: false
auto_enable: false
auto_load: false
runtime_enforced: false
approval_granted: false
```

`TSF_SENSITIVE_CONNECTORS` includes Google Drive only where connected-account access would be required. Its membership is a cautionary classification pool and never a loading instruction.
