# R-09 — Contracts & Balance (Work Order)

**Status: DESIGN APPROVED. Slice 1 IMPLEMENTED + verified, incl. the accept/
reload re-evaluation hardening (source smoke 394/394 ×2, 0 skipped; exported
388/388 + 6 skipped, 2026-07-24). Slices 2–3 NOT STARTED.**

This document is the row-level authority for R-09. Slice 1 (contract foundation)
is implemented per the design below; slices 2–3 remain design-only.
`docs/HANDOFF.md`,
`docs/FABLE_TASK_QUEUE.md`, and `docs/WORK_ORDER_RELEASE_FOUNDATIONS.md` (R-09
row) point here.

Operator approved R-09 as the next code-lane arc with the decisions and
revisions recorded below. R-06 (ownership decomposition) remains deferred and
must not be pulled forward unless R-09 exposes a concrete ownership problem
that cannot be resolved safely in the current architecture.

---

## 1. Design spine (the rules everything derives from)

1. **Observe live authoritative state; never copy it.** The save persists
   only **lifecycle status** and, *exclusively* for actions that leave no
   reconstructable trace, a small **event-progress accumulator keyed by a
   stable objective id**. Resource counts, station state, day number, and
   threat are read live at evaluation time. No shadow stockpile, no duplicate
   settlement counters.
2. **Rewards route only through existing player-facing grant authorities.**
   No new item/stat pathway is created for contract convenience.
3. **Narrow vocabulary, not a quest engine.** One objective and one reward per
   contract in Slice 1. No expression tree, no generic condition DSL.

Objectives split into two persistence classes:

| Class | Meaning | Persisted |
|---|---|---|
| **Reconstructable** | Progress is a pure function of current world state | Only the latched lifecycle status |
| **Event-only** | The action leaves no queryable trace (a kill, a craft) | One integer accumulator per **objective id** |

## 2. Operator decisions (locked)

- **Stockpile-grant rewards are out of Slice 1 and Slice 2.** Rewards are
  granted only through an existing player-facing authority (player inventory in
  Slice 1; player XP added in Slice 2). Direct settlement-stock rewards are
  reconsidered only later, and only when a contract's fiction represents an
  **external delivery or sponsor** rather than the settlement effectively
  rewarding itself. **Do not add `town_hall.receive_stock()` for contract
  convenience.**
- **Save version bumps `0.5 → 0.6`.** Accept `0.6`, `0.5`, `0.4`. A missing
  contracts key migrates to an **empty collection**. Named smoke covers the
  `0.5 → 0.6` boundary and claimed-state persistence.
- **First representative contract is `stockpile_at_least`.** Semantic:
  **"have/store at least 20 stone in the Town Hall stockpile"** — not "gather
  20 stone." It exercises live-authority observation, threshold completion,
  completion latching, save/reload, and post-completion stock reduction. Its
  reward is a small **non-circular** player-inventory item already in the
  registry (`torch` ×3 — the torch recipe is wood+coal, so stone→torch is not
  a wash).

## 3. Lifecycle (simplified)

`available → active → completed → claimed`

`accepted` and `active` are **not** separate states — they had no distinct
mechanics, so acceptance is simply the `available → active` transition.

- **available** — defined in `data/contracts.json`, no persisted record yet.
- **active** — accepted; objective is being observed. Event-only accumulators
  increment **only while active**.
- **completed** — objective threshold first reached; **latches** (see §4).
- **claimed** — reward granted exactly once (see §5); terminal.

`failed` / `expired` are **not** in Slice 1 (expiry is omitted entirely; see
§7). They arrive with Slice 2 only when implemented and tested.

Persistence is minimal: the world save stores a record only for contracts that
have advanced beyond `available` (i.e. active/completed/claimed). A defined
contract with no persisted record is `available`. On load the runtime merges
definitions with persisted records.

## 4. `stockpile_at_least` semantics (Slice 1, explicit)

- **Observed authority:** `town_hall.stockpile[item]` read live
  (`town_hall.gd:20`); completion test is `stockpile.get(item,0) >= count`.
- **Completion:** the contract completes the **first time** the live threshold
  is reached while `active`.
- **Latching:** once `completed`, status never reverts. Spending the stone
  below the threshold afterward leaves the contract `completed`. This is why we
  persist the latched *status* rather than a copy of the stock count — the
  count stays authoritative and live; only the lifecycle fact is stored.

## 5. Claiming is transactional

Claim is an **explicit** step (Slice 1: a model method the smoke drives;
Slice 2: a contracts-panel button). The claim is all-or-nothing:

- If the reward can be granted in full, the reward is applied through the
  existing authority **and** status becomes `claimed`.
- Otherwise **neither** occurs: status stays `completed`, no partial reward is
  granted, and the claim is safely retryable.

