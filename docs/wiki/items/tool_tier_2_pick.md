# Tool Tier 2 Pick

Generated: 2026-07-21

> `Item` page. Current status: `internal`.

| Field | Value |
|---|---|
| ID | `tool_tier_2_pick` |
| Page type | Item |
| Current status | internal |
| Storage | internal token |
| Player-facing? | No |
| Status explanation | This token is an internal recipe bridge. The player-facing result route upgrades the live pick state to `pick_forged`. |
| Image path | No player-facing image needed. |
| Fallback / placeholder | No player-facing image surface is required for this internal token. |

## Summary

This token exists to bridge the Town Hall pick upgrade route. The real gameplay result is the forged pick equipment state.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Recipe output | Basic Pick Upgrade | 1x at [Town Hall](../stations/town_hall.md) | Output route: inventory. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- The real player-facing result route resolves to `pick_forged`.
