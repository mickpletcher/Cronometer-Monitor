# Generate Requirements For Cronometer Monitor

You are working in the `Cronometer-Monitor` repository, which is an existing PowerShell codebase that extracts Cronometer diary data from a live Chrome session by reading the rendered page through Chrome DevTools Protocol.

## Goal

Create or update a numbered spec package requirement document for a real repo change.

## Instructions

1. Inspect the current repo before writing requirements.
2. Anchor requirements to existing files such as `Invoke-CronometerMonitor.ps1`, `Start-ChromeDebug.ps1`, `README.md`, and `logs/`.
3. Preserve the current DOM based extraction path unless the requested change explicitly replaces it.
4. Distinguish current state facts from proposed behavior.
5. Write concrete and testable requirements.
6. Include non goals so the scope does not drift into browser automation, API reverse engineering, or packaging work unless requested.
7. Call out impacts on script behavior, logs, README, and local verification steps.

## Output Format

Update `specs/<NNN-name>/requirements.md` with:

1. Change summary
2. Current baseline
3. Numbered functional requirements
4. Numbered non functional requirements
5. Non goals
6. Acceptance signals

Do not include implementation details here.