**Inventory cannot accept the reward:** the claim path first checks a
`can_accept(reward)` predicate against the player inventory. If it returns
false, claim is a no-op that leaves status `completed`, surfaces a player-facing
message (`hud.log_event` / `player_event`), and remains retryable. (Player
inventory is currently uncapped, so in Slice 1 `can_accept` is always true; the
transactional structure is in place for a future capacity model and is what the
no-double-pay test exercises.)

**No double-pay:** the reward fires only on the `completed → claimed`
transition, guarded by the persisted status. Claiming an already-`claimed`
contract is a no-op. Reloading after claim restores status `claimed` and never
re-grants.

## 6. Event-only objective rules (Slice 2)

- Count **only events that occur after activation**. Events before `active` or
  after `completed` do not accumulate.
- The accumulator **freezes at completion** and does not resume.
- Persisted progress is **restored** on load, never **replayed** — the runtime
  does not re-run historical events; it reads the stored integer and continues
  from there for events that arrive after load.
- Progress is persisted **by stable objective id** (`objective.oid`), never by
  objective type, so two contracts observing the same event type never collide.

## 7. Data schema

**`data/contracts.json`** (definition; validated). No expiry field in Slice 1.

```json
{
  "contracts": [
    {
      "id": "stone_reserve",
      "title": "Stone Reserve",
      "description": "Store at least 20 stone in the Town Hall stockpile.",
      "objective": {
        "oid": "stone_reserve.stock",
        "type": "stockpile_at_least",
        "item": "stone",
        "count": 20
      },
      "reward": { "type": "grant_items", "items": { "torch": 3 } }
    }
  ]
}
```

**Persisted state — `world_save.state.contracts`** (world-owned, alongside
`stations_built` / `subjects` / `item_drops`; contracts pressure the
settlement, which is world-owned, not the roaming character):

```json
{ "id": "stone_reserve", "status": "active" }
```

Reconstructable objectives persist no `progress` (recomputed live). Event-only
objectives (Slice 2) add `"progress": { "<objective_oid>": <int> }`. Expiry
fields are added only when Slice 2 implements and tests them.

## 8. Authority map

**Objective vocabulary** (1 type in Slice 1; 5 total by Slice 2):

| Objective type | Observed authority | file:line | Class | Slice |
|---|---|---|---|---|
| `stockpile_at_least{item,count}` | `town_hall.stockpile[item]` (live read) | town_hall.gd:20 | Reconstructable | 1 |
| `station_built{station}` | `town_hall.station_built(id)` | town_hall.gd:119 | Reconstructable | 2 |
| `survive_to_day{day}` | `game_root.day_count` | game_root.gd:64 | Reconstructable | 2 |
| `defeat_enemies{count}` | `simple_threat.died` → `_on_threat_died` | simple_threat.gd:8 / game_root.gd:1009 | Event-only | 2 |
| `craft_items{recipe,count}` | `player.crafted(recipe_id)` → `_on_player_crafted` | player.gd:11 / game_root.gd:1160 | Event-only | 2 |

**Reward vocabulary** (`grant_items` only in Slice 1; `grant_xp` added Slice 2):

| Reward type | Grant authority (existing) | file:line | Slice |
|---|---|---|---|
| `grant_items{items:{id:count}}` | `inventory.add_many(dict)` (player inventory) | inventory.gd:18 | 1 |
| `grant_xp{event_id}` | `game_root.award_xp(event_id)` (references `player_xp.json`) | game_root.gd:1361 | 2 |
| *(feedback only)* | `hud.log_event` / `player_event` | game_root.gd:1172 / player.gd:13 | 1 |

`grant_xp` is event-id-based, so a contract's XP reward references a
`contract_reward_*` entry added to `data/progression/player_xp.json`
(data-driven, validator-checked) — granting through the real XP authority
rather than an invented amount path.

## 9. Save-version & migration

- Additive optional `state.contracts` key; absent → empty collection
  (legacy-safe, matches the R-02 default-safe pattern).
- `save_manager.SAVE_VERSION "0.5" → "0.6"`; accepted `["0.6","0.5","0.4"]`.
  No field removed; rides the existing R-02 atomic-write / recover path
  unchanged.

## 10. Validation additions (`validate_repo.py`)

Require + parse `data/contracts.json`; per contract fail **clearly** on:
duplicate contract id; duplicate `objective.oid`; `objective.type` /
`reward.type` outside the allowed vocab; referenced `item` / `station` /
`recipe` ids absent from their registries; `reward.event_id` absent from
`player_xp.json`; non-positive counts; more than one objective or reward per
contract (Slice-1 narrowness enforced structurally).

## 11. Slice matrix

