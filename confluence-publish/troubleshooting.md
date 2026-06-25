# Troubleshooting

## Browser is on the login page

**Symptom**: `Browser is on the login page. Log in first, then rerun the command.`

**Fix**: Re-run with `--open-browser --wait-login`, then complete login manually in the Chrome window. The session is saved to `--profile-dir` (default `./chrome-profile-confluence`), so subsequent runs skip login.

## TinyMCE editor not found

**Symptom**: `Timed out waiting for Confluence editor. Last state: ...`

**Causes**:
- Page hasn't fully loaded. Increase timeout or retry.
- Confluence redirected to a different page (e.g., license error, permission denied).
- The URL is not a `createpage.action` URL.

**Fix**: Verify the `--url` is correct and the user has page-creation permission in the target space.

## Publish button not found

**Symptom**: `Publish button not found`

**Cause**: The Confluence editor DOM differs from expected. This skill targets Confluence 6.x with TinyMCE. Newer Confluence versions (7.12+ with the new editor) may use a different publish button selector.

**Fix**: Inspect the page DOM and update the `#rte-button-publish` selector in `build_injection_js()`.

## Publish fails with HTTP error

**Symptom**: `responseStatus: 400` or similar in the JSON output.

**Causes**:
- `spaceKey` or `fromPageId` missing from the URL.
- Title contains characters Confluence rejects.
- Page title already exists in the space (Confluence requires unique titles within a space).

**Fix**: Check `responseJson.message` for the specific error. Ensure the title is unique and the URL has both `spaceKey` and `fromPageId`.

## Unicode characters break the editor

**Symptom**: Page content looks corrupted or TinyMCE fails to save.

**Fix**: The script auto-strips problematic Unicode ranges. If new characters cause issues, add them to `strip_problem_unicode()` ranges in `publish_confluence_html.py`.

## Chrome CDP port already in use

**Symptom**: Chrome starts but `agent-browser` cannot connect, or a stale Chrome instance is running.

**Fix**: The script calls `stop_chrome_on_port()` before starting. If that fails, manually kill Chrome processes:

```powershell
Get-CimInstance Win32_Process -Filter "name = 'chrome.exe'" |
  Where-Object { $_.CommandLine -like '*--remote-debugging-port=9223*' } |
  Stop-Process -Force
```

## agent-browser not found

**Symptom**: `Command failed: powershell.exe -NoProfile -Command "agent-browser ..."` with a "not recognized" error.

**Fix**: Install `agent-browser` on Windows and ensure it is on the system PATH. Verify with:

```powershell
agent-browser --version
```

## beautifulsoup4 missing

**Symptom**: `Missing Python package: beautifulsoup4`

**Fix**:

```bash
pip install beautifulsoup4
```

## Host resolver not working

**Symptom**: Chrome opens but cannot reach the Confluence host.

**Cause**: The `--host-resolver` flag maps a hostname to an IP, but the Confluence server may use HTTPS or a different port.

**Fix**: Ensure the `--host-resolver` value matches the host in `--url`. For example:

```bash
--url "http://wiki.internal:8888/..." --host-resolver "MAP wiki.internal 10.0.0.1"
```
