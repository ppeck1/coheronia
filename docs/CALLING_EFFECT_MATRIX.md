# Coheronia — Calling Effect Matrix

_Authoritative trace of every Calling/Path/skill to the live hook it drives. After the closure-and-truthfulness pass **every purchasable skill is wired to a real gameplay hook** — there are no inert or placeholder skills. Effects are built only from existing systems (no new subsystems); 34 originally-unhooked skills were re-themed onto a wired channel within their Path's theme (see the Re-theme note)._

## Design & correctness invariants

- **Nothing inert is purchasable.** `try_purchase_perk` refuses any non-live skill; `perk_state` returns `coming_soon` for one. (All 72 are live today, so the guard is a standing safety net.)
- **Tier gates never force an inert purchase.** The gate is `min(design_gate, live-skills-in-lower-tiers)` and counts only *live* purchases, so every live skill is reachable by buying the live skills beneath it; it collapses to the exact 2 / 6 / 9 design gate once a Path is fully live.
- **Progression is character-owned.** XP, level, and purchased skills live on the shell character (`character.progression`) and follow it between worlds; on load they are filtered to the character's Calling so one Calling can never inherit another's purchases.
- **Legacy migration is semantic:** Warden→Oathbound, Prospector→Wayfarer, Homesteader→Runewright; anything else → default. Read-time, non-destructive.
- **Context is real:** a *settlement assault* means a live threat inside/near the settlement bounds (not any creature anywhere); reveal skills are scoped underground vs. surface.

## Callings & innate effects (all wired)

| Calling | Paths | Innate | What it does (live) |
|---|---|---|---|
| **Oathbound** | Warden, Vanguard | Resolve | Reduces hostile-creature damage (stronger during a settlement assault). |
| **Wayfarer** | Prospector, Trailseeker | Trailcraft | Faster movement outside the settlement + permanently wider scout radius. |
| **Runewright** | Hearthwright, Resonant | Measured Hand | Player structure repairs restore more; equipped ring/amulet Attunement is amplified. |
## Skills by Path

### Warden — Oathbound

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Tempered Frame** | Permanently increases maximum health. | `player.max_health via effects merge (player.gd:264)` |
| I | **Armored Bearing** | Increases the protection supplied by equipped armor. Does not amplify weapons, tools, or unrelated effects. | `player.armor_total() scale` |
| I | **Holdfast** | Reduces hostile-creature damage further while inside settlement bounds. | `player.take_damage(source=enemy) + settlement_bounds` |
| II | **Guarded Recovery** | Increases all healing you receive (food and passive recovery) while inside settlement bounds or during a settlement assault. | `player heal path (food/regen) + settlement/threat context` |
| II | **Defensive Presence** | Take even less hostile-creature damage while inside settlement bounds. | `take_damage(enemy)+settlement` |
| II | **Rally the Line** | Your weapon strikes assault enemies (those attacking the settlement) harder. | `_try_hit_threat+assault` |
| II | **Emergency Repairs** | Player-performed structure repairs restore more health during a settlement assault. | `game_root repair path + threat context` |
| III | **Reinforced Position** | Increases the protection supplied by your equipped armor. | `armor_total()` |
| III | **Stand Together** | Holding the line with the settlement raises your maximum health. | `player.max_health` |
| III | **Last Watch** | Personal defensive effects strengthen while below a health threshold during an active settlement threat. | `player.take_damage(source=enemy) + health fraction + threat context` |
| III | **Unbroken** | You take even less hostile damage while wounded during an assault. | `take_damage(enemy)+lowhp+assault` |
| Cap | **Guardian of the Hearth** | Guardian of the Hearth: markedly less hostile damage while defending the settlement. | `take_damage(enemy)+settlement` |

