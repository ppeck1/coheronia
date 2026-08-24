# Release checklist — Coheronia v0.7-alpha

Concise, repeatable steps to cut a **prerelease**. This is the release authority;
day-to-day status lives in [`HANDOFF.md`](HANDOFF.md). Nothing here is executed
automatically — a human runs it and confirms each gate. Do **not** tag while any
required gate is red.

Semantic version source of truth: `application/config/version` in
`project.godot` (currently `0.7.0-alpha`). The Windows PE numeric quad lives in
`export_presets.cfg` (`application/file_version` / `product_version`,
`0.7.0.0`). `build/build_info.json` echoes the semantic version + commit at
export time. Keep the three in agreement; bump them together.

## 1. Required CI checks (green before anything else)

`.github/workflows/ci.yml` — all three jobs must pass on the release commit:

- **static** — `python scripts/ci/verify.py --static-only` (validators, asset
  audit, HUD-kit hashes, gear alignment, Capsule Doctor, wiki generation +
  drift + links, verifier/onboarding self-tests).
- **godot** — Linux/X11: import, source smoke, real export, exported-artifact
  smoke.
- **windows (ship target)** — Windows: import, source smoke, real export,
  launches `coheronia.exe` in smoke mode.

The verifier is fail-closed: a nonzero exit, a fatal marker (SCRIPT ERROR /
Compile / Parse / Nonexistent function), an **exit-time lifecycle leak**
(RID/ObjectDB/resource), an **unexpected Godot `ERROR` line** (outside the
named-test allowlist), a stale/foreign result, or an inconsistent result JSON
all fail even if the JSON says PASS.

## 2. Local full gate (mirror of CI, before tagging)

```
python scripts/ci/verify.py --godot <godot-bin> --export --export-preset "Windows Desktop"
```

Expect: source smoke green with **zero skips**; export smoke green with exactly
the six read-only `res://` fixture skips; `=== VERIFY PASS ===`; no leak/error
lines. (Linux export: same with `--export-preset "Linux/X11"` on Linux.)

## 3. Clean-profile boot

- Move/rename the user profile (`%APPDATA%/Godot/app_userdata/Coheronia`, or the
  platform equivalent) so the game starts with no saves.
- Launch the exported artifact. Confirm: character-creation shell → world entry,
  no errors in the log, HUD/onboarding goals present.

## 4. Save / world compatibility (non-mutating)

- Copy (never move) an existing `shell.json` and a `worlds/<id>.json` fixture
  into a scratch profile.
- Confirm the character carries between worlds and an existing world loads
  without a `gen_version`/`SAVE_VERSION` migration prompt. `gen_version` is **5**;
  v3/v4/v5 worlds must regenerate byte-identically (covered by the smoke
  `wg_gen_v3_v4_pinned_after_v5` / persistence checks — do not bump either
  version for a release).

## 5. Artifact smoke

- CI already launches the exported `.exe`/binary in smoke mode. For a manual
  spot check, run the exported artifact with `COHERONIA_SMOKE=1` and confirm the
  separate `export_smoke_results.json` reports PASS.

## 6. Version metadata

- `project.godot` `config/version`, `export_presets.cfg` file/product version,
  and the intended git tag agree (`0.7.0-alpha` / `0.7.0.0` / `v0.7-alpha`).
- `build/build_info.json` shows the expected `version` + release `commit`.

## 7. Changelog + known issues

- README changelog has a dated entry for the release with **actual** evidence
  (smoke totals from this run), not aspirational numbers.
- `docs/wiki/known_issues.md` reflects current deferred items (regenerate the
  wiki if data changed: `python scripts/wiki/generate_wiki.py`).

## 8. Tag / prerelease

- Only after **all** gates above are green:
  - `git tag -a v0.7-alpha -m "Coheronia v0.7-alpha"`
  - Push the tag; create a GitHub **prerelease** (mark "pre-release").
  - Attach the CI-built Linux + Windows artifacts (`coheronia`,
    `coheronia.exe`, `.pck`, `build_info.json`).

## 9. Rollback

- A prerelease is non-destructive: delete the GitHub release and
  `git push --delete origin v0.7-alpha` to retract. No user saves are affected
  (save format unchanged). If a bad commit reached `main`, revert forward with a
  new commit rather than rewriting history.

---

## Operator-only: recommended GitHub governance (document, do not apply here)

These are **not** applied by this checklist (GitHub-side settings need operator
action):

- **Branch protection on `main`:** require the `static`, `godot`, and `windows`
  status checks to pass; require at least one review; disallow force-push;
  require branches up to date before merge.
- **Required review:** at least one independent approval on every PR to `main`.
- **Linear history / no direct pushes to `main`** (optional but recommended for
  a clean release trail).
