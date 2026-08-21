# new-task.ahk — Alpine New Ticket Tool

AutoHotkey tool for generating standardized ticket folders, notes templates, and supporting directories for technical support workflows.

## Overview

`new-task.ahk` provides a lightweight, repeatable way to create a working directory for a new support ticket.

This Alpine version is derived from the original `new-task.ahk` project workflow tool, but has been adapted for Zendesk-based application support work.

With a single ticket entry, the script creates a consistently named ticket directory, a preformatted notes file, and supporting folders for logs, images, and other files collected during investigation.

## What It Does

- Runs from the keyboard with **Ctrl+Alt+N**
- Prompts for a ticket ID and optional subject
- Accepts ticket names in a format such as:

  ```text
  67157 - SQL Syntax Error when saving Drill
  ```

- Creates a month-based ticket directory
- Creates a ticket-specific working folder
- Generates a ticket notes file
- Creates supporting folders for:
  - `Logs`
  - `Etc`
  - `Images`
- Provides a standardized notes template containing fields such as:
  - Ticket ID
  - Zendesk URL
  - Project Owner
  - Organization
  - Requester
  - Form
  - Phone Call status
  - Other investigation notes
- Sanitizes characters that cannot be used in Windows filenames
- Maintains configuration and debug logging under the user's AppData directory
- Automatically backs up and repairs its configuration file when necessary

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

The parent month folder is generated automatically using the current year and month.

## Notes Template

Each ticket receives a text file containing a basic investigation template:

```text
Ticket ID: 67157 - SQL Syntax Error when saving Drill

Zendesk URL: [Zendesk Ticket URL]

Project Owner: <Windows Username>

Org:

Requester:

Form:

Phone Call? (Y/N):

----------

Other Notes:
[Use this space for anything not covered above.]
```

The template is intended to provide a quick place for investigation notes, SQL findings, log observations, troubleshooting steps, and other information gathered while working the ticket.

## Configuration

User configuration is stored in:

```text
%APPDATA%\HotKeys\NewTask\NewTask.ini
```

The configuration currently includes settings such as:

- Base ticket storage directory
- Post-creation behavior
- Editor configuration
- Debug mode
- Configuration version

The script verifies the INI at startup and repairs missing configuration keys when possible.

Existing INI files are backed up before verification or modification.

## Debug Logging

A hidden debug-mode toggle is available with:

```text
Ctrl+NumpadMinus
```

Debug information is written to:

```text
%APPDATA%\HotKeys\NewTask\NewTask_debug.log
```

The log is automatically reset if it grows beyond its configured size limit.

## How to Use

1. Run `new-task.ahk`.
2. On first use, select the directory where ticket folders should be stored.
3. Press **Ctrl+Alt+N**.
4. Enter the ticket ID and optional subject.
5. Click **OK**.
6. The ticket directory, notes file, and supporting folders are created automatically.

## Requirements

- Windows
- AutoHotkey **v1.1**

This version of the script has not yet been migrated to AutoHotkey v2.

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

## Planned Development

Future work for the Alpine version includes improvements to the notes workflow and migration to AutoHotkey v2.

Potential future note types may include Word and OneNote-based workflows. These are not implemented in the current version.

## License

MIT
