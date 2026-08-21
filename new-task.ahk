;==============================================================================
; New Ticket Tool
;==============================================================================
; Version: 1.13.0
; Standalone AHK v1.1 script
;==============================================================================

#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

;------------------------------------------------------------------------------
; Global Paths / Runtime Settings
;------------------------------------------------------------------------------
global appDataFolder := A_AppData "\HotKeys\NewTask"
global backupFolder := appDataFolder "\OldConfigs"
global iniFile := appDataFolder "\NewTask.ini"
global logFile := appDataFolder "\NewTask_debug.log"
global missingKeys
global debugMode := 0
global baseDir := ""
global openTarget := "notes"
global editorMode := "default"
global editorPath := ""
global settingsDialogResult := "cancel"
global settingsIsFirstRun := false

;------------------------------------------------------------------------------
; Startup
;------------------------------------------------------------------------------
EnsureAppFoldersExist()
VerifyOrInitializeINI()
LoadDebugMode()
LoadRuntimeSettings()
InitializeTrayMenu()

if (baseDir = "")
    ShowSettings(true)

;------------------------------------------------------------------------------
; Hotkeys
;------------------------------------------------------------------------------
^!n::NewTicketRunner("NewTask")      ; Ctrl+Alt+N
^NumpadSub::ToggleDebugMode()        ; Ctrl+NumpadMinus (hidden/power user)

return


;==============================================================================
; GUI / Tray Labels
;==============================================================================

OpenSettingsFromTray:
ShowSettings(false)
return

SettingsBrowseBaseDir:
BrowseForBaseDirectory()
return

SettingsBrowseEditor:
BrowseForEditor()
return

SettingsEditorModeChanged:
UpdateEditorControls()
return

SettingsSave:
SaveSettings()
return

SettingsCancel:
SettingsGuiClose:
SettingsGuiEscape:
settingsDialogResult := "cancel"
Gui, Settings:Destroy
return


;==============================================================================
; Main Functions
;==============================================================================

