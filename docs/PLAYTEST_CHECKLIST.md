# Coheronia — Operator Playtest Checklist

A hands-on pass to confirm the first play loop works without reading the handoff.
The in-game **goal panel** (top-center; press **O** to hide/show) advances through
these same objectives from real state — you should be able to follow it alone.
There are **seven** ordered goals; tick each box and note anything unclear.

## Launch

- [ ] Game boots to the title screen (prologue plays on first run; **Esc** skips,
      any key advances). Continue or start a new character + world.
- [ ] On entering a world, the goal panel reads **Goal 1/7: Gather wood and stone**.

## First loop (goal panel should advance as you go)

1. **Gather wood and stone**
   - [ ] Mine a tree (LMB) → wood enters the backpack; mine stone → stone enters.
   - [ ] Goal advances to **Light the Town Hall** once you hold some wood + stone.
2. **Light the Town Hall**
   - [ ] Press **C** to craft a torch; select it and place it (RMB) near the hall.
   - [ ] Night visibly darkens; the torch throws local light. Goal advances to
         **Deposit resources**.
3. **Deposit resources at the hall**
   - [ ] Stand next to the Town Hall and press **E** to open it; deposit materials
         into the stockpile (Town Hall label stops reading "empty").
   - [ ] Goal advances to **Forge a tool or build a station**.
4. **Forge a tool or build a station**
   - [ ] Press **C** to open the unified crafting panel; forge a tool (e.g. the
         tier-2 pick or the axe) or build a station (e.g. the workbench). Recipes
         are grouped by station with have/need per input.
   - [ ] Confirmation feedback fires; the tool/station is now yours. Goal advances
         to **Survive the first night**.
5. **Survive the first night**
   - [ ] Night falls, threats approach; keep the hall lit and hold until dawn.
   - [ ] On reaching a new day the goal advances to **Build a house**.
6. **Build a house**
   - [ ] Wall in a room and hang a door (craft doors with **C**). A valid enclosed
         house raises settlement housing capacity above the Town Hall's base.
   - [ ] Goal advances to **Post a defender**.
7. **Post a defender**
   - [ ] Open the Town Hall (**E**) and cycle a settler's job to **Defender**.
   - [ ] With a defender posted the goal panel shows
         **✓ Settlement founded — keep it thriving.**

## Unobtrusiveness / hide

- [ ] Press **O** — the goal panel hides; press **O** again — it returns.
- [ ] The panel never blocks the play field or steals mouse input.

## Persistence

- [ ] Save (**F5**), reload (**F9**) mid-loop: the goal panel resumes at the right
      objective (it re-derives from real state, not a saved tutorial flag).

## Free play sanity

- [ ] Mining/placing, day/night, storms, population, and the settlement bars
      (Coherence / Load / Resilience) all respond to what you do.
- [ ] Nothing in the goal panel regresses to an earlier objective after you have
      completed it.

## Callings — first-loop sanity across all three

Run the loop once per Calling (**Oathbound**, **Wayfarer**, **Runewright**) to
exercise both of each Calling's Paths:

- [ ] Purchases spend perk points and open tiers by count (II at 2, III at 6,
      capstone at 9); no live skill is gated behind an inert one.
- [ ] Calling, XP, level, and purchased skills carry across a world switch
      (character-owned), while settlement level stays with the world.
- [ ] Natural-yield perks (extra ore/wood/plant, seed return) only fire on
      natural resources, not placed blocks; assault/settlement-scoped effects
      only apply in the right context.

---

# S-07.2 — Calling balance: MEASURE-FIRST protocol

**This is a measurement pass, not a tuning pass.** Per D3 (LOCKED) no data value
changes until the worst-case stacking below is recorded. The goal is one number
per hot channel: *how strong does the fully-stacked, best-context build get,
measured in-game*, so the later data-only tuning (cap stacking / de-dup the most
repetitive channel by re-pointing effects) has evidence to size against. Do **not**
tune, re-point, or edit `data/progression/perks.json` during this pass.

## The three hot channels (D3)

