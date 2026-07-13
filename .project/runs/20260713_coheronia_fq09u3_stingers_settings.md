# Run Ledger: 20260713_coheronia_fq09u3_stingers_settings

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Opus 4.8) implementation lead, remote-control session |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09U3 (docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md) |
| Started At | 2026-07-13T13:15:00-04:00 |
| Ended At | 2026-07-13T13:55:00-04:00 |

## User Request

Remote-control resume: "the computer was reset along with your workstation
after running out of tokens in the middle of work. Also note, codex has
been adding images (and notified to stay out of your way) please review
where we are and where to jump back in. Use a token saving swarm of agents
and a verification and optimization loop as appropriate."

## Context Recovered

The reset landed mid-FQ-09U3. The dirty tree held two entangled streams:
this FQ-09U3 music work and a concurrent, independently-verified Codex art
integration (`docs/HANDOFF_ART_INTEGRATION_2026-07-12.md`). U3 was ~95%
done; the sole failing smoke check was `fq09u3_events_fire_stingers`
(256/257 in Codex's last recorded run). Three files
(`scripts/main/smoke_test.gd`, `scripts/validate_repo.py`,
`scripts/player/player.gd`) carry hunks from both lanes and cannot be split.

## Root Cause and Fix (resume point)

`fq09u3_events_fire_stingers` drives two game events and expects two
stingers: `music_event("nightfall")` and the player's `attunement_pulsed`.
Only nightfall fired (+1, not +2). Cause: the AdaptiveMusicDirector wired
both signals inside its `_ready`; as a child of Main it runs `_ready` before
game_root assigns its `@onready var player`, so `root.player` was null and
the `attunement_pulsed -> _on_attunement_pulsed` connection was silently
skipped (the `_wire_events` guard `root.player != null` was false). The
`music_event` connection survived because it targets a script-level signal
available immediately. Fix: `_wire_events.call_deferred()` in the director's
`_ready`, so wiring runs after the full `_ready` cascade when the player
node is live. One line, entirely within the audio lane. Suite 256 -> 257.

## What Shipped (implementation commit `188a01b`)

- **FQ-09U3** (`scripts/audio/adaptive_music_director.gd`,
  `scripts/audio/audio_settings.gd`, `data/music_manifest.json`,
  `scenes/audio/AdaptiveMusicDirector.tscn`, plus the U3 blocks in
  `smoke_test.gd` and `validate_repo.py`):
  - `play_stinger(kind)` fires a one-shot on the SFX-bus StingerPlayer over
    a per-frame Music-bus duck envelope (bed dips under the stinger; music
    never stops). Per-kind cooldowns stop event spam; the duck attacks fast,
    releases slow, all data-defined in `stinger_config`.
  - The narrow event surface: `_wire_events` (now deferred) connects
    game_root's `music_event(kind)` and the player's `attunement_pulsed`.
  - `AudioSettings.apply(profile[, duck_db])` is the single bus-volume
    authority (runtime Music + SFX buses, profile `music_volume`/
    `sfx_volume`, optional duck folded into Music); volume state is
    profile-level, never a world-save key.
  - Director `process_mode = ALWAYS`: score + duck/cooldown envelope survive
    pause.
  - `validate_repo.py` requires the five stinger OGGs.
- **Codex art integration** (55 PNGs + `data/player_visuals.json`,
  `scripts/player/player_visual.gd`, `scenes/player/Player.tscn`,
  `scripts/settlement/town_hall.gd`, `scripts/world/world_backdrop.gd`,
  `scripts/world/block_registry.gd`, `data/visual_assets.json`,
  `docs/ASSET_ROADMAP.md`, `docs/HANDOFF_ART_INTEGRATION_2026-07-12.md`, and
  the art blocks in the shared files): independently verified by Codex;
  committed together with U3 per operator decision because of the shared
  files. Base bodies stay unarmored; collision (12x28) and the action/
  facing/three-phase swing interface are unchanged.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; incl. five stinger OGGs + all Codex art contracts |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 257/257 | `smoke_results.json` at 2026-07-13T13:32:02 (isolated temp APPDATA) |
| `git diff --check` | PASS | only expected LF->CRLF notices |

The 8 `fq09u3_*` checks: stinger assets (five short non-looping one-shots,
director reports five kinds); a fired stinger ducking the Music bus below
-3 dB while the context loop plays; the duck releasing; per-kind cooldowns
(repeat blocked, other kind allowed, same kind after cooldown); the event
surface reaching the director (nightfall + attunement each fire a stinger —
the deferred-wiring proof); volume settings applying to the buses and
round-tripping; and the world save carrying zero music/volume/stinger keys.

## Acceptance vs FQ-09U3

- Dawn/nightfall/raid/attunement/base-advance stingers over temporary
  ducking, never stopping the music. [done]
- Music/SFX volume settings applied to runtime buses, profile-persisted.
  [done]
- Pause behavior: director keeps processing (ALWAYS). [done]
- Final audio asset validation (five stinger OGGs; verifier durations/
  sample rates/headroom; operator listening approval 2026-07-10). [done]

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260713_coheronia_fq09u3_stingers_settings.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260713_coheronia_fq09u3_stingers_settings.json`

## Git Closeout

Implementation commit `188a01b` (U3 + the Codex art integration together —
the shared `smoke_test.gd`/`validate_repo.py`/`player.gd` hunks made a clean
split impossible; operator chose the combined commit), then this
evidence-only commit. NOT pushed — push deferred to explicit operator
instruction (the remote-control choice specified "push only if you say so").

## Remaining Risks

- Stinger FEEL (duck depth -9 dB, attack/release rates, 8 s cooldown) is
  play-tunable in `stinger_config`; only listening during play settles it.
- The combined commit means U3 and the art lane share history; a future
  revert of one would need path-level surgery.
- Codex art QA noted a headless screenshot tour blocked on
  `RenderingServer.frame_post_draw`; final visual screenshots used a
  hidden/windowed rendered run. No new art screenshots were captured this
  resume (the change was audio-only); the art was accepted on Codex's prior
  verified rendered QA.
- Nothing pushed to origin/main; the local `main` is ahead by two commits.

## Next Action

FQ-10 (more ores and metallurgy data) is the queue head. Art production
continues via `docs/ASSET_ROADMAP.md`; the recommended sprite backlog
(player gear overlays, remaining equipment icons, opening cels) is in
`docs/HANDOFF_ART_INTEGRATION_2026-07-12.md`. Push when the operator says so.