;------------------------------------------------------------------------------
; Function: New Ticket Tool - Build Folder Structure for each new Ticket
;------------------------------------------------------------------------------
NewTicketRunner(section := "NewTask") {
    global iniFile
    global baseDir

    ; Runtime settings are loaded centrally so tray changes apply immediately.
    if (baseDir = "") {
        if !ShowSettings(true)
            return
    }

    ; Preserve existing configuration reads used by the ticket workflow.
    IniRead, taskFile, %iniFile%, %section%, taskFile, notes.txt
    IniRead, taskPrefix, %iniFile%, %section%, taskPrefix, Task

    ; === Prompt for Ticket ID ===
    InputBox, taskName, Ticket ID, Enter the Ticket ID:`nFormat: 12345 - Optional Subject,, 600, 150
    if (ErrorLevel or taskName = "") {
        MsgBox, 48, Error, No ticket ID provided. Exiting.
        return
    }

    ; === Validate Format ===
    if !RegExMatch(taskName, "^\s*.*\d{5}.*$") {
        MsgBox, 48, Error, Invalid format.`n`nMust match: ##### - Optional Subject
        return
    }

    ; === Sanitize File Name ===
    sanitizedTaskName := ""
    Loop, Parse, taskName
    {
        char := A_LoopField
        if InStr("<>:/|?*", char)
            sanitizedTaskName .= "_"
        else
            sanitizedTaskName .= char
    }

    DebugLog("Sanitized Task Name: " . sanitizedTaskName)

    ; === Build Paths ===
    FormatTime, currentMonth,, yyyy-MM
    projectDir := baseDir "\" currentMonth
    taskDir := projectDir "\" sanitizedTaskName

    DebugLog("Project directory: " . projectDir)
    DebugLog("Ticket directory: " . taskDir)

    ; === Create Folders ===
    dirList := projectDir . "`n" . taskDir
    Loop, Parse, dirList, `n, `r
    {
        if !FileExist(A_LoopField) {
            FileCreateDir, %A_LoopField%
            if !FileExist(A_LoopField) {
                MsgBox, 48, Error, Failed to create:`n%A_LoopField%
                DebugLog("Failed to create directory: " . A_LoopField, true)
                return
            }
        }
    }

    ; === Build Notes Filename ===
    notesFile := taskDir "\" sanitizedTaskName "_notes.txt"

    ; === Create Supporting Subfolders ===
    logsDir := taskDir "\Logs"
    otherDir := taskDir "\Etc"
    imagesDir := taskDir "\Images"

    subdirs := logsDir . "`n" . otherDir . "`n" . imagesDir
    Loop, Parse, subdirs, `n, `r
    {
        if !FileExist(A_LoopField) {
            FileCreateDir, %A_LoopField%
            if !FileExist(A_LoopField) {
                MsgBox, 48, Error, Failed to create:`n%A_LoopField%
                DebugLog("Failed to create subdirectory: " . A_LoopField, true)
                return
            }
        }
    }

    ; === Create Notes File ===
    notesFileExisted := FileExist(notesFile)
    if (!notesFileExisted) {
        FileAppend,
(
Ticket ID: %taskName%

Ticket Folder: %taskDir%

Zendesk URL: [Zendesk Ticket URL]

Ticket Owner: %A_Username%

Org:

Requester:

Form:

Phone Call? (Y/N): 

----------

Issue / Request:
[What is the customer reporting or asking for?]

Impact:
[What is prevented, affected, or degraded?]

Environment / Context:
[Workstation, server, module, environment, hosting/database type, version, etc. as relevant.]

Time(s) Observed:
[Approximate or exact time(s), if relevant.]

Reproduction / Verification:
[Steps taken, where tested, whether reproducible, and any known-good comparison.]

----------

Investigation / Findings:
[Logs, SQL, screenshots, record IDs, services, files, configuration, observations, etc.]

Actions Taken:
[Changes made, updates run, records corrected, configuration changed, customer contacted, etc.]

----------

Current Status / Blocker:
[What is the current state? What are we waiting on, if anything?]

Next Step:
[What should happen next, and who owns it?]

----------

Other Notes:
[Anything not covered above.]
), %notesFile%

        writeError := ErrorLevel
        writeLastError := A_LastError

        if (writeError || !FileExist(notesFile)) {
            DebugLog("FAILED to create notes file: " . notesFile
                . " | ErrorLevel=" . writeError
                . " | A_LastError=" . writeLastError, true)
            MsgBox, 48, Error, Failed to create notes file:`n%notesFile%
            return
        }

        DebugLog("Notes file created: " . notesFile, true)
    } else {
        DebugLog("Existing notes file left unchanged: " . notesFile)
    }

    ; Opening is intentionally last and can never roll back a created ticket.
    OpenCreatedTicket(taskDir, notesFile)
}

;------------------------------------------------------------------------------
; Function: Open the configured post-create target(s)
;------------------------------------------------------------------------------
OpenCreatedTicket(taskDir, notesFile) {
    global openTarget

    if (openTarget = "folder" or openTarget = "both")
        OpenTicketFolder(taskDir)

    ; Open notes last for the combined mode so the document gets focus.
    if (openTarget = "notes" or openTarget = "both")
        OpenNotesFile(notesFile)
}

;------------------------------------------------------------------------------
; Function: Open generated notes using default association or custom editor
;------------------------------------------------------------------------------
OpenNotesFile(notesFile) {
    global editorMode
    global editorPath

    if (editorMode = "custom") {
        if !FileExist(editorPath) {
            DebugLog("Configured custom editor was not found; using Windows default app.", true)
            MsgBox, 48, Notes Editor Not Found, The configured notes editor could not be found.`n`nThe notes file will be opened with your Windows default app instead.`n`nYou can change the editor from the tray-menu New Ticket Settings option.
            Run, % """" . notesFile . """",, UseErrorLevel
        } else {
            Run, % """" . editorPath . """ """ . notesFile . """",, UseErrorLevel
        }
    } else {
        Run, % """" . notesFile . """",, UseErrorLevel
    }

    if (ErrorLevel)
        DebugLog("Failed to open notes file. Run error: " . ErrorLevel, true)
}

;------------------------------------------------------------------------------
; Function: Open generated ticket folder
;------------------------------------------------------------------------------
OpenTicketFolder(taskDir) {
    Run, % """" . taskDir . """",, UseErrorLevel
    if (ErrorLevel)
        DebugLog("Failed to open ticket folder. Run error: " . ErrorLevel, true)
}


;==============================================================================
; Settings UI
;==============================================================================

;------------------------------------------------------------------------------
; Function: Build and display reusable first-run/settings GUI
;------------------------------------------------------------------------------
ShowSettings(isFirstRun := false) {
    global baseDir
    global openTarget
    global editorMode
    global editorPath
    global settingsDialogResult
    global settingsIsFirstRun
    global settingsBaseDir
    global settingsOpenTarget
    global settingsEditorMode
    global settingsEditorPath
    global settingsOpenNotes
    global settingsOpenFolder
    global settingsOpenBoth
    global settingsOpenNone
    global settingsEditorDefault
    global settingsEditorCustom
    global settingsEditorBrowse

    if WinExist("New Ticket Settings ahk_class AutoHotkeyGUI") {
        WinActivate
        return false
    }

    settingsDialogResult := "cancel"
    settingsIsFirstRun := isFirstRun
    settingsBaseDir := baseDir
    settingsOpenTarget := openTarget
    settingsEditorMode := editorMode
    settingsEditorPath := editorPath
    checkedOpenNotes := (settingsOpenTarget = "notes") ? "Checked" : ""
    checkedOpenFolder := (settingsOpenTarget = "folder") ? "Checked" : ""
    checkedOpenBoth := (settingsOpenTarget = "both") ? "Checked" : ""
    checkedOpenNone := (settingsOpenTarget = "none") ? "Checked" : ""
    checkedEditorDefault := (settingsEditorMode = "default") ? "Checked" : ""
    checkedEditorCustom := (settingsEditorMode = "custom") ? "Checked" : ""

    Gui, Settings:New, +OwnDialogs +AlwaysOnTop, New Ticket Settings
    Gui, Settings:Margin, 14, 12
    Gui, Settings:Font, s9, Segoe UI

    if (isFirstRun)
        Gui, Settings:Add, Text, w520, All fields are required for first-time setup. Save writes all settings together; Cancel leaves the current configuration unchanged.

    Gui, Settings:Add, GroupBox, xm w540 h70 Section, Ticket storage folder
    Gui, Settings:Add, Edit, xs+12 ys+25 w420 vsettingsBaseDir, %settingsBaseDir%
    Gui, Settings:Add, Button, x+8 yp-1 w82 gSettingsBrowseBaseDir, Browse...

    Gui, Settings:Add, GroupBox, xm y+14 w540 h145 Section, After creating a ticket, open:
    Gui, Settings:Add, Radio, xs+12 ys+25 vsettingsOpenNotes %checkedOpenNotes%, Notes
    Gui, Settings:Add, Radio, xp yp+25 vsettingsOpenFolder %checkedOpenFolder%, Ticket Folder
    Gui, Settings:Add, Radio, xp yp+25 vsettingsOpenBoth %checkedOpenBoth%, Notes and Ticket Folder
    Gui, Settings:Add, Radio, xp yp+25 vsettingsOpenNone %checkedOpenNone%, Nothing

    Gui, Settings:Add, GroupBox, xm y+14 w540 h145 Section, Notes editor
    Gui, Settings:Add, Radio, xs+12 ys+25 vsettingsEditorDefault gSettingsEditorModeChanged %checkedEditorDefault%, Use my Windows default app for .txt files
    Gui, Settings:Add, Radio, xp yp+25 vsettingsEditorCustom gSettingsEditorModeChanged %checkedEditorCustom%, Use a specific application
    Gui, Settings:Add, Edit, xp y+28 w395 vsettingsEditorPath, %settingsEditorPath%
    Gui, Settings:Add, Button, x+8 yp-1 w82 vsettingsEditorBrowse gSettingsBrowseEditor, Browse...
    Gui, Settings:Add, Text, xs+12 y+34 w500 c555555, Plain-text (.txt) notes only. Word and OneNote note formats are not supported in this version.

    Gui, Settings:Add, Button, xm+358 y+18 w85 Default gSettingsSave, Save
    Gui, Settings:Add, Button, x+10 w85 gSettingsCancel, Cancel

    UpdateEditorControls()
    Gui, Settings:Show, AutoSize Center
    WinWaitClose, New Ticket Settings ahk_class AutoHotkeyGUI
    return (settingsDialogResult = "saved")
}

;------------------------------------------------------------------------------
; Function: Persist validated settings and update runtime immediately
;------------------------------------------------------------------------------
SaveSettings() {
    global iniFile
    global baseDir
    global openTarget
    global editorMode
    global editorPath
    global settingsDialogResult
    global settingsBaseDir
    global settingsEditorPath
    global settingsOpenNotes
    global settingsOpenFolder
    global settingsOpenBoth
    global settingsOpenNone
    global settingsEditorDefault
    global settingsEditorCustom

    Gui, Settings:Submit, NoHide
    candidateBaseDir := Trim(settingsBaseDir)
    candidateEditorPath := Trim(settingsEditorPath, " `t""")

    if (candidateBaseDir = "" or !InStr(FileExist(candidateBaseDir), "D")) {
        MsgBox, 48, Invalid Ticket Folder, Select an existing ticket storage directory before saving.
        return false
    }

    if (settingsOpenFolder)
        candidateOpenTarget := "folder"
    else if (settingsOpenBoth)
        candidateOpenTarget := "both"
    else if (settingsOpenNone)
        candidateOpenTarget := "none"
    else
        candidateOpenTarget := "notes"

    candidateEditorMode := settingsEditorCustom ? "custom" : "default"
    if (candidateEditorMode = "custom") {
        if (candidateEditorPath = "" or FileExist(candidateEditorPath) = "" or InStr(FileExist(candidateEditorPath), "D")) {
            MsgBox, 48, Invalid Notes Editor, Select a valid editor executable before saving.
            return false
        }
        SplitPath, candidateEditorPath,,, candidateEditorExt
        if (ToLower(candidateEditorExt) != "exe") {
            MsgBox, 48, Invalid Notes Editor, The custom notes editor must be an executable (.exe) file.
            return false
        }
    } else {
        candidateEditorPath := ""
    }

    ; Validate everything first, then write the complete settings group. Keep
    ; prior values so an unexpected INI write failure cannot leave a partial set.
    IniRead, priorBaseDir, %iniFile%, NewTask, baseDir,
    IniRead, priorOpenTarget, %iniFile%, NewTask, openTarget, notes
    IniRead, priorEditorMode, %iniFile%, NewTask, editorMode, default
    IniRead, priorEditorPath, %iniFile%, NewTask, editorPath, __MISSING__
    priorEditorPath := NormalizeIniBlank(priorEditorPath)
    writeFailed := false

    IniWrite, %candidateBaseDir%, %iniFile%, NewTask, baseDir
    if (ErrorLevel)
        writeFailed := true
    IniWrite, %candidateOpenTarget%, %iniFile%, NewTask, openTarget
    if (ErrorLevel)
        writeFailed := true
    IniWrite, %candidateEditorMode%, %iniFile%, NewTask, editorMode
    if (ErrorLevel)
        writeFailed := true
    IniWrite, %candidateEditorPath%, %iniFile%, NewTask, editorPath
    if (ErrorLevel)
        writeFailed := true

    if (writeFailed) {
        restoreFailed := false
        IniWrite, %priorBaseDir%, %iniFile%, NewTask, baseDir
        if (ErrorLevel)
            restoreFailed := true
        IniWrite, %priorOpenTarget%, %iniFile%, NewTask, openTarget
        if (ErrorLevel)
            restoreFailed := true
        IniWrite, %priorEditorMode%, %iniFile%, NewTask, editorMode
        if (ErrorLevel)
            restoreFailed := true
        IniWrite, %priorEditorPath%, %iniFile%, NewTask, editorPath
        if (ErrorLevel)
            restoreFailed := true
        return SettingsWriteFailed(restoreFailed)
    }

    baseDir := candidateBaseDir
    openTarget := candidateOpenTarget
    editorMode := candidateEditorMode
    editorPath := candidateEditorPath
    settingsDialogResult := "saved"

    DebugLog("New Ticket settings saved (open target and editor mode updated).", true)
    Gui, Settings:Destroy
    return true
}

SettingsWriteFailed(restoreFailed := false) {
    if (restoreFailed) {
        DebugLog("Failed to save New Ticket settings; one or more prior values could not be restored.", true)
        MsgBox, 48, Settings Not Saved, The settings could not be written, and one or more prior values could not be restored.`n`nRuntime settings were not changed. The Settings window will remain open so you can review the values or cancel.
    } else {
        DebugLog("Failed to save New Ticket settings; prior values were restored.", true)
        MsgBox, 48, Settings Not Saved, The settings could not be written. Prior values were restored, and runtime settings were not changed.`n`nThe Settings window will remain open so you can try again.
    }
    return false
}

;------------------------------------------------------------------------------
; Function: Browse for ticket storage directory
;------------------------------------------------------------------------------
BrowseForBaseDirectory() {
    global settingsBaseDir

    Gui, Settings:+OwnDialogs
    FileSelectFolder, selectedDir, *%settingsBaseDir%, 3, Select a folder to store your ticket files:
    if (!ErrorLevel and selectedDir != "") {
        settingsBaseDir := selectedDir
        GuiControl, Settings:, settingsBaseDir, %settingsBaseDir%
    }
}

;------------------------------------------------------------------------------
; Function: Browse for custom editor executable
;------------------------------------------------------------------------------
BrowseForEditor() {
    global settingsEditorPath

    Gui, Settings:+OwnDialogs
    FileSelectFile, selectedEditor, 3, %settingsEditorPath%, Select a notes editor executable, Applications (*.exe)
    if (!ErrorLevel and selectedEditor != "") {
        settingsEditorPath := selectedEditor
        GuiControl, Settings:, settingsEditorPath, %settingsEditorPath%
        GuiControl, Settings:, settingsEditorCustom, 1
        UpdateEditorControls()
    }
}

;------------------------------------------------------------------------------
; Function: Enable custom-editor fields only when custom mode is selected
;------------------------------------------------------------------------------
UpdateEditorControls() {
    GuiControlGet, customMode, Settings:, settingsEditorCustom
    controlAction := customMode ? "Enable" : "Disable"
    GuiControl, Settings:%controlAction%, settingsEditorPath
    GuiControl, Settings:%controlAction%, settingsEditorBrowse
}

;------------------------------------------------------------------------------
; Function: Add Settings without replacing standard tray commands
;------------------------------------------------------------------------------
InitializeTrayMenu() {
    Menu, Tray, Add
    Menu, Tray, Add, New Ticket Settings..., OpenSettingsFromTray
}


;==============================================================================
; INI / Setup / Maintenance
;==============================================================================

;------------------------------------------------------------------------------
; Function: Ensure AppData folders exist
;------------------------------------------------------------------------------
EnsureAppFoldersExist() {
    global appDataFolder
    global backupFolder

    if !FileExist(appDataFolder) {
        FileCreateDir, %appDataFolder%
        if !FileExist(appDataFolder) {
            MsgBox, 16, Error, Failed to create AppData folder:`n%appDataFolder%
            ExitApp
        }
    }

    if !FileExist(backupFolder) {
        FileCreateDir, %backupFolder%
        if !FileExist(backupFolder) {
            MsgBox, 16, Error, Failed to create backup folder:`n%backupFolder%
            ExitApp
        }
    }
}

;------------------------------------------------------------------------------
; Function: AutoFixINI
; Purpose : Write default if key is missing or blank, and track repairs
;------------------------------------------------------------------------------
AutoFixINI(section, key, defaultValue) {
    global iniFile
    global missingKeys

    IniRead, val, %iniFile%, %section%, %key%
    if (val = "ERROR" or val = "") {
        IniWrite, %defaultValue%, %iniFile%, %section%, %key%
        missingKeys.Push(section . "/" . key)
    }
}

;------------------------------------------------------------------------------
; Function: Verify, migrate, repair, and initialize NewTask.ini
;------------------------------------------------------------------------------
VerifyOrInitializeINI() {
    global iniFile
    global backupFolder
    global missingKeys

    latestConfigVersion := "1.2"
    missingKeys := []
    iniExisted := FileExist(iniFile)

    ; === Backup Existing INI ===
    if (iniExisted) {
        FormatTime, nowReadable,, yyyyMMdd_HHmmss
        backupPath := backupFolder "\NewTask_backup_" . nowReadable . ".ini"
        FileCopy, %iniFile%, %backupPath%, 1
        TrimBackups()
    }

    ; Read legacy values before adding new defaults so migration can distinguish
    ; an existing installation from a fresh one.
    IniRead, existingOpenTarget, %iniFile%, NewTask, openTarget, __MISSING__
    IniRead, legacyOpenOnCreate, %iniFile%, NewTask, openOnCreate, true
    IniRead, existingEditorMode, %iniFile%, NewTask, editorMode, __MISSING__
    IniRead, legacyEditorPath, %iniFile%, NewTask, editorPath, __MISSING__
    normalizedLegacyEditor := NormalizeIniBlank(legacyEditorPath)

    ; --- [Settings] Section ---
    AutoFixINI("Settings", "debugMode", 0)

    ; --- [NewTask] Section ---
    AutoFixINI("NewTask", "baseDir", "")
    AutoFixINI("NewTask", "taskFile", "notes.txt")
    AutoFixINI("NewTask", "taskPrefix", "Task")

    if (existingOpenTarget = "__MISSING__" or existingOpenTarget = "") {
        migratedOpenTarget := IsTrueValue(legacyOpenOnCreate) ? "notes" : "none"
        IniWrite, %migratedOpenTarget%, %iniFile%, NewTask, openTarget
        DebugLog("Migrated post-create preference to openTarget=" . migratedOpenTarget . ".", true)
    } else if !IsValidOpenTarget(existingOpenTarget) {
        IniWrite, notes, %iniFile%, NewTask, openTarget
        DebugLog("Repaired invalid openTarget value to notes.", true)
    }

    if (existingEditorMode = "__MISSING__" or existingEditorMode = "") {
        normalizedLegacyEditor := Trim(normalizedLegacyEditor, " `t""")
        if (normalizedLegacyEditor = "" or ToLower(normalizedLegacyEditor) = "notepad") {
            IniWrite, default, %iniFile%, NewTask, editorMode
            IniWrite, % "", %iniFile%, NewTask, editorPath
            DebugLog("Migrated notes editor preference to Windows default app.", true)
        } else {
            IniWrite, custom, %iniFile%, NewTask, editorMode
            DebugLog("Migrated notes editor preference to custom mode.", true)
        }
    } else if (existingEditorMode = "custom" and normalizedLegacyEditor = "") {
        IniWrite, default, %iniFile%, NewTask, editorMode
        IniWrite, % "", %iniFile%, NewTask, editorPath
        DebugLog("Repaired incomplete custom editor preference to Windows default app.", true)
    } else if (existingEditorMode != "default" and existingEditorMode != "custom") {
        IniWrite, default, %iniFile%, NewTask, editorMode
        DebugLog("Repaired invalid editorMode value to default.", true)
    }

    ; Fresh configurations also retain this compatibility key, but runtime
    ; behavior is controlled exclusively by openTarget.
    AutoFixINI("NewTask", "openOnCreate", "true")

    ; IniWrite cannot reliably express an empty value in every v1 environment;
    ; ensure the key exists, then normalize the historical notepad default.
    IniRead, repairedEditorMode, %iniFile%, NewTask, editorMode, default
    IniRead, repairedEditorPath, %iniFile%, NewTask, editorPath, __MISSING__
    repairedEditorPath := NormalizeIniBlank(repairedEditorPath)
    if (repairedEditorMode = "default" and repairedEditorPath != "") {
        IniWrite, % "", %iniFile%, NewTask, editorPath
        DebugLog("Cleared editorPath because editorMode uses the Windows default app.", true)
    }

    ; === Final Report Missing Keys (if any) ===
    if (missingKeys.MaxIndex()) {
        Loop % missingKeys.MaxIndex()
        {
            fixedKey := missingKeys[A_Index]
            DebugLog("Repaired: " . fixedKey, true)
        }
        DebugLog("INI repaired and fully verified.", true)
    } else {
        DebugLog("No missing legacy keys detected. INI verified clean.", true)
    }

    ; === Ensure Config Version is Synced ===
    IniRead, configVersion, %iniFile%, Settings, configVersion, 0
    if (CompareVersions(configVersion, latestConfigVersion) < 0) {
        IniWrite, %latestConfigVersion%, %iniFile%, Settings, configVersion
        DebugLog("Config version synced to " . latestConfigVersion, true)
    } else if (configVersion = "ERROR" or configVersion = "") {
        IniWrite, %latestConfigVersion%, %iniFile%, Settings, configVersion
        DebugLog("Repaired: Settings/configVersion", true)
    }
}

