# Cronometer Monitor Analysis

**Date:** 2026-04-29
**Script:** `Invoke-CronometerMonitor.ps1`

---

## Summary

This project is a PowerShell script that authenticates to Cronometer, queries the diary API for daily nutrition data, compares values against user-defined goals, and logs everything in CMTrace format. The architecture is complete and production-quality. The only blocker is that the GraphQL endpoint URL is a placeholder that returns 404. The login step works correctly.

---

## Current Status

| Component | Status |
| --- | --- |
| CMTrace logging | Working |
| Credential handling (parameter, file, interactive) | Working |
| Session creation and cookie capture | Working |
| Login POST to `https://cronometer.com/login` | Working (2 cookies captured) |
| GraphQL diary request | Failing (404) |
| Response parsing | Not yet reachable |
| Goal comparison and alert generation | Not yet reachable |

The login reliably completes and captures two session cookies. Every run fails at the diary request because `https://cronometer.com/api/cronometer/v2/graphql` does not exist.

---

## Root Cause: Wrong GraphQL Endpoint

The 404 error is consistent across all test runs. The `CronometerErrorResponse.txt` file contains a rendered HTML 404 page from the Cronometer web app, confirming the URL resolves to a route that doesn't exist on the server.

The real API endpoint needs to be captured from a live browser session using DevTools (Network tab). Steps:

1. Log in to cronometer.com in Chrome or Firefox.
2. Open DevTools, go to the Network tab, filter by Fetch/XHR.
3. Navigate to the diary view for any date.
4. Identify the GraphQL or API request that returns diary data.
5. Capture the full URL, method, headers, and request body.
6. Update `Invoke-CronometerDiaryRequest` and `Get-CronometerDiaryQueryDefinition` accordingly.

Cronometer may use a different base path (e.g., `/graphql`, `/api/graphql`, or a completely different REST endpoint). The app may also require CSRF tokens or additional headers not currently sent.

---

## Bug: Disposed HttpContent in PS7 Error Extraction

In `Get-CronometerErrorDetail`, the code attempts to call `$response.Content.ReadAsStringAsync()` after `Invoke-RestMethod` has already disposed the `HttpConnectionResponseContent`. This is a PowerShell 7 behavior where the response content stream is consumed by the cmdlet before the catch block runs.

The log shows:

```text
Could not extract HTTP response details. Exception calling "ReadAsStringAsync" with "0" argument(s): "Cannot access a disposed object."
```

The existing `ErrorDetails.Message` fallback on line 245 saves the situation in some runs but not reliably across PS versions. To fix this properly, the error body should be captured using `$_.ErrorDetails.Message` immediately in the catch block and not rely on reading the response stream.

Suggested fix in `Get-CronometerErrorDetail`:

```powershell
# Replace the Content.ReadAsStringAsync() branch with:
if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
    $responseBody = $ErrorRecord.ErrorDetails.Message
}
```

The `GetResponseStream` path handles PS5.1 correctly, so keep that. Remove the `hasContentProperty` branch that calls `ReadAsStringAsync` since it will always fail in PS7 after `Invoke-RestMethod` disposes the content.

---

## Architecture Review

The script structure is solid.

**Strengths:**

- Clean separation of concerns. Each function has a single responsibility.
- CMTrace logging is correctly formatted and includes timestamp, thread, context, and severity.
- Credential handling covers all three cases (parameter, encrypted file, interactive prompt) with a save option on first interactive use.
- `Get-CronometerMetricValue` safely coerces nullable values with a configurable default.
- `ConvertFrom-CronometerDiaryResponse` degrades gracefully if the path `data.diary.totals` is missing, logging a warning and returning zeros rather than throwing.
- `Save-CronometerRawResponse` respects the `ForceRawDump` switch and skips overwriting if the file already exists.
- `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` enforce clean error propagation.

**Weaknesses:**

- The GraphQL query at line 418 is a placeholder. The field names (`diary`, `totals`, `nutrients`) are assumed. They will likely need to match Cronometer's actual schema exactly.
- No timeout is set on `Invoke-RestMethod` calls. A hung connection will block indefinitely.
- The script logs the credential file path but not whether credentials were valid (login success vs. cookie presence). Two cookies does not confirm a valid authenticated session. The login response body is discarded.
- No retry logic on transient network failures.

---

## Parameters and Defaults

| Parameter | Default | Notes |
| --- | --- | --- |
| `Date` | Today's date | Accepts any `[datetime]` |
| `Credential` | None | PSCredential object |
| `CredentialPath` | `%APPDATA%\CronometerMonitor\cronometer.credential.xml` | Auto-created on save |
| `LogPath` | `<script dir>\logs\CronometerMonitor.log` | Directory auto-created |
| `RawResponsePath` | `<script dir>\logs\CronometerDiaryRawResponse.json` | |
| `ErrorResponsePath` | `<script dir>\logs\CronometerErrorResponse.txt` | |
| `ForceRawDump` | Off | Forces overwrite of raw response file |
| `ProteinGoalGrams` | 150 | Alert fires if below this |
| `CalorieGoal` | 2200 | Alert fires if below this |
| `CarbohydrateGoalGrams` | 200 | Alert fires if below this |
| `FatGoalGrams` | 70 | Alert fires if below this |

---

## Output Object Structure

When the diary request succeeds and parses correctly, `Start-CronometerMonitor` returns a `PSCustomObject` with:

```text
Date                 string    yyyy-MM-dd
Calories             double
ProteinGrams         double
CarbohydratesGrams   double
FatGrams             double
Goals                object    { Calories, ProteinGrams, CarbohydratesGrams, FatGrams }
Alerts               string[]  One entry per macronutrient below goal
Nutrients            object[]  { Name, Unit, Value } per micronutrient
RawDataPath          string    Path to the saved raw response
ResponseSchemaHint   string    Documents expected path for troubleshooting
QueryStatus          string    'Parsed' or 'SchemaNeedsRefinement'
```

This is well-structured for downstream use in n8n, scheduled tasks, or daily summary reports.

---

## Next Steps

1. Capture the real diary API request from browser DevTools and update the endpoint and GraphQL query.
2. Fix the `ReadAsStringAsync` disposed-object bug in `Get-CronometerErrorDetail`.
3. Add `-TimeoutSec` to both `Invoke-RestMethod` calls.
4. Validate the login response body to confirm authenticated state rather than relying on cookie count.
5. Once the endpoint is confirmed working, wire the output to a notification channel (n8n webhook, email, or Windows toast).