### Vanguard — Oathbound

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Weapon Discipline** | Weapons deal more damage to hostile creatures. Mining, chopping, harvesting, and block damage are unaffected. | `player._try_hit_threat weapon damage` |
| I | **Decisive Strikes** | Your weapons strike hostile creatures with extra force. | `_try_hit_threat` |
| I | **Relentless** | Defeating an XP-granting hostile creature restores health. | `enemy-defeat XP award hook` |
| II | **Momentum** | Battle momentum sharpens your blows against hostile creatures. | `_try_hit_threat` |
| II | **Executioner** | You hit hostile creatures harder, cutting down wounded foes faster. | `_try_hit_threat` |
| II | **Threat Hunter** | Weapon attacks deal additional damage to enemies belonging to an active settlement threat. | `player._try_hit_threat + active-threat context` |
| II | **Counterforce** | You answer blows with harder weapon strikes against hostile creatures. | `_try_hit_threat` |
| III | **Steel Rhythm** | You strike assault enemies harder while the settlement is under attack. | `_try_hit_threat+assault` |
| III | **Breachbreaker** | You hit assault enemies (those at the settlement) with extra force. | `_try_hit_threat+assault` |
| III | **Press the Line** | You press assault enemies with heavier weapon strikes. | `_try_hit_threat+assault` |
| III | **Victory's Breath** | Successfully ending a settlement threat restores health and Attunement. | `threat-cleared hook restores health + Attunement` |
| Cap | **Threatbreaker** | Threatbreaker: your weapons devastate assault enemies attacking the settlement. | `_try_hit_threat+assault` |

### Prospector — Wayfarer

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Stonewise** | Stone and ore nodes are mined faster. | `player.effective_mine_speed (perk_mine_speed_mult)` |
| I | **Practiced Swing** | Reduces the recovery time between mining actions. | `player.effective_mine_speed (recovery folds into mine rate)` |
| I | **Deep Surveying** | Increases map-reveal radius while underground. | `game_root._scout_reveal_radius + underground context` |
| II | **Resonant Survey** | Increases Attunement-pulse radius while underground. | `attunement pulse radius + underground context` |
| II | **Clean Extraction** | Mining a natural ore vein has a chance to yield an additional unit of that ore. | `mining drop resolution (ore family)` |
| II | **Stone Economy** | Mining deepstone (natural deep rock) has a chance to yield an extra unit. Placed or constructed blocks are unaffected. | `mining drop resolution (natural stone only)` |
| II | **Long Pick** | Increases mining interaction reach without increasing weapon, harvesting, building, or pickup reach. | `player mining reach (scoped, not build/pickup/weapon)` |
| III | **Tunnel Hardened** | Reduces lava and other environmental hazard damage while underground. Hostile-creature damage is unaffected. | `player.take_damage(source=hazard) + underground context` |
| III | **Deep Reserves** | Attunement pulses consume less Attunement while underground. | `attunement pulse cost + underground context` |
| III | **Deep Lantern** | Attunement-generated illumination lasts longer while underground. | `attunement pulse duration + underground context` |
| III | **Deep Stride** | Trailcraft's movement benefit becomes stronger while underground and outside settlement bounds. | `player move speed + underground/outside-settlement context` |
| Cap | **Master of the Deep** | Master of the Deep: mine stone and ore substantially faster. | `effective_mine_speed` |

### Trailseeker — Wayfarer

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Wildhand** | Trees and harvestable plants are gathered faster. | `player harvest/chop rate (axe/plant-preferred blocks)` |
| I | **Farwalker** | Trailcraft's movement bonus becomes stronger outside settlement bounds. | `player move speed + outside-settlement context` |
| I | **Broad Horizon** | Increases map-reveal radius while on the surface. | `game_root._scout_reveal_radius + surface context` |
| II | **Seedkeeper** | Clearing tree leaves is more likely to return a tree seed. | `seed-return roll on harvest (seed_pouch loop)` |
| II | **Woodwise** | Chopping natural trees has a chance to yield extra wood. Placed wood blocks are unaffected. | `tree-harvest drop resolution` |
| II | **Forager's Share** | Harvesting wild berry bushes and ripe crops has a chance to yield extra. Placed blocks, trees, and ore are unaffected. | `plant/crop harvest drop resolution` |
| II | **Careful Harvest** | Careful harvesting makes tree leaves more likely to return a tree seed. | `seed-return roll` |
| III | **Stormwise** | Reduces storm and environmental hazard damage while on the surface outside settlement bounds. | `player.take_damage(source=hazard) + surface/outside-settlement context` |
| III | **Field Sustenance** | Existing food and foraged healing consumables restore more health while outside settlement bounds. | `player food-heal amount + outside-settlement context` |
| III | **Sunwise** | Sunwise sight widens the surface you reveal as you travel. | `_scout_reveal_radius+surface` |
| III | **Familiar Ground** | Movement is faster across previously revealed surface terrain outside settlement bounds. | `player move speed + map_state.cell_revealed + outside-settlement context` |
| Cap | **Beyond the Known** | Beyond the Known: move much faster beyond the settlement walls. | `player move + outside-settlement` |

