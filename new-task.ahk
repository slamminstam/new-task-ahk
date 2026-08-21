;==============================================================================
; New Ticket Tool
;==============================================================================
; Version: 1.12.0
; Standalone AHK v1.1 script
;==============================================================================

#NoEnv
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%

;------------------------------------------------------------------------------
; Global Paths
;------------------------------------------------------------------------------
global appDataFolder := A_AppData "\HotKeys\NewTask"
global backupFolder := appDataFolder "\OldConfigs"
global iniFile := appDataFolder "\NewTask.ini"
global logFile := appDataFolder "\NewTask_debug.log"
global missingKeys
global debugMode := 0

;------------------------------------------------------------------------------
; Startup
;------------------------------------------------------------------------------
EnsureAppFoldersExist()
VerifyOrInitializeINI()
LoadDebugMode()

;------------------------------------------------------------------------------
; Hotkeys
;------------------------------------------------------------------------------
^!n::NewTicketRunner("NewTask")      ; Ctrl+Alt+N
^NumpadSub::ToggleDebugMode()      ; Ctrl+NumpadMinus (hidden/power user)

return


;==============================================================================
; Main Functions
;==============================================================================

;------------------------------------------------------------------------------
; Function: New Ticket Tool - Build Folder Structure for each new Ticket
;------------------------------------------------------------------------------
NewTicketRunner(section := "NewTask") {
    global iniFile
    global debugMode

    ; === LOAD CONFIG FROM INI ===
    IniRead, baseDir, %iniFile%, %section%, baseDir,
    IniRead, taskFile, %iniFile%, %section%, taskFile, notes.txt
    IniRead, taskPrefix, %iniFile%, %section%, taskPrefix, Task
    IniRead, openAfter, %iniFile%, %section%, openOnCreate, true
    IniRead, editorPath, %iniFile%, %section%, editorPath, notepad

    ; Normalize boolean-ish value
    openAfter := (openAfter = "1" or openAfter = "true")

    if (baseDir = "") {
        MsgBox, 48, Configuration Required, This is your first time running the script, or no ticket storage location has been set.`n`nPlease select a folder to store your ticket files.
        FileSelectFolder, baseDir, , 3, Select a folder to store your ticket files:
        if (ErrorLevel || baseDir = "") {
            MsgBox, 48, Error, No directory selected. Exiting.
            return
        }
        IniWrite, %baseDir%, %iniFile%, NewTask, baseDir
        DebugLog("Base project directory selected: " . baseDir, true)
    }

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
    if (!FileExist(notesFile)) {
        FileAppend,
(
Ticket ID: %taskName%

Zendesk URL: [Zendesk Ticket URL]

Project Owner: %A_Username%

Org:

Requester:

Form:

Phone Call? (Y/N): 

----------

Other Notes:
[Use this space for anything not covered above.]
), %notesFile%
    }

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

    ; === Offer to Open Folder ===
    if (openAfter) {
        MsgBox, 36, Open Directory, Would you like to open the task folder now?
        IfMsgBox Yes
            Run, %taskDir%
    }
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
; Function: VerifyOrInitializeINI
; Purpose : Verify, repair, and initialize NewTask.ini
;------------------------------------------------------------------------------
VerifyOrInitializeINI() {
    global iniFile
    global backupFolder
    global missingKeys

    latestConfigVersion := "1.1"
    missingKeys := []

    ; === Backup Existing INI ===
    if FileExist(iniFile) {
        FormatTime, nowReadable,, yyyyMMdd_HHmmss
        backupPath := backupFolder "\NewTask_backup_" . nowReadable . ".ini"
        FileCopy, %iniFile%, %backupPath%, 1
        TrimBackups()
    }

    ; --- [Settings] Section ---
    AutoFixINI("Settings", "debugMode", 0)
    AutoFixINI("Settings", "configVersion", latestConfigVersion)

    ; --- [NewTask] Section ---
    AutoFixINI("NewTask", "baseDir", "")
    AutoFixINI("NewTask", "taskFile", "notes.txt")
    AutoFixINI("NewTask", "taskPrefix", "Task")
    AutoFixINI("NewTask", "openOnCreate", "true")
    AutoFixINI("NewTask", "editorPath", "notepad")

    ; === Final Report Missing Keys (if any) ===
    if (missingKeys.MaxIndex()) {
        Loop % missingKeys.MaxIndex()
        {
            fixedKey := missingKeys[A_Index]
            DebugLog("Repaired: " . fixedKey, true)
        }
        DebugLog("INI repaired and fully verified.", true)
    } else {
        DebugLog("No missing keys detected. INI verified clean.", true)
    }

    ; === Ensure Config Version is Synced ===
    IniRead, configVersion, %iniFile%, Settings, configVersion
    if (CompareVersions(configVersion, latestConfigVersion) < 0) {
        IniWrite, %latestConfigVersion%, %iniFile%, Settings, configVersion
        DebugLog("Config version synced to " . latestConfigVersion, true)
    }
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