;------------------------------------------------------------------------------
; Function: Load post-create settings used at runtime
;------------------------------------------------------------------------------
LoadRuntimeSettings() {
    global iniFile
    global baseDir
    global openTarget
    global editorMode
    global editorPath

    IniRead, baseDir, %iniFile%, NewTask, baseDir,
    IniRead, openTarget, %iniFile%, NewTask, openTarget, notes
    IniRead, editorMode, %iniFile%, NewTask, editorMode, default
    IniRead, editorPath, %iniFile%, NewTask, editorPath, __MISSING__
    editorPath := NormalizeIniBlank(editorPath)

    if !IsValidOpenTarget(openTarget)
        openTarget := "notes"
    if (editorMode != "default" and editorMode != "custom")
        editorMode := "default"
    if (editorMode = "default")
        editorPath := ""
}

IsValidOpenTarget(value) {
    return (value = "notes" or value = "folder" or value = "both" or value = "none")
}

IsTrueValue(value) {
    value := ToLower(Trim(value))
    return (value = "1" or value = "true" or value = "yes" or value = "on")
}

ToLower(value) {
    StringLower, lowerValue, value
    return lowerValue
}

NormalizeIniBlank(value) {
    value := Trim(value, " `t""")
    if (value = "ERROR" or value = "__MISSING__")
        return ""
    return value
}

