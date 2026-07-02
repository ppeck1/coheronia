# SIGNABLE Gate

A run may end SIGNABLE only if all required items are PASS or explicitly NOT_CHECKED with a structured override.

| Gate Item | Result | Evidence |
|---|---|---|
| Repo identity verified | PASS/FAIL/NOT_CHECKED |  |
| Branch and commit recorded | PASS/FAIL/NOT_CHECKED |  |
| Dirty state classified | PASS/FAIL/NOT_CHECKED |  |
| Scope recorded | PASS/FAIL/NOT_CHECKED |  |
| Diff matches scope | PASS/FAIL/NOT_CHECKED |  |
| Protected paths preserved | PASS/FAIL/NOT_CHECKED |  |
| Validation run or justified | PASS/FAIL/NOT_CHECKED |  |
| README audited or updated | PASS/FAIL/NOT_CHECKED |  |
| Variable matrix audited or updated | PASS/FAIL/NOT_CHECKED |  |
| Handoff updated | PASS/FAIL/NOT_CHECKED |  |
| Run ledger created | PASS/FAIL/NOT_CHECKED |  |
| Atlas event or outbox written | PASS/FAIL/NOT_CHECKED |  |
| BOH packet or outbox written when enabled | PASS/FAIL/NOT_CHECKED |  |
| Git closeout recorded | PASS/FAIL/NOT_CHECKED |  |
| Remaining risks documented | PASS/FAIL/NOT_CHECKED |  |