| Slice | Scope | New vocab | Deliverables |
|---|---|---|---|
| **R-09.1 — Foundation** | Definitions + validation; persistent lifecycle `available→active→completed→claimed`; explicit `stockpile_at_least` semantics with latching; transactional claim + `can_accept`; **one** contract (`stone_reserve`); no-double-pay; save `0.5→0.6` migration. Headless (no UI). | `stockpile_at_least` / `grant_items` | `contract_model.gd`, `contracts.json`, validator block, save wiring + version bump, focused smoke |
| **R-09.2 — Objective & reward expansion** | Add the 4 remaining objective types + `grant_xp`; event-only accumulator rules (§6); contracts panel (accept/claim/status); multi-contract + reload-edge coverage; optional expiry (adds `expired`/`failed` + expiry schema, implemented **and tested** together). | +`station_built`, `survive_to_day`, `defeat_enemies`, `craft_items` / +`grant_xp` | UI panel, event-progress wiring, expanded smoke |
| **R-09.3 — Deterministic balance report** | Fixed-seed **named scenario** + scripted policy over N in-game days; reports inflow/outflow, contract completion latency, pressure timeseries, reward value, bottlenecks; JSON + markdown; **no auto-mutation**. | (none — reporting) | balance runner, report artifacts, determinism smoke, documented baseline + proposed tuning for separate review |

## 12. Balance report design (Slice 3)

A headless fixed-seed runner (Godot `COHERONIA_BALANCE=1` scene or a
`scripts/ci/balance_report.py` driver reusing the smoke harness) plays a
**named, scripted deterministic policy** for N in-game days against a fixed
`world_seed` + fixed RNG. It records per-day: resource inflow/outflow, contract
completion latency (activation-day → completion-day), pressure timeseries
(coherence / resilience / load / `current_threat_severity`), reward value
dispensed, and bottleneck flags (contracts unmet within a window).

- **The report identifies its scenario and scripted policy.** Results are
  described as **deterministic evidence under that policy**, not proof of
  global balance.
- Emits `build/balance_report.json` + a markdown summary.
- **Changes no balance values** — it proposes tuning deltas in the markdown for
  separate human review.
- Determinism is asserted by comparing **normalized report payloads** (metadata
  and timestamps stripped) across two runs — not by requiring byte-identical
  files.

## 13. Acceptance tests (smoke) mapped to constraints

| Check | Proves | Slice |
|---|---|---|
| `r09_contract_definitions_valid` | contracts.json parses; validator rejects bad ids/types/refs and >1 objective/reward | 1 |
| `r09_lifecycle_available_active_completed_claimed` | accept → store ≥20 stone → completes → claim grants `torch`×3 | 1 |
| `r09_stockpile_at_least_first_reach` | completes on first threshold crossing while active | 1 |
| `r09_completion_latches` | complete, then spend stone below target → stays completed | 1 |
| `r09_claim_transactional_no_double_pay` | claim twice → granted once; claim of already-claimed is a no-op | 1 |
| `r09_claim_inventory_cannot_accept` | when `can_accept` is false, claim is a no-op leaving `completed`, retryable | 1 |
| `r09_save_migration_0_5_to_0_6` | 0.5 world (no contracts key) loads as empty; re-saves as 0.6 | 1 |
| `r09_claimed_state_persists` | active/completed/claimed survive save/load; reload after claim never re-grants | 1 |
| `r09_objective_<type>` (×4) | each Slice-2 objective progresses & completes from its authority | 2 |
| `r09_event_progress_after_activation_only` | event-only counts only post-activation events, freezes at completion | 2 |
| `r09_event_progress_persists_no_replay` | accumulator restored on load, not replayed; keyed by objective id | 2 |
| `r09_reward_routes_through_authority` | `grant_items`→inventory, `grant_xp`→award_xp only | 2 |
| `r09_multi_contract_independent` | two contracts on the same event type do not collide | 2 |
| `r09_balance_report_deterministic` | two fixed-seed runs produce identical **normalized** payloads | 3 |
| `r09_balance_report_no_mutation` | report run alters no data/balance values | 3 |

## 14. Constraint checklist

Real-state observation ✓ · no shadow inventories/counters ✓ · idempotent,
no double-pay ✓ · full lifecycle persisted ✓ · reload-around-completion safe ✓
· reconstruct-where-practical / persist-events-only-when-necessary ✓ · progress
by stable objective id ✓ · data-driven + validated ✓ · clear validation
failures ✓ · one objective + one reward per contract (narrow, not a quest
engine) ✓ · no expiry in Slice 1 ✓ · cross-system pressure not arbitrary
counts ✓ · lifecycle before economy rebalance ✓ · scenario/policy-scoped
deterministic report, normalized comparison, evidence-not-mutation ✓ ·
backward-compatible saves (0.5/0.4 accepted, missing key → empty) ✓ · no
`town_hall.receive_stock()` for convenience ✓ · settlement-stock rewards
deferred to an external-delivery fiction ✓ · docs/README/wiki/smoke-counts
updated only **after** CI ✓ · R-06 not pulled forward ✓.

## 15. Closeout standard (every slice)

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (if data/assets touched)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
   (source), plus the exported-build run per the R-04 CI verifier
5. Update this work order's slice state, `docs/HANDOFF.md`, and the queue with
   actual pass/fail evidence — never aspirational numbers
6. Commit only when the operator gates it; never push unless told
