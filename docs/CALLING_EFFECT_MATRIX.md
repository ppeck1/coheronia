# Coheronia — Calling Effect-Support Matrix

_Generated from `data/character_data.json` and `data/progression/perks.json`. This is the authoritative trace of every Calling/Path/skill effect to its state owner/hook, and its implementation status this pass._


**Status totals:** 13 live · 39 staged (hook identified, wiring deferred) · 20 deferred (needs a new mechanism). Total 72 skills + 3 innate.

## Callings & innate effects

The permanent, character-owned identity is stored under the legacy save key `role`; its values are the three Callings. Each Calling's innate effect is automatic.

| Calling | Paths | Innate | Innate effect | Status |
|---|---|---|---|---|
| **Oathbound** | Warden, Vanguard | Resolve | Damage received from hostile creatures is reduced. This protection becomes stronger during an active settlement threat. | live (Resolve wired in take_damage) |
| **Wayfarer** | Prospector, Trailseeker | Trailcraft | Movement is faster outside settlement bounds, and map-reveal radius is permanently increased. | deferred (movement staged; reveal-radius innate staged — purchased reveal skills are live) |
| **Runewright** | Hearthwright, Resonant | Measured Hand | Player-performed structure repairs restore more structure health, and positive maximum-Attunement bonuses supplied by equipment are amplified. | deferred (repair-amount + equip-attunement staged) |

## Progression contract

- One perk point per player level above 1. Calling gates which two Paths are purchasable; both remain available.
- Tier II opens at **2** skills purchased in the Path; Tier III at **6**; Capstone at **9** non-capstone skills.
- Calling, purchased skills, levels, and perk points are character-owned. No multiclass / respec / starter-item windfall.

## Warden Path — Oathbound

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| tempered_frame | I | **Tempered Frame** | `max_health_bonus` | ✅ live | player.max_health via effects merge (player.gd:264) |
| armored_bearing | I | **Armored Bearing** | `armor_mult` | ✅ live | player.armor_total() scale |
| holdfast | I | **Holdfast** | `hostile_damage_mult_settlement` | ✅ live | player.take_damage(source=enemy) + settlement_bounds |
| guarded_recovery | II | **Guarded Recovery** | `heal_mult_settlement_or_threat` | 🟡 staged | HOOK EXISTS (wiring staged): player heal path (food/regen) + settlement/threat context |
| defensive_presence | II | **Defensive Presence** | `defender_damage_taken_mult` | ⛔ deferred | MISSING: per-citizen damage-taken buff (subjects take no scaled combat damage hook) |
| rally_the_line | II | **Rally the Line** | `defender_damage_mult` | ⛔ deferred | MISSING: per-citizen outgoing-damage buff to Defenders |
| emergency_repairs | II | **Emergency Repairs** | `repair_amount_mult_threat` | 🟡 staged | HOOK EXISTS (wiring staged): game_root repair path + threat context |
| reinforced_position | III | **Reinforced Position** | `structure_damage_taken_mult_threat` | ⛔ deferred | MISSING: per-structure incoming-damage hook (only town-hall single HP exists) |
| stand_together | III | **Stand Together** | `resolve_per_defender` | ⛔ deferred | MISSING: nearby-Defender count feeding the live Resolve multiplier (proximity query coarse) |
| last_watch | III | **Last Watch** | `hostile_damage_mult_lowhp_threat` | ✅ live | player.take_damage(source=enemy) + health fraction + threat context |
| unbroken | III | **Unbroken** | `survive_once_per_threat` | ⛔ deferred | MISSING: per-threat-instance one-shot flag + lethal-hit intercept |
| guardian_of_the_hearth | Cap | **Guardian of the Hearth** | `capstone_warden` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported Warden components (defense + emergency repairs) while in-settlement during a threat; citizen/structure components deferred |

