# Coheronia — Operator Playtest Checklist

A hands-on pass to confirm the first play loop works without reading the handoff.
The in-game **goal panel** (top-center; press **O** to hide/show) advances through
these same early objectives from real state — you should be able to follow it
alone. Tick each box; note anything that felt unclear.

## Launch

- [ ] Game boots to the title screen (prologue plays on first run; **Esc** skips,
      any key advances). Continue or start a new character + world.
- [ ] On entering a world, the goal panel reads **Goal 1/5: Gather wood and stone**.

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
   - [ ] In the Town Hall panel, forge the pick (tier 2) — or the axe, or build a
         workbench — from the stockpile.
   - [ ] Confirmation feedback fires; the tool/station is now yours. Goal advances
         to **Survive the first night**.
5. **Survive the first night**
   - [ ] Night falls, threats approach; keep the hall lit and hold until dawn.
   - [ ] At dawn the goal panel shows **✓ Settlement founded — keep it thriving.**

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

## Notes

_Record friction, confusing prompts, or anything that needed the handoff to
understand — those are the FQ-14 follow-ups._
