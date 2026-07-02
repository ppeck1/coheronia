# Project Ops Capsule Usage for Coheronia

Included capsule copy:

```text
_protocol/Project_Ops_Capsule
```

## Constitutional Rule

```text
Every run records evidence; only signable runs update accepted truth.
```

## Required Closeout Files

Every implementation run should update or create:

```text
.project/runs/<run-id>.md
.project/atlas_outbox/<run-id>.json
.project/boh_outbox/<run-id>.json
docs/HANDOFF.md
docs/VARIABLE_MATRIX.md
README.md if behavior/setup/status changed
```

## Validation

```powershell
python scripts/validate_repo.py
python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo
```

For gameplay verification:

```powershell
$env:COHERONIA_SMOKE = "1"
Start-Process -FilePath "<path-to-godot-4.6>" -ArgumentList @("--path", "<repo-root>") -Wait
```

The smoke test writes `user://smoke_results.json`. Windowed smoke runs also write `user://smoke_screenshot.png`.

## Atlas Note

Queue an outbox event for the existing project key:

```text
coheronia-game
```

## BOH Note

BOH packets are evidence-only unless explicitly promoted by the operator.

## Git Behavior

- Commit only after a signable run or explicit operator request.
- Push only on explicit operator request.
- Do not claim accepted truth from unvalidated work.