### Hearthwright — Runewright

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Long Measure** | Increases building-placement reach without affecting mining, combat, harvesting, or pickup reach. | `player build/repair reach (scoped, not mining/combat/harvest/pickup)` |
| I | **Steady Placement** | Steady hands extend your building-placement reach. | `build/repair reach` |
| I | **Practiced Repairs** | Player-performed structure repairs restore additional structure health. | `game_root repair path` |
| II | **Economical Construction** | Skilled construction makes each structure repair restore more health. | `repair path` |
| II | **Salvager** | Salvaged materials make your structure repairs restore more health. | `repair path` |
| II | **Repairer's Example** | Your example makes your own structure repairs more effective. | `repair path` |
| II | **Foundation Sense** | A sure sense of foundations extends your building-placement reach. | `build/repair reach` |
| III | **Reinforced Work** | Reinforced work: your repairs restore more structure health. | `repair path` |
| III | **Coordinated Labor** | Coordinated labor extends how far you can place settlement structures. | `build/repair reach` |
| III | **Hearth Efficiency** | Efficient work at the hearth strengthens your structure repairs. | `repair path` |
| III | **Swift Maintenance** | Swift maintenance: each repair restores more structure health. | `repair path` |
| Cap | **Keeper of Foundations** | Keeper of Foundations: your structure repairs restore far more health. | `repair path` |

### Resonant — Runewright

| Tier | Skill | Live effect | Hook |
|:--:|---|---|---|
| I | **Deep Reservoir** | Permanently increases base maximum Attunement. | `player.perk_attunement_bonus (additive max Attunement)` |
| I | **Far Echo** | Increases Attunement-pulse radius. | `attunement pulse radius` |
| I | **Lingering Echo** | Increases the duration of pulse-created illumination. | `attunement pulse duration` |
| II | **Efficient Resonance** | Attunement pulses consume less Attunement. | `attunement pulse cost` |
| II | **Inscribed Conduit** | Increases the maximum-Attunement bonus supplied by equipped rings, amulets, and other Attunement-bearing gear. | `player max Attunement from equipped rings/amulets (amplified)` |
| II | **Harmonic Equipment** | Amplifies the maximum-Attunement bonus supplied by equipped rings and amulets. | `Amplifies supported Attunement equipment effects (max-Attunement contribution); non-capacity equipment effects deferred` |
| II | **Echo Mapping** | Echo-mapping widens the reach of every attunement pulse. | `pulse radius` |
| III | **Deep Illumination** | Underground, your attunement pulses shine longer. | `pulse duration+underground` |
| III | **Structured Pulse** | Structured pulses linger longer, lighting the space around you. | `pulse duration` |
| III | **Full Resonance** | Your attunement pulses reach a greater radius. | `pulse radius` |
| III | **Reserve Channel** | You channel attunement efficiently — your pulses cost less. | `pulse cost` |
| Cap | **Living Resonance** | Living Resonance: your attunement pulses reach dramatically farther. | `pulse radius` |

## Re-theme note

The original design specified several effects that had no authoritative hook (per-citizen job buffs, per-structure incoming-damage, combat-state combos, placement-preview UI, etc.). Rather than build new subsystems or ship inert skills, 34 skills were re-themed onto an existing wired channel **within their Path's theme**, and their descriptions updated to match exactly what they now do:

- **Warden** → personal defense / endurance (settlement damage reduction, armor, max health, low-health protection).
- **Vanguard** → weapon-vs-hostile damage (flat and assault-scoped) + on-defeat restores.
- **Prospector / Trailseeker** → mining & harvest speed, extra-yield & seed return, scoped reach, movement, reveal radius, Attunement-pulse tuning, hazard reduction.
- **Hearthwright** → structure-repair strength and build/repair reach.
- **Resonant** → Attunement capacity, pulse radius / duration / cost, equipment amplification.

This keeps names and flavor while guaranteeing every skill is real. The wired channels are all consulted live at their computation sites (`player.gd` movement / mining / harvest / reach / pulse / food-heal / weapon-hit / max-attunement; `game_root.gd` damage-source resolver, reveal radius, on-defeat and assault-end restores; `town_hall.repair` amount).

## Save compatibility

- Serialized character key stays `role`; its values are Callings. Legacy values map semantically (above); the stored value is never rewritten.
- Progression is authored on the character and mirrored into the world save for backward compatibility; on load the character copy wins, with the world copy as a fallback for pre-existing worlds.
- Callings grant no starting-item windfall.
