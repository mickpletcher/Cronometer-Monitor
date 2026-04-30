# Cronometer Monitor Build Prompt

I am building a PowerShell script to monitor my personal nutrition and diary data from Cronometer (cronometer.com) after authenticating with my credentials. Here is the context and progress so far:

## Background

- Cronometer is a React/JavaScript SPA (single-page application)
- Raw HTTP requests will not return rendered diary data
- All diary data is loaded via XHR/fetch calls to a backend API (likely GraphQL at something like /api/cronometer/v2/graphql)
- I have confirmed basic PowerShell web requests work — Invoke-WebRequest successfully returns the public page

## What I Need the Script to Do

1. Authenticate to cronometer.com using my credentials and capture the session cookie
2. Intercept or replicate the API call that returns my daily diary data (calories, macros, nutrients)
3. Parse the response and extract key nutrition metrics
4. Compare current values against target thresholds (e.g. alert if protein is below goal)
5. Log all activity using CMTrace-compatible logging format
6. Output results in a structured format suitable for downstream use (n8n webhook, daily summary, or console output)

## PowerShell Requirements

- Use CmdletBinding and comment-based help with === separator lines
- Wrap all external calls in try/catch
- Use approved PowerShell verbs
- Include Functions and Main regions
- CMTrace-compatible log output
- Use Invoke-RestMethod for API calls
- Use a WebRequestSession object to persist the auth cookie across requests

## Credential Handling

- Accept credentials interactively using Get-Credential if no credentials file is present
- If a credentials file exists (encrypted with Export-Clixml / Import-Clixml), load from that
- On first run, prompt with Get-Credential, then ask the user if they want to save credentials to an encrypted file for future runs
- Never hardcode credentials in the script

## Known Technical Details

- Login endpoint is likely a POST to <https://cronometer.com/login> with JSON body containing username and password
- After login, session cookie must be passed to all subsequent API requests using -WebSession
- The diary API is likely GraphQL — the query will need to request fields for date, calories consumed, protein, carbohydrates, fat, and any other tracked nutrients
- The script should accept date as a parameter (default to today)

## Next Steps Needed from Codex

1. Write the full PowerShell script based on the above requirements
2. Include a placeholder GraphQL query that targets daily diary totals — I will refine the query fields once I intercept the actual API call from DevTools
3. Include a section that dumps the raw API response to a log file on first run so I can inspect the actual response schema
4. Make credentials accept input as parameters or from a credentials file — do not hardcode them

## Environment

- Windows 11
- PowerShell 5.1 or 7.x
- No third-party modules — native PowerShell only
