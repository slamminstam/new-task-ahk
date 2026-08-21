# New Ticket Tool — Manual Regression Baseline

Use disposable AppData and ticket directories. Never run migration or failure tests against live `%APPDATA%\HotKeys\NewTask` data or a real ticket store.

## Fresh setup

### First-run defaults

- **Preconditions:** No test `NewTask.ini`; disposable AppData path.
- **Action:** Start the script.
- **Expected:** AppData and backup folders are created; Settings opens once with Notes and Windows-default editor selected; no ticket prompt appears.

### First-run cancellation and completion

- **Preconditions:** First-run Settings is open.
- **Action:** Cancel, press Escape, or close with X; then press Ctrl+Alt+N. Repeat and save once with a valid disposable ticket directory.
- **Expected:** Each cancellation writes no UI selections and creates no ticket. Ctrl+Alt+N reopens required setup. Save persists all settings and later Ctrl+Alt+N opens the ticket prompt.

## Existing configuration migration

For each case, copy the INI into disposable AppData, start once, and inspect the resulting INI and debug log.

| Preconditions | Action | Expected result |
|---|---|---|
| `configVersion=1.1`, `openOnCreate=true`, no `openTarget` | Start script | `openTarget=notes`, config version 1.2, migration logged. |
| `configVersion=1.1`, `openOnCreate=false`, no `openTarget` | Start script | `openTarget=none`. |
| `editorPath=notepad`, no `editorMode` | Start script | `editorMode=default`, blank `editorPath`. |
| Meaningful custom `editorPath`, no `editorMode` | Start script | `editorMode=custom`, path preserved. |
| Missing config version or known key | Start script | Known value is safely repaired; unrelated keys remain. |
| Invalid `openTarget` or `editorMode` | Start script | Safe known value is persisted and used at runtime. |
| `editorMode=custom` with blank path | Start script | Repaired to Windows-default mode with blank path. |
| Valid config version 1.2 | Start script | Valid values and unrelated keys remain unchanged. |
| Config version newer than 1.2 | Start script | Version is not downgraded. |

For every existing INI case, confirm a timestamped backup is made. With more than ten backups, confirm only the ten newest remain.

## Settings GUI

### Saved values and radio groups

- **Preconditions:** Configured test installation.
- **Action:** Open **New Ticket Settings...** from the tray; test each open-target choice and both editor modes, saving and reopening after each.
- **Expected:** The two radio groups remain independent; exactly one option in each is selected; reopened values match the saved INI and runtime behavior.

### Browse, validation, and cancellation

- **Preconditions:** Settings open with known saved values.
- **Action:** Browse for a base directory and custom `.exe`; try a missing directory, directory-as-editor, missing editor, and non-`.exe`; edit controls and Cancel.
- **Expected:** Browse updates only the UI and selecting an editor selects custom mode. Invalid values cannot save. Cancel/Escape/X preserve the prior INI and runtime values.

### Write failure

- **Preconditions:** Disposable INI made temporarily unwritable; Settings open.
- **Action:** Save valid changed values.
- **Expected:** Runtime globals are not updated, the GUI stays open, the failure message describes restoration status, and the debug log records the failure without sensitive details.

## Ticket creation and notes template

### New ticket

- **Preconditions:** Valid disposable base directory; `openTarget=none`.
- **Action:** Press Ctrl+Alt+N and enter `12345 - Stage 2 Test`.
- **Expected:** `yyyy-MM\12345 - Stage 2 Test` contains `Logs`, `Etc`, `Images`, and `12345 - Stage 2 Test_notes.txt`. Ticket naming and sanitization are unchanged.

### Revised notes content

- **Preconditions:** Newly created notes file.
- **Action:** Open the file and inspect the template.
- **Expected:** It contains Ticket Folder with the exact generated path; Ticket Owner resolves to the current Windows username; and all sections appear: Issue / Request, Impact, Environment / Context, Time(s) Observed, Reproduction / Verification, Investigation / Findings, Actions Taken, Current Status / Blocker, Next Step, and Other Notes.

### Validation and sanitization

- **Preconditions:** Configured test installation.
- **Action:** Try an entry without five digits, then a valid entry containing the same Windows-invalid characters covered by the existing sanitizer.
- **Expected:** Invalid ID is rejected; valid ID is accepted; sanitized folder and notes names follow existing behavior.

## Open-target and editor behavior

Repeat with paths containing spaces, parentheses, ampersands, hyphens, and a long reasonable name.

| Preconditions | Action | Expected result |
|---|---|---|
| `openTarget=notes` | Create/reopen ticket | Notes only opens. |
| `openTarget=folder` | Create/reopen ticket | Folder only opens. |
| `openTarget=both` | Create/reopen ticket | Folder opens first; notes open second. |
| `openTarget=none` | Create/reopen ticket | Nothing opens. |
| `editorMode=default` | Open notes | Windows handles the `.txt` association. |
| Valid custom editor, including a path with spaces | Open notes | Editor receives the notes path as one argument. |
| Configured editor later removed | Open notes | Ticket remains; warning names tray Settings; default app fallback is attempted; failure is logged. |
| Default association cannot open notes | Open notes | Ticket remains and launch failure is logged. |

## Existing ticket handling

- **Preconditions:** Existing ticket folder with populated supporting folders and edited notes; optionally remove one supporting folder.
- **Action:** Run ticket creation again with the same ticket name.
- **Expected:** Existing notes and supporting content are untouched; missing supporting folders are recreated; no stale `ErrorLevel` failure appears; saved post-create opening still runs against the existing notes file.

## Failure cases and debug logging

- **Preconditions:** Disposable locations that can be made unwritable or unavailable; test once with debug disabled and once enabled.
- **Action:** Exercise folder creation, notes creation, invalid settings, missing editor, and launch failures; toggle debug with Ctrl+NumpadMinus.
- **Expected:** Failures never delete a completed ticket; forced operational failures are logged; ordinary debug detail follows debug mode; the toggle persists; and a log over 1 MiB resets as before.

