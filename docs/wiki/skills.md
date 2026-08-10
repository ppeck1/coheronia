# Skills

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

## Scope

- Source data: `data/progression/perks.json` (six Path lanes × twelve skills) and `data/character_data.json` (the three Callings).
- Live UI consumer: `scripts/ui/skill_tree_panel.gd` (two Path cards for the character's Calling).
- Point economy is runtime-owned (one perk point per player level above 1); a character's Calling, XP, level, and purchased skills are character-owned and follow the character between worlds.

> Every skill below is wired to a real gameplay hook (`support: live`). Balance is a known open item — see [Known Issues](known_issues.md).

## Callings

| Calling | ID | Paths | Innate effect |
|---|---|---|---|
| Oathbound | `oathbound` | Warden, Vanguard | Resolve: Damage received from hostile creatures is reduced. This protection becomes stronger during an active settlement threat. |
| Wayfarer | `wayfarer` | Prospector, Trailseeker | Trailcraft: Movement is faster outside settlement bounds, and map-reveal radius is permanently increased. |
| Runewright | `runewright` | Hearthwright, Resonant | Measured Hand: Player-performed structure repairs restore more structure health, and positive maximum-Attunement bonuses supplied by equipment are amplified. |

## Tier Gates

A Path's tiers open by the count of skills already purchased in that Path (a live skill is never gated behind an inert one):

| Tier | Opens at |
|---|---|
| Tier 1 | 0 skills already purchased in the Path |
| Tier 2 | 2 skills already purchased in the Path |
| Tier 3 | 6 skills already purchased in the Path |
| Capstone | 9 skills already purchased in the Path |

## Paths and Skills

### Warden (Oathbound)

*Personal endurance, settlement defense, structure protection, and Defender support.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Tempered Frame | `tempered_frame` | 1 | `max_health_bonus` | 20 | live | Permanently increases maximum health. |
| Tier 1 | Armored Bearing | `armored_bearing` | 1 | `armor_mult` | 1.15 | live | Increases the protection supplied by equipped armor. Does not amplify weapons, tools, or unrelated effects. |
| Tier 1 | Holdfast | `holdfast` | 1 | `hostile_damage_mult_settlement` | 0.9 | live | Reduces hostile-creature damage further while inside settlement bounds. |
| Tier 2 | Guarded Recovery | `guarded_recovery` | 1 | `heal_mult_settlement_or_threat` | 1.25 | live | Food and passive recovery restore more health inside settlement bounds or during a settlement assault. |
| Tier 2 | Defensive Presence | `defensive_presence` | 1 | `hostile_damage_mult_settlement` | 0.95 | live | Take even less hostile-creature damage while inside settlement bounds. |
| Tier 2 | Rally the Line | `rally_the_line` | 1 | `weapon_damage_mult_threat` | 1.1 | live | Your weapon strikes assault enemies (those attacking the settlement) harder. |
| Tier 2 | Emergency Repairs | `emergency_repairs` | 1 | `repair_amount_mult_threat` | 1.25 | live | Player-performed structure repairs restore more health during a settlement assault. |
| Tier 3 | Reinforced Position | `reinforced_position` | 1 | `armor_mult` | 1.1 | live | Increases the protection supplied by your equipped armor. |
| Tier 3 | Stand Together | `stand_together` | 1 | `max_health_bonus` | 15 | live | Holding the line with the settlement raises your maximum health. |
| Tier 3 | Last Watch | `last_watch` | 1 | `hostile_damage_mult_lowhp_threat` | 0.8 | live | Personal defensive effects strengthen while below a health threshold during an active settlement threat. |
| Tier 3 | Unbroken | `unbroken` | 1 | `hostile_damage_mult_lowhp_threat` | 0.9 | live | You take even less hostile damage while wounded during an assault. |
| Capstone | Guardian of the Hearth | `guardian_of_the_hearth` | 1 | `hostile_damage_mult_settlement` | 0.85 | live | Guardian of the Hearth: markedly less hostile damage while defending the settlement. |

### Vanguard (Oathbound)

*Weapon mastery, aggressive threat removal, combat momentum, and finishing power.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Weapon Discipline | `weapon_discipline` | 1 | `weapon_damage_mult` | 1.15 | live | Weapons deal more damage to hostile creatures. Mining, chopping, harvesting, and block damage are unaffected. |
| Tier 1 | Decisive Strikes | `decisive_strikes` | 1 | `weapon_damage_mult` | 1.15 | live | Your weapons strike hostile creatures with extra force. |
| Tier 1 | Relentless | `relentless` | 1 | `heal_on_xp_kill` | 6 | live | Defeating an XP-granting hostile creature restores health. |
| Tier 2 | Momentum | `momentum` | 1 | `weapon_damage_mult` | 1.1 | live | Battle momentum sharpens your blows against hostile creatures. |
| Tier 2 | Executioner | `executioner` | 1 | `weapon_damage_mult` | 1.15 | live | You hit hostile creatures harder, cutting down wounded foes faster. |
| Tier 2 | Threat Hunter | `threat_hunter` | 1 | `weapon_damage_mult_threat` | 1.2 | live | Weapon attacks deal additional damage to enemies belonging to an active settlement threat. |
| Tier 2 | Counterforce | `counterforce` | 1 | `weapon_damage_mult` | 1.1 | live | You answer blows with harder weapon strikes against hostile creatures. |
| Tier 3 | Steel Rhythm | `steel_rhythm` | 1 | `weapon_damage_mult_threat` | 1.15 | live | You strike assault enemies harder while the settlement is under attack. |
| Tier 3 | Breachbreaker | `breachbreaker` | 1 | `weapon_damage_mult_threat` | 1.15 | live | You hit assault enemies (those at the settlement) with extra force. |
| Tier 3 | Press the Line | `press_the_line` | 1 | `weapon_damage_mult_threat` | 1.1 | live | You press assault enemies with heavier weapon strikes. |
| Tier 3 | Victory's Breath | `victorys_breath` | 1 | `threat_end_restore` | 25 | live | Successfully ending a settlement threat restores health and Attunement. |
| Capstone | Threatbreaker | `threatbreaker` | 1 | `weapon_damage_mult_threat` | 1.5 | live | Threatbreaker: your weapons devastate assault enemies attacking the settlement. |

### Prospector (Wayfarer)

*Mining, underground exploration, ore extraction, surveying, and underground survival.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Stonewise | `stonewise` | 1 | `mining_speed` | 1.15 | live | Stone and ore nodes are mined faster. |
| Tier 1 | Practiced Swing | `practiced_swing` | 1 | `mining_speed` | 1.1 | live | Reduces the recovery time between mining actions. |
| Tier 1 | Deep Surveying | `deep_surveying` | 1 | `reveal_radius_underground` | 1 | live | Increases map-reveal radius while underground. |
| Tier 2 | Resonant Survey | `resonant_survey` | 1 | `pulse_radius_mult_underground` | 1.2 | live | Increases Attunement-pulse radius while underground. |
| Tier 2 | Clean Extraction | `clean_extraction` | 1 | `ore_extra_drop_chance` | 0.2 | live | Mining a natural ore vein has a chance to yield an additional unit of that ore. |
| Tier 2 | Stone Economy | `stone_economy` | 1 | `stone_extra_drop_chance` | 0.15 | live | Mining deepstone (natural deep rock) has a chance to yield an extra unit. Placed or constructed blocks are unaffected. |
| Tier 2 | Long Pick | `long_pick` | 1 | `mining_reach_bonus` | 1 | live | Increases mining interaction reach without increasing weapon, harvesting, building, or pickup reach. |
| Tier 3 | Tunnel Hardened | `tunnel_hardened` | 1 | `hazard_damage_mult_underground` | 0.8 | live | Reduces lava and other environmental hazard damage while underground. Hostile-creature damage is unaffected. |
| Tier 3 | Deep Reserves | `deep_reserves` | 1 | `pulse_cost_mult_underground` | 0.85 | live | Attunement pulses consume less Attunement while underground. |
| Tier 3 | Deep Lantern | `deep_lantern` | 1 | `pulse_duration_mult_underground` | 1.25 | live | Attunement-generated illumination lasts longer while underground. |
| Tier 3 | Deep Stride | `deep_stride` | 1 | `move_speed_mult_underground_wild` | 1.1 | live | Trailcraft's movement benefit becomes stronger while underground and outside settlement bounds. |
| Capstone | Master of the Deep | `master_of_the_deep` | 1 | `mining_speed` | 1.2 | live | Master of the Deep: mine stone and ore substantially faster. |

### Trailseeker (Wayfarer)

*Surface exploration, wilderness travel, harvesting, food, and renewable resources.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Wildhand | `wildhand` | 1 | `harvest_speed` | 1.15 | live | Trees and harvestable plants are gathered faster. |
| Tier 1 | Farwalker | `farwalker` | 1 | `move_speed_mult_wild` | 1.1 | live | Trailcraft's movement bonus becomes stronger outside settlement bounds. |
| Tier 1 | Broad Horizon | `broad_horizon` | 1 | `reveal_radius_surface` | 1 | live | Increases map-reveal radius while on the surface. |
| Tier 2 | Seedkeeper | `seedkeeper` | 1 | `seed_return_chance_mult` | 1.25 | live | Clearing tree leaves is more likely to return a tree seed. |
| Tier 2 | Woodwise | `woodwise` | 1 | `wood_extra_drop_chance` | 0.2 | live | Chopping natural trees has a chance to yield extra wood. Placed wood blocks are unaffected. |
| Tier 2 | Forager's Share | `foragers_share` | 1 | `plant_extra_drop_chance` | 0.2 | live | Harvesting wild berry bushes and ripe crops has a chance to yield extra. Placed blocks, trees, and ore are unaffected. |
| Tier 2 | Careful Harvest | `careful_harvest` | 1 | `seed_return_chance_mult` | 1.25 | live | Careful harvesting makes tree leaves more likely to return a tree seed. |
| Tier 3 | Stormwise | `stormwise` | 1 | `hazard_damage_mult_surface_wild` | 0.8 | live | Reduces storm and environmental hazard damage while on the surface outside settlement bounds. |
| Tier 3 | Field Sustenance | `field_sustenance` | 1 | `heal_mult_food_wild` | 1.25 | live | Existing food and foraged healing consumables restore more health while outside settlement bounds. |
| Tier 3 | Sunwise | `sunwise` | 1 | `reveal_radius_surface` | 1 | live | Sunwise sight widens the surface you reveal as you travel. |
| Tier 3 | Familiar Ground | `familiar_ground` | 1 | `move_speed_mult_revealed_wild` | 1.1 | live | Movement is faster across previously revealed surface terrain outside settlement bounds. |
| Capstone | Beyond the Known | `beyond_the_known` | 1 | `move_speed_mult_wild` | 1.2 | live | Beyond the Known: move much faster beyond the settlement walls. |

### Hearthwright (Runewright)

*Construction, placement, repair, settlement maintenance, and Repairer support.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Long Measure | `long_measure` | 1 | `build_repair_reach_bonus` | 1 | live | Increases building-placement reach without affecting mining, combat, harvesting, or pickup reach. |
| Tier 1 | Steady Placement | `steady_placement` | 1 | `build_repair_reach_bonus` | 1 | live | Steady hands extend your building-placement reach. |
| Tier 1 | Practiced Repairs | `practiced_repairs` | 1 | `repair_amount_mult` | 1.2 | live | Player-performed structure repairs restore additional structure health. |
| Tier 2 | Economical Construction | `economical_construction` | 1 | `repair_amount_mult` | 1.15 | live | Skilled construction makes each structure repair restore more health. |
| Tier 2 | Salvager | `salvager` | 1 | `repair_amount_mult` | 1.15 | live | Salvaged materials make your structure repairs restore more health. |
| Tier 2 | Repairer's Example | `repairers_example` | 1 | `repair_amount_mult` | 1.15 | live | Your example makes your own structure repairs more effective. |
| Tier 2 | Foundation Sense | `foundation_sense` | 1 | `build_repair_reach_bonus` | 1 | live | A sure sense of foundations extends your building-placement reach. |
| Tier 3 | Reinforced Work | `reinforced_work` | 1 | `repair_amount_mult` | 1.15 | live | Reinforced work: your repairs restore more structure health. |
| Tier 3 | Coordinated Labor | `coordinated_labor` | 1 | `build_repair_reach_bonus` | 1 | live | Coordinated labor extends how far you can place settlement structures. |
| Tier 3 | Hearth Efficiency | `hearth_efficiency` | 1 | `repair_amount_mult` | 1.1 | live | Efficient work at the hearth strengthens your structure repairs. |
| Tier 3 | Swift Maintenance | `swift_maintenance` | 1 | `repair_amount_mult` | 1.15 | live | Swift maintenance: each repair restores more structure health. |
| Capstone | Keeper of Foundations | `keeper_of_foundations` | 1 | `repair_amount_mult` | 1.3 | live | Keeper of Foundations: your structure repairs restore far more health. |

### Resonant (Runewright)

*Attunement capacity, pulses, illumination, map reveal, and Attunement-bearing equipment.*

| Tier | Skill | ID | Cost | Effect key | Value | Support | Description |
|---|---|---|---|---|---|---|---|
| Tier 1 | Deep Reservoir | `deep_reservoir` | 1 | `attunement_bonus` | 15 | live | Permanently increases base maximum Attunement. |
| Tier 1 | Far Echo | `far_echo` | 1 | `pulse_radius_mult` | 1.15 | live | Increases Attunement-pulse radius. |
| Tier 1 | Lingering Echo | `lingering_echo` | 1 | `pulse_duration_mult` | 1.2 | live | Increases the duration of pulse-created illumination. |
| Tier 2 | Efficient Resonance | `efficient_resonance` | 1 | `pulse_cost_mult` | 0.85 | live | Attunement pulses consume less Attunement. |
| Tier 2 | Inscribed Conduit | `inscribed_conduit` | 1 | `equip_attunement_amp` | 1.2 | live | Increases the maximum-Attunement bonus supplied by equipped rings, amulets, and other Attunement-bearing gear. |
| Tier 2 | Harmonic Equipment | `harmonic_equipment` | 1 | `attunement_equipment_effect_amp` | 1.15 | live | Amplifies the maximum-Attunement bonus supplied by equipped rings and amulets. |
| Tier 2 | Echo Mapping | `echo_mapping` | 1 | `pulse_radius_mult` | 1.1 | live | Echo-mapping widens the reach of every attunement pulse. |
| Tier 3 | Deep Illumination | `deep_illumination` | 1 | `pulse_duration_mult_underground` | 1.25 | live | Underground, your attunement pulses shine longer. |
| Tier 3 | Structured Pulse | `structured_pulse` | 1 | `pulse_duration_mult` | 1.15 | live | Structured pulses linger longer, lighting the space around you. |
| Tier 3 | Full Resonance | `full_resonance` | 1 | `pulse_radius_mult` | 1.15 | live | Your attunement pulses reach a greater radius. |
| Tier 3 | Reserve Channel | `reserve_channel` | 1 | `pulse_cost_mult` | 0.85 | live | You channel attunement efficiently — your pulses cost less. |
| Capstone | Living Resonance | `living_resonance` | 1 | `pulse_radius_mult` | 1.25 | live | Living Resonance: your attunement pulses reach dramatically farther. |

## Related Pages

- [Character Types](character_types.md)
- [Known Issues](known_issues.md)
- [Wiki Overview](wiki.md)
