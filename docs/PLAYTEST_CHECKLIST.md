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

## Callings (extend the pass across all three)

Run the loop once per Calling (**Oathbound**, **Wayfarer**, **Runewright**) to
exercise both of each Calling's Paths:

- [ ] Purchases spend perk points and open tiers by count (II at 2, III at 6,
      capstone at 9); no live skill is gated behind an inert one.
- [ ] Calling, XP, level, and purchased skills carry across a world switch
      (character-owned), while settlement level stays with the world.
- [ ] Natural-yield perks (extra ore/wood/plant, seed return) only fire on
      natural resources, not placed blocks; assault/settlement-scoped effects
      only apply in the right context.
- [ ] **Record the measured worst-case conditional stacking on the hot channels**
      (weapon damage, hostile-damage reduction, repair amount) for the S-07.2
      balance pass — no tuning until this evidence exists.

## Notes

_Record friction, confusing prompts, or anything that needed the handoff to
understand — those are the FQ-14 follow-ups._