## Vanguard Path — Oathbound

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| weapon_discipline | I | **Weapon Discipline** | `weapon_damage_mult` | 🟡 staged | HOOK EXISTS (wiring staged): player._try_hit_threat weapon damage |
| decisive_strikes | I | **Decisive Strikes** | `first_hit_bonus` | ⛔ deferred | MISSING: per-enemy undamaged/first-hit state tracking |
| relentless | I | **Relentless** | `heal_on_xp_kill` | ✅ live | enemy-defeat XP award hook |
| momentum | II | **Momentum** | `kill_momentum` | ⛔ deferred | MISSING: kill-buff timer + movement responsiveness / weapon recovery stat |
| executioner | II | **Executioner** | `weapon_damage_mult_low_enemy` | ⛔ deferred | MISSING: target enemy hp fraction at weapon-hit resolution |
| threat_hunter | II | **Threat Hunter** | `weapon_damage_mult_threat` | 🟡 staged | HOOK EXISTS (wiring staged): player._try_hit_threat + active-threat context |
| counterforce | II | **Counterforce** | `counter_bonus` | ⛔ deferred | MISSING: recently-hurt combat-state timer feeding next attack |
| steel_rhythm | III | **Steel Rhythm** | `combo_ramp` | ⛔ deferred | MISSING: same-target consecutive-hit combo tracking |
| breachbreaker | III | **Breachbreaker** | `weapon_damage_mult_vs_attacker` | ⛔ deferred | MISSING: enemy 'currently attacking citizen/structure' target state |
| press_the_line | III | **Press the Line** | `weapon_recovery_mult_threat` | ⛔ deferred | MISSING: player weapon-recovery/attack-cadence stat |
| victorys_breath | III | **Victory's Breath** | `threat_end_restore` | ✅ live | threat-cleared hook restores health + Attunement |
| threatbreaker | Cap | **Threatbreaker** | `capstone_vanguard` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported Vanguard components (threat weapon damage); per-defeat refresh ramp deferred |

## Prospector Path — Wayfarer

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| stonewise | I | **Stonewise** | `mining_speed` | ✅ live | player.effective_mine_speed (perk_mine_speed_mult) |
| practiced_swing | I | **Practiced Swing** | `mining_speed` | ✅ live | player.effective_mine_speed (recovery folds into mine rate) |
| deep_surveying | I | **Deep Surveying** | `reveal_radius_underground` | ✅ live | game_root._scout_reveal_radius + underground context |
| resonant_survey | II | **Resonant Survey** | `pulse_radius_mult_underground` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse radius + underground context |
| clean_extraction | II | **Clean Extraction** | `ore_extra_drop_chance` | 🟡 staged | HOOK EXISTS (wiring staged): mining drop resolution (ore family) |
| stone_economy | II | **Stone Economy** | `stone_extra_drop_chance` | 🟡 staged | HOOK EXISTS (wiring staged): mining drop resolution (natural stone only) |
| long_pick | II | **Long Pick** | `mining_reach_bonus` | 🟡 staged | HOOK EXISTS (wiring staged): player mining reach (scoped, not build/pickup/weapon) |
| tunnel_hardened | III | **Tunnel Hardened** | `hazard_damage_mult_underground` | ✅ live | player.take_damage(source=hazard) + underground context |
| deep_reserves | III | **Deep Reserves** | `pulse_cost_mult_underground` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse cost + underground context |
| deep_lantern | III | **Deep Lantern** | `pulse_duration_mult_underground` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse duration + underground context |
| deep_stride | III | **Deep Stride** | `move_speed_mult_underground_wild` | 🟡 staged | HOOK EXISTS (wiring staged): player move speed + underground/outside-settlement context |
| master_of_the_deep | Cap | **Master of the Deep** | `capstone_prospector` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported underground components (mining, reach, reveal, pulse, movement, hazard) |

## Trailseeker Path — Wayfarer

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| wildhand | I | **Wildhand** | `harvest_speed` | 🟡 staged | HOOK EXISTS (wiring staged): player harvest/chop rate (axe/plant-preferred blocks) |
| farwalker | I | **Farwalker** | `move_speed_mult_wild` | 🟡 staged | HOOK EXISTS (wiring staged): player move speed + outside-settlement context |
| broad_horizon | I | **Broad Horizon** | `reveal_radius_surface` | ✅ live | game_root._scout_reveal_radius + surface context |
| seedkeeper | II | **Seedkeeper** | `seed_return_chance_mult` | 🟡 staged | HOOK EXISTS (wiring staged): seed-return roll on harvest (seed_pouch loop) |
| woodwise | II | **Woodwise** | `wood_extra_drop_chance` | 🟡 staged | HOOK EXISTS (wiring staged): tree-harvest drop resolution |
| foragers_share | II | **Forager's Share** | `plant_extra_drop_chance` | 🟡 staged | HOOK EXISTS (wiring staged): plant/crop harvest drop resolution |
| careful_harvest | II | **Careful Harvest** | `renewable_preserve_chance` | ⛔ deferred | MISSING: per-source exhaustion/regrowth-preservation hook |
| stormwise | III | **Stormwise** | `hazard_damage_mult_surface_wild` | ✅ live | player.take_damage(source=hazard) + surface/outside-settlement context |
| field_sustenance | III | **Field Sustenance** | `heal_mult_food_wild` | 🟡 staged | HOOK EXISTS (wiring staged): player food-heal amount + outside-settlement context |
| sunwise | III | **Sunwise** | `pulse_reveal_radius_surface` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse reveal radius + surface context |
| familiar_ground | III | **Familiar Ground** | `move_speed_mult_revealed_wild` | 🟡 staged | HOOK EXISTS (wiring staged): player move speed + map_state.cell_revealed + outside-settlement context |
| beyond_the_known | Cap | **Beyond the Known** | `capstone_trailseeker` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported surface components (movement, reveal radius, harvest yield, seed return) |

