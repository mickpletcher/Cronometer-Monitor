## Updated Project Direction

The script should not start by logging in with Cronometer credentials.

Instead, the project should interface with an already logged in Chrome browser session and extract nutrition data from the active Cronometer session.

## New Primary Goal

Build a PowerShell based automation tool that can connect to an existing authenticated Chrome session, read Cronometer diary data, and extract:

- Foods already consumed today
- Calories consumed
- Calories remaining
- Protein consumed and remaining
- Carbs consumed and remaining
- Fat consumed and remaining
- Fiber
- Sodium
- Potassium
- Vitamins and minerals
- Any other visible daily nutrition totals available in Cronometer

## Browser Session Requirement

The tool should support using an already logged in Chrome profile instead of storing Cronometer credentials.

Preferred approach:

1. Launch Chrome with remote debugging enabled
2. Use the existing Chrome user data profile where Cronometer is already logged in
3. Use PowerShell to connect to Chrome DevTools Protocol
4. Read the current Cronometer page DOM or intercept network responses
5. Extract diary and nutrition data from the rendered session

Example Chrome launch pattern:

```powershell
chrome.exe `
  --remote-debugging-port=9222 `
  --user-data-dir="$env:LOCALAPPDATA\Google\Chrome\User Data"