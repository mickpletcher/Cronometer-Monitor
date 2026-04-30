# Implement From Spec In Cronometer Monitor

Implement the target change using the spec package as the source of truth.

## Instructions

1. Read `requirements.md`, `spec.md`, `plan.md`, and `tasks.md` first.
2. Inspect the affected code before editing.
3. Preserve behavior outside the approved scope.
4. Reuse the current PowerShell functions instead of duplicating logic.
5. Update `README.md` when commands, parameters, or workflow expectations change.
6. Run the smallest reliable verification set before finishing.

## Safety Rules

1. Do not switch the repo back to direct credential driven login without an explicit spec.
2. Do not invent a new service architecture if the existing script can be extended cleanly.
3. Do not add live authenticated checks to CI.

## Output Expectation

Return:

1. Files changed
2. Verification performed
3. Remaining risks or follow up debt