## Hearthwright Path — Runewright

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| long_measure | I | **Long Measure** | `build_repair_reach_bonus` | 🟡 staged | HOOK EXISTS (wiring staged): player build/repair reach (scoped, not mining/combat/harvest/pickup) |
| steady_placement | I | **Steady Placement** | `placement_tolerance` | ⛔ deferred | MISSING: placement-validity tolerance/snap widening in build_preview |
| practiced_repairs | I | **Practiced Repairs** | `repair_amount_mult` | 🟡 staged | HOOK EXISTS (wiring staged): game_root repair path |
| economical_construction | II | **Economical Construction** | `structure_recipe_cost_mult` | 🟡 staged | HOOK EXISTS (wiring staged): settlement-structure recipe input cost (common materials only) |
| salvager | II | **Salvager** | `dismantle_return_mult` | 🟡 staged | HOOK EXISTS (wiring staged): dismantle/reclaim return (capped at original spend) |
| repairers_example | II | **Repairer's Example** | `repairer_output_mult` | ⛔ deferred | MISSING: per-citizen Repairer output buff hook |
| foundation_sense | II | **Foundation Sense** | `placement_preview_info` | ⛔ deferred | MISSING: placement-preview info overlay (validity/bounds/cost/housing/contribution) |
| reinforced_work | III | **Reinforced Work** | `repaired_structure_protection` | ⛔ deferred | MISSING: per-structure incoming-damage hook + recent-repair timer |
| coordinated_labor | III | **Coordinated Labor** | `repairer_priority` | ⛔ deferred | MISSING: Repairer AI target-prioritization/idle-reduction hook |
| hearth_efficiency | III | **Hearth Efficiency** | `structure_contribution_mult` | ⛔ deferred | MISSING: per-structure settlement-threshold contribution weighting |
| swift_maintenance | III | **Swift Maintenance** | `repair_cooldown_mult` | 🟡 staged | HOOK EXISTS (wiring staged): game_root repair-action cadence |
| keeper_of_foundations | Cap | **Keeper of Foundations** | `capstone_hearthwright` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported build/repair components (repair amount, reach, cadence); citizen/structure components deferred |

## Resonant Path — Runewright

| ID | Tier | Skill | Effect key | Support | State owner / hook |
|---|:--:|---|---|---|---|
| deep_reservoir | I | **Deep Reservoir** | `attunement_bonus` | ✅ live | player.perk_attunement_bonus (additive max Attunement) |
| far_echo | I | **Far Echo** | `pulse_radius_mult` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse radius |
| lingering_echo | I | **Lingering Echo** | `pulse_duration_mult` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse duration |
| efficient_resonance | II | **Efficient Resonance** | `pulse_cost_mult` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse cost |
| inscribed_conduit | II | **Inscribed Conduit** | `equip_attunement_amp` | 🟡 staged | HOOK EXISTS (wiring staged): player max Attunement from equipped rings/amulets (amplified) |
| harmonic_equipment | II | **Harmonic Equipment** | `attunement_equipment_effect_amp` | 🟡 staged | HOOK EXISTS (wiring staged): Amplifies supported Attunement equipment effects (max-Attunement contribution); non-capacity equipment effects deferred |
| echo_mapping | II | **Echo Mapping** | `pulse_reveal_persist` | 🟡 staged | HOOK EXISTS (wiring staged): pulse reveal writes into persistent map_state |
| deep_illumination | III | **Deep Illumination** | `pulse_illumination_mult_underground` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse illumination/duration + underground context |
| structured_pulse | III | **Structured Pulse** | `pulse_identify_structures` | ⛔ deferred | MISSING: pulse-driven door/station/structure identification overlay |
| full_resonance | III | **Full Resonance** | `pulse_full_bonus` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse radius/duration when cast at full Attunement |
| reserve_channel | III | **Reserve Channel** | `pulse_reserve` | 🟡 staged | HOOK EXISTS (wiring staged): attunement pulse-cast path (weak proportional pulse when under normal cost) |
| living_resonance | Cap | **Living Resonance** | `capstone_resonant` | 🟡 staged | HOOK EXISTS (wiring staged): Aggregates supported Attunement components (capacity, radius, duration, efficiency, reveal persistence) |

## What is wired live this pass (13 skills + Oathbound innate)

