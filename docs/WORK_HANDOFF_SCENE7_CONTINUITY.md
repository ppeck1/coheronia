# Scene 7 Continuity Handoff

Date: 2026-07-15  
Scope: opening-cinematic artwork only; no HUD, prologue, gameplay, or manifest code changes.

## Current working replacement

`art/generated/opening/opening_07_civilization_pushes_back_01.png` is now a normalized 640x360 replacement based on the externally supplied Scene 7 image. It keeps that image's coherent single-scene settlement, hall, berry tender, digger, crate carrier, beam carrier, and shared dusk pixel-art language, while moving the important action above the lower-quarter caption band.

The prior rich underground-settlement baseline remains recoverable from the generated source path listed below. It is not the active project asset.

The immediately preceding replacement was rejected because it read as the same weak Scene 7 composition with a separate horizon layer pasted over it. That replacement has been removed from the project asset.

## What was attempted

1. A sparse wireframe Scene 7 was produced earlier. It was rejected as an under-resolved regression.
2. A richer settlement restyle was produced from the original Scene 7 plus Scenes 3 and 5. This became the restored baseline above.
3. A continuity-first regeneration was attempted using the original Scene 7 composition and Scenes 3/5 as style references. It failed visual review: character/environment continuity still did not match the collection, and the result felt composited rather than authored as one scene.
4. That failed regeneration was reverted.
5. The user supplied a replacement image from another generation path. It was re-authored as one coherent composition with the action shifted above the caption region, then normalized to the runtime contract.

## Canonical references for the next pass

- `art/generated/opening/opening_03_scattered_peoples_01.png` — character scale, anatomy, outlines, and warm practical-light language.
- `art/generated/opening/opening_05_first_hall_raised_01.png` — builder scale, environment density, and authored pixel rendering.
- `art/generated/opening/opening_06_attunement_pulse_01.png` — five-star constellation anchor positions.
- `art/generated/opening/opening_08_title_card_01.png` — title constellation treatment.
- Original Scene 7 source master: `C:\Users\peckm\.codex\generated_images\019f617b-f865-7bb0-8c73-4fad442613ed\exec-a99ee4ec-618b-47be-b102-0844eff07862.png`.

## Required next-pass constraints

- Treat Scene 7 as a single authored pixel-art composition, not a background plus pasted horizon or pasted characters.
- Preserve the existing settlement content/layout, but redesign the characters and environment together.
- Match Scenes 3 and 5 in character proportions, silhouette articulation, outline treatment, pixel-cluster density, and light response.
- Remove the dotted gold/amber arc entirely.
- Keep the threat mostly as two faint eyes and a partial silhouette beyond the light boundary.
- Use the five constellation anchors subdued behind the settlement light.
- Keep the lower quarter calm for the engine caption.
- Generate and approve one still frame before deriving animation frames.
- The active replacement is already 640x360/32-color compliant; do not resize it again without checking the prologue view.

## Verification

After restoration, the existing pixel-asset validator, strict asset audit, repository validator, and `git diff --check` were run successfully. The existing unrelated `scripts/ui/hud.gd` working-tree modification was not touched.
