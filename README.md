## 🪟 `new-task.ahk` — README.md

# new-task.ahk
AutoHotkey GUI tool for generating standardized project folders, nites templates, and supporting structure for content request workflows.

## Overview
`new-task.ahk` extends the same structured workflow concept as `newcase.sh`, but adapts it for users who prefer a graphical interface over command-line interaction.

It enables consistent project setup through a single input field, making the process accessible to non-technical users without sacrificing structure.

## What it does
- Prompts for a project/task name in a structured format:
####### | Task Title
- Automatically creates a project folder using that format
- Generates a notes file within the directory
- Builds a consistent folder structure for:
- Drafts
- Images
- Versions

## Example Input
1234567 | Add FAQ for Cancellations
creates:
```
C:\Projects\2025-05\1234567 | Add FAQ for Cancellations
├── Drafts
├── Images
├── Versions
└── 1234567_notes.txt
```
## Why it exists
Not all users are comfortable working in a terminal.

This tool provides the same structured workflow benefits as the Bash version, but in a format that:
- Reduces cognitive load
- Removes the need to remember commands
- Encourages consistent naming and organization

## How to use
1. Run the script (`.ahk` file)
2. Enter your project/task name in the required format
3. Click **OK**
4. The directory and files are created automatically

## Requirements
- Windows OS
- AutoHotkey installed

## Notes
- Designed for content and documentation workflows
- Enforces naming consistency through input format
- Can be adapted for different directory structures or file types

## Relationship to newcase.sh
This tool was created as a GUI-based counterpart to `newcase.sh`, translating the same workflow principles into a more accessible interface for broader audiences.

## License
MIT