;------------------------------------------------------------------------------
; Function: Keep only the 10 most recent INI backups
;------------------------------------------------------------------------------
TrimBackups() {
    global backupFolder

    backupPattern := backupFolder "\NewTask_backup_*.ini"
    backupList := ""

    Loop, Files, %backupPattern%
        backupList .= A_LoopFileFullPath . "`n"

    if (backupList = "")
        return

    Sort, backupList
    StringTrimRight, backupList, backupList, 1

    StringSplit, backupArray, backupList, `n
    if (backupArray0 > 10) {
        excess := backupArray0 - 10
        Loop, %excess%
        {
            FileDelete, % backupArray%A_Index%
            DebugLog("Old backup deleted: " . backupArray%A_Index%, true)
        }
        if (excess > 0)
            DebugLog(excess . " old backup(s) deleted during cleanup.", true)
    }
}

;------------------------------------------------------------------------------
; Function: Read debug mode from INI into global variable
;------------------------------------------------------------------------------
LoadDebugMode() {
    global iniFile
    global debugMode

    IniRead, debugMode, %iniFile%, Settings, debugMode, 0
    debugMode := (debugMode = "1")
}

;------------------------------------------------------------------------------
; Function: Toggle Debug Mode
;------------------------------------------------------------------------------
ToggleDebugMode() {
    global iniFile
    global debugMode

    IniRead, debugMode, %iniFile%, Settings, debugMode, 0
    debugMode := (debugMode = "1") ? 0 : 1
    IniWrite, %debugMode%, %iniFile%, Settings, debugMode

    previousState := (debugMode = 1) ? "Disabled" : "Enabled"
    newState := (debugMode = 1) ? "Enabled" : "Disabled"

    DebugLog("Debug Mode toggled from " . previousState . " to " . newState, true)
    MsgBox, 64, Debug Mode, Debug mode is now: %newState%
}


;==============================================================================
; Utilities
;==============================================================================

;------------------------------------------------------------------------------
; Function: Compare Versions
;------------------------------------------------------------------------------
CompareVersions(v1, v2) {
    v1 := Trim(v1)
    v2 := Trim(v2)

    StringSplit, v1Parts, v1, .
    StringSplit, v2Parts, v2, .
    maxParts := (v1Parts0 > v2Parts0) ? v1Parts0 : v2Parts0

    Loop, %maxParts%
    {
        part1 := (A_Index <= v1Parts0) ? v1Parts%A_Index% : 0
        part2 := (A_Index <= v2Parts0) ? v2Parts%A_Index% : 0

        if (part1 > part2)
            return 1
        if (part1 < part2)
            return -1
    }
    return 0
}

;------------------------------------------------------------------------------
; Function: Debug Logging
;------------------------------------------------------------------------------
DebugLog(message, force := false) {
    global debugMode
    global logFile
    global appDataFolder
    static resolvedLogFile

    if (!resolvedLogFile)
        resolvedLogFile := logFile

    if (debugMode || force) {
        if FileExist(resolvedLogFile) {
            FileGetSize, fileSize, %resolvedLogFile%
            if (fileSize > 1048576) {
                FileDelete, %resolvedLogFile%
                FormatTime, resetTime,, yyyy-MM-dd HH:mm:ss
                FileAppend, [%resetTime%] Debug log reset due to size.`n, %resolvedLogFile%
            }
        }

        FormatTime, timestamp, %A_Now%, yyyy-MM-dd HH:mm:ss
        FileAppend, [%timestamp%] %message%`n, %resolvedLogFile%
    }
}

