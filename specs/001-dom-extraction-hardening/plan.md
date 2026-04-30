# 001 DOM Extraction Hardening Plan

## Phase 1

Create the repo level scaffold.

1. Add `.github/copilot-instructions.md`.
2. Add prompt files for requirements, spec, plan, tasks, implementation, audit, fixes, and regression testing.
3. Add a minimal GitHub Actions workflow for parse and analyzer checks.

## Phase 2

Create the baseline documentation package.

1. Add `docs/repo-audit.md`.
2. Add the numbered spec package under `specs/001-dom-extraction-hardening/`.
3. Update `README.md` so future work starts from the spec flow.

## Phase 3

Run low risk validation.

1. Parse all repo PowerShell scripts locally.
2. Review the new Markdown and workflow files for path or naming mistakes.
3. Record any remaining verification gaps that need a live Cronometer session.
