# Project Ops Capsule Usage for Coheronia

Canonical capsule root:

```text
B:\Projects\LLM_Modules\Project_Ops_Capsule
```

Included fallback/reference copy:

```text
_protocol/Project_Ops_Capsule
```

## Constitutional rule

```text
Every run records evidence; only signable runs update accepted truth.
```

## Required closeout files

Every implementation run should update or create:

```text
.project/runs/<run-id>.md
.project/atlas_outbox/<run-id>.json
.project/boh_outbox/<run-id>.json
docs/HANDOFF.md
docs/VARIABLE_MATRIX.md
README.md if behavior/setup/status changed
```

## Atlas note

The user indicated this project already exists in Project Atlas MCP. Queue an outbox event for the existing project identity; do not create a new Atlas identity unless instructed.

Suggested project key:

```text
coheronia-game
```

## BOH note

BOH packets are evidence-only unless explicitly promoted by the operator.

## Git behavior

- Do not push automatically.
- Commit only after a signable run if the operator allows it.
- Do not claim accepted truth from unvalidated work.
