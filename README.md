# new-task.ahk — Alpine New Ticket Tool

AutoHotkey v1.1 tool for generating standardized ticket folders, investigation notes, and supporting directories for technical-support workflows.

## Overview

`new-task.ahk` provides a lightweight, repeatable way to create a working directory for a support ticket. This Alpine version is derived from the original `new-task.ahk` project workflow tool and has been adapted for Zendesk-based application support.

With one ticket entry, the script creates a consistently named ticket directory, a plain-text notes file, and supporting folders for logs, images, and other investigation files.

## What It Does

- Runs ticket creation with **Ctrl+Alt+N**.
- Prompts for a five-digit ticket ID and optional subject, such as `67157 - SQL Syntax Error when saving Drill`.
- Creates a `yyyy-MM` month directory and a ticket-specific working folder.
- Creates `Logs`, `Etc`, and `Images` supporting folders.
- Generates `<sanitized ticket name>_notes.txt` without replacing an existing notes file.
- Sanitizes characters that cannot be used in Windows filenames.
- Opens the generated notes by default after creation.
- Can instead open the ticket folder, both notes and folder, or nothing.
- Uses the Windows default `.txt` application by default, with an optional custom editor executable.
- Maintains configuration, backups, repair/migration behavior, and debug logging under the user's AppData directory.

## Example

Entering:

```text
67157 - SQL Syntax Error when saving Drill
```

creates a structure similar to:

```text
C:\Tickets\2026-08\
└── 67157 - SQL Syntax Error when saving Drill
    ├── Logs
    ├── Etc
    ├── Images
    └── 67157 - SQL Syntax Error when saving Drill_notes.txt
```

## Notes Template

New notes files use a general support-investigation structure. The header records the ticket ID, actual ticket-folder path, Zendesk URL, current Windows user as Ticket Owner, organization, requester, form, and phone-call status.

The investigation body separates:

- Issue / Request and Impact
- Environment / Context and Time(s) Observed
- Reproduction / Verification
- Investigation / Findings
- Actions Taken
- Current Status / Blocker
- Next Step
- Other Notes

This keeps reported behavior, evidence, actions, and handoff state distinct without adding product-specific permanent fields. The revised template is used only when a notes file is new; existing ticket notes are never rewritten.

## First Run and Settings

On first run, **New Ticket Settings** requests:

- Ticket storage folder
- What to open after ticket creation: Notes, Ticket Folder, Notes and Ticket Folder, or Nothing
- Notes editor: the Windows default `.txt` application or a specific `.exe`

The default workflow is to open the generated notes file using the Windows file association. When both targets are selected, the ticket folder opens first and notes open second.

Settings can be changed later from the standard AutoHotkey system-tray menu using **New Ticket Settings...**. Saving applies changes immediately; Cancel, Escape, or closing the window discards unsaved UI changes.

## Configuration

User configuration is stored in:

```text
%APPDATA%\HotKeys\NewTask\NewTask.ini
```

Version 1.13.0 uses configuration schema 1.2, including:

```ini
[NewTask]
baseDir=
openTarget=notes
editorMode=default
editorPath=
```

The script verifies the INI at startup, migrates supported v1.1 settings, repairs missing or invalid known values, and preserves unrelated keys. Existing INI files are backed up before verification or modification, with the ten newest backups retained.

## Debug Logging

Toggle debug mode with:

```text
Ctrl+NumpadMinus
```

Debug information is written to:

```text
%APPDATA%\HotKeys\NewTask\NewTask_debug.log
```

The log resets when it exceeds its configured size limit.

## How to Use

1. Install AutoHotkey v1.1 and run `new-task.ahk`.
2. Complete the first-run Settings window.
3. Press **Ctrl+Alt+N**.
4. Enter the ticket ID and optional subject.
5. The ticket directory, notes file, and supporting folders are created; the saved post-create preference is then applied.

## Requirements and Scope

- Windows
- AutoHotkey **v1.1**
- Plain-text (`.txt`) notes

Word and OneNote workflows are future possibilities and are not implemented. Migration to AutoHotkey v2 is planned but has not begun in this release.

## Project Lineage

This branch is an Alpine-specific offshoot of the original `new-task.ahk` project.

The original version was designed for structured content and documentation work and used project identifiers, Adobe Workfront references, and folders such as `Drafts` and `Versions`.

The Alpine version preserves the same core workflow concept while adapting it for technical support:

```text
Original workflow
Project / task
├── Drafts
├── Images
├── Versions
└── Project notes
```

became:

```text
Alpine workflow
Support ticket
├── Logs
├── Etc
├── Images
└── Ticket notes
```

Development of the Alpine version continues independently while retaining the original project's history and design principles.

## Testing

See [TESTING.md](TESTING.md) for the reusable v1.13 regression baseline.

## License

MIT