Delivered gameplay changes, all covered by smoke checks (`calling_static_effects_apply`,
`calling_damage_source_scoping`, `calling_defeat_rewards_and_heal`, `fq06_*`, `fq15_*`):

- **Damage source system** — `player.take_damage(amount, source)` now tags `enemy`/`hazard`/`drowning`/`generic`.
  Enemy contact (`simple_threat.gd`) tags `enemy`; lava/contact hazard (`player._apply_environmental_hazard`) tags `hazard`. Resolved via `game_root.calling_incoming_damage_mult(source)`.
- **Oathbound — Resolve (innate):** enemy damage ×0.9 (×0.8 during an active settlement threat).
- **Warden — Holdfast (W3):** ×0.9 enemy damage while inside settlement bounds.
- **Warden — Last Watch (W10):** ×0.8 enemy damage while below 35% health during a threat.
- **Warden — Tempered Frame (W1):** +20 max health (idempotent delta in `apply_perk_effects`).
- **Warden — Armored Bearing (W2):** equipped-armor ×1.15 (read-time in `armor_total()`; gear only).
- **Prospector — Tunnel Hardened (P8):** hazard damage ×0.8 underground (hostile unaffected).
- **Trailseeker — Stormwise (T8):** hazard damage ×0.8 on the surface outside settlement.
- **Prospector/Trailseeker — Deep Surveying (P3) / Broad Horizon (T3):** +1 scout reveal radius (`_scout_reveal_radius`).
- **Prospector — Stonewise (P1) / Practiced Swing (P2):** mining speed ×1.15 / ×1.10 (`effective_mine_speed`).
- **Resonant — Deep Reservoir (R1):** +15 max Attunement (`perk_attunement_bonus`).
- **Vanguard — Relentless (V3):** +6 health per XP-granting defeat (`_on_threat_died`).
- **Vanguard — Victory's Breath (V11):** +25 health & Attunement when a defeat ends the threat.

Context predicates reused/added: `_player_in_settlement()` (mirrors `subject.settlement_bounds_px`),
`_player_underground()` (`world.sky_line`), `calling_threat_active()` (`_live_threat_count`).

**Staged (39):** the authoritative hook is identified in the `hook` column ("HOOK EXISTS (wiring staged)") but the effect is not applied yet — gameplay is unchanged. These are the natural next wiring batch (movement contexts, Attunement-pulse radius/duration/cost, harvest speed, extra-drop chances, scoped reach, repair amount/cadence, recipe cost, salvage, food-heal, echo mapping, etc.).

**Deferred — needs a new mechanism (20):** combat-state tracking (Decisive Strikes, Momentum, Executioner, Counterforce, Steel Rhythm, Breachbreaker, Press the Line), per-citizen job buffs (Defensive Presence, Rally the Line, Stand Together, Repairer's Example, Coordinated Labor), per-structure incoming-damage (Reinforced Position, Reinforced Work), Unbroken (per-threat lethal-hit intercept), placement tolerance/preview UI (Steady Placement, Foundation Sense, Structured Pulse), and Hearth Efficiency contribution weighting. Left gameplay-unchanged per handoff constraint 7 (no simulated support).

## Save compatibility

- The serialized character key stays **`role`** (no migration of existing saves). Values are now Callings.
- **Legacy characters** whose stored `role` is not one of the three Callings (`homesteader`/`prospector`/`warden` or anything else) are **auto-mapped at read time** to the data-driven `default_calling` (`oathbound`) via `BlockRegistry.calling_of()` — non-destructive; the stored value is never rewritten, so unrelated persistence is untouched.
- **Purchased skills** live in the world save's progression state exactly as before. Old perk ids (`stone_recovery`, etc.) no longer exist, so they self-drop on load (existing behavior in `apply_progression_state`), quietly refunding their points.
- Per-role **starter kits were removed** (Callings grant no starting-item windfall, handoff constraint 6); `_grant_role_items` now grants nothing because every Calling's `starting_items` is empty.

## Player-facing Role → Calling changes

- Character creation (`shell_ui.gd`): the "Role" selector is now **"Calling"** (3 options); help text updated; the character card detail resolves through the mapped Calling.
- Player character panel (`hud.gd`): "Role: X" is now **"Calling: <Name> · <Innate>"**.
- Skill panel (`skill_tree_panel.gd`): shows the character's Calling, its Innate, and its two Paths laid out by tier (I / II / III / Capstone) with tier-gate state.
- Citizen panel (`hud.gd`): a citizen's **job** label/button changed from "Role"/"Change role" to **"Job"/"Change job"** to disambiguate settlement jobs (Defender/Repairer) from the player's Calling. Jobs are preserved as jobs (handoff constraint 2).
- Internal/technical uses of "role" (tests, layer roles, save keys) are intentionally preserved.
