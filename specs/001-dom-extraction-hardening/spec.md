# 001 DOM Extraction Hardening Spec

## Scope

This spec package defines repo level process scaffolding plus the target direction for the next implementation cycle. It does not yet change runtime behavior in `Invoke-CronometerMonitor.ps1`.

## Current Implementation Summary

1. The script reads diary totals from a live Cronometer page through CDP `Runtime.evaluate`.
2. The extractor depends on selectors such as `.diary-date-btn` and `table.targets-table`.
3. Empty or changed DOM results currently surface as `NoDataFound` or degraded output without enough structure to explain why.

## Proposed Design

1. Add repo specific GitHub Spec scaffolding so future work follows a repeatable `requirements -> spec -> plan -> tasks -> implementation -> audit -> regression test` flow.
2. Establish `001-dom-extraction-hardening` as the first numbered package for this repo.
3. Treat a future hardening change as focused on:
   1. explicit page readiness checks
   2. selector presence validation
   3. clearer output and logging for missing date controls, nutrient tables, or malformed rows
   4. fixture friendly conversion testing where live browser access is not required

## File Impact

1. `.github/copilot-instructions.md` defines repo specific delivery rules.
2. `.github/prompts/*.prompt.md` provides reusable prompt entry points for the spec flow.
3. `.github/workflows/ci.yml` adds parse and analyzer checks for PowerShell scripts.
4. `docs/repo-audit.md` documents the current repo shape and retrofit rationale.
5. `specs/001-dom-extraction-hardening/*` becomes the anchor for the next substantive implementation.
6. `README.md` points future work at the spec process.

## Verification Strategy

1. Confirm all scaffold files exist in the expected locations.
2. Parse the workflow YAML and Markdown visually.
3. Run local PowerShell parse validation across `.ps1` files after the scaffold lands.

## Risks And Open Questions

1. ScriptAnalyzer may report findings in existing scripts that predate this retrofit.
2. A future selector hardening change will still require a live Cronometer smoke test.
3. `PLAN.md` and `ANALYSIS.md` remain historical until they are refreshed or archived.