These are the conditionally-stacking channels the balance pass cares about. Each
row names the Path that owns it, every skill that piles onto it, and the context
that maximizes it (contexts multiply the stack, so the worst case is "all skills
bought **and** the strongest context active at once").

| # | Hot channel | Calling / Path | Stacking skills (buy all) | Max-out context |
|---|---|---|---|---|
| A | **Hostile-damage reduction** (damage *taken* from creatures) | Oathbound / **Warden** | Resolve (innate) + Holdfast + Defensive Presence + Last Watch + Unbroken + Guardian of the Hearth (+ Armored Bearing / Reinforced Position via armor) | Inside settlement bounds **and** an active settlement assault **and** wounded (below the Last Watch/Unbroken health threshold) |
| B | **Weapon damage vs hostiles** (damage *dealt*) | Oathbound / **Vanguard** | Weapon Discipline + Decisive Strikes + Momentum + Executioner + Threat Hunter + Counterforce + Steel Rhythm + Breachbreaker + Press the Line + Threatbreaker (cap) | Striking an **assault** enemy during an active settlement threat (Executioner adds more vs a wounded target) |
| C | **Structure-repair amount** (structure HP restored per repair) | Runewright / **Hearthwright** | Measured Hand (innate) + Practiced Repairs + Economical Construction + Salvager + Repairer's Example + Reinforced Work + Hearth Efficiency + Swift Maintenance + Keeper of Foundations (cap) | Repairing a damaged player structure. *(Note the cross-Calling ceiling: Warden's Emergency Repairs also boosts repair during an assault, but only one Calling is active at a time — record Hearthwright's own stack.)* |

## How to measure each channel

For each channel, take a **baseline** (fresh character of that Calling, **zero**
skills purchased) and a **full-stack** reading (every listed skill bought, in the
max-out context), against the **same fixed target**, then record the ratio.

Setup per channel:
- Make a fresh character of the owning Calling; note it starts with the innate only.
- Level / award enough perk points to buy the whole Path under test (tiers open by
  live-count 2 / 6 / 9). If there is no fast route, record the highest tier you
  could actually reach and mark the reading **partial** — a partial worst-case is
  still evidence; note which tiers are missing.
- Use one fixed, repeatable target so baseline and full-stack are comparable
  (same enemy id for A/B, same structure at the same damage for C).

- [ ] **A — damage reduction.** Take a hit from a fixed enemy with 0 skills; record
      HP lost. Repeat with the full Warden stack in-context (inside bounds, assault
      active, wounded); record HP lost. Ratio = full ÷ baseline damage taken.
- [ ] **B — weapon damage.** Hit a fixed full-HP enemy with 0 skills; record damage
      per hit (or hits-to-kill). Repeat with the full Vanguard stack vs an assault
      enemy during a threat; record damage per hit. Ratio = full ÷ baseline damage.
- [ ] **C — repair amount.** Damage a structure a fixed amount; repair once with 0
      skills and record HP restored. Repeat with the full Hearthwright stack; record
      HP restored. Ratio = full ÷ baseline restored.

## Results ledger (fill this in — this is the S-07.2 deliverable)

Record the actual observed numbers. "Ratio" is the multiple over the zero-skill
baseline; "context" is which max-out conditions were genuinely active; "reach"
notes if the read is full (capstone bought) or partial (and which tiers missing).

| Channel | Baseline (0 skills) | Full stack | Ratio (×) | Context active | Reach (full/partial) | Notes |
|---|---|---|---|---|---|---|
| A — hostile-damage reduction | | | | | | |
| B — weapon damage vs hostiles | | | | | | |
| C — structure-repair amount | | | | | | |

**Worst-case summary (one line the tuning pass will size against):**

> Highest measured ratio was channel ___ at ___× (context: ___). Most-repetitive
> channel (most skills pointed at one number) was ___. Recommended cap direction: ___.

## Secondary channels — glance only (record only if a value looks egregious)

Not the D3 focus, but note any that feel obviously out of band during the runs:
max health (Warden: Tempered Frame + Stand Together); armor protection; mining
speed (Prospector: Stonewise + Practiced Swing + Master of the Deep); move speed
(Trailseeker: Trailcraft + Farwalker + Deep Stride + Familiar Ground + Beyond the
Known); Attunement pulse radius / duration / cost (Resonant); extra-yield roll
rates (Clean Extraction / Stone Economy / Woodwise / Forager's Share).

- [ ] No secondary channel is so lopsided it needs to jump the D3 queue. If one is,
      note it here (do not tune it now): ____________________________________

## After the pass

- [ ] The three-row results ledger above is filled with real numbers (or explicitly
      marked partial with the missing tiers).
- [ ] The worst-case summary line is written.
- [ ] **Nothing was tuned.** Any proposed cap / de-dup is written as a recommendation
      for the S-07.2 tuning slice, not applied — that slice authors it against this
      evidence and is guarded by `s07_calling_stack_cap_holds`.

## Notes

_Record friction, confusing prompts, or anything that needed the handoff to
understand — those are the FQ-14 follow-ups._
