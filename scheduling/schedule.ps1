<#
.SYNOPSIS
    A lightning-fast CLI-based vertical daily timeline renderer.
.DESCRIPTION
    This script parses a JSON-based schedule to generate a visual 24-hour roadmap directly in the console. 
    It features Nerd Font integration for iconography, automatic color stabilization (mapping non-standard 
    JSON colors to console-safe ones), and a real-time "Now" indicator that tracks the current hour and 
    half-hour increments.

    Key Features:
    - O(1) Hour Mapping for performance.
    - Automatic date filtering (only shows today's tasks).
    - Support for JetBrains Nerd Font glyphs.
    - Visual task duration spanning with vertical continuation lines..PARAMETER Selection
    The key mapped to a specific project. If empty, displays the navigation menu.

.PARAMETER Path
    The file path to the 'schedule.json' file. Defaults to the /data/ subfolder relative to the script.


.EXAMPLE
    .\schedule.ps1
    Runs the planner using the default JSON path and renders the current day's schedule.

.NOTES
    Author: Priyanshu Farkonde (gh: priyanshuf11)
    Version: 1.0
    Requirements: A terminal with Nerd Font support (e.g., Cascadia Code NF, JetBrainsMono NF).
#>

# --- 1. DATA MODELS & STABILIZATION ---

function Get-DailySchedule {
    param($Path)
    if (-not (Test-Path $Path)) { return @() }
    
    # Read raw JSON as a single string
    $raw = Get-Content $Path -Raw | ConvertFrom-Json
    if ($null -eq $raw) { return @() }
    $rawTasks = @($raw)

    $today = (Get-Date).Date
    $filtered = foreach ($task in $rawTasks) {
        if ($null -ne $task.Date) {
            $taskDate = ([datetime]$task.Date).Date
            if ($taskDate -eq $today) {
                # Map non-standard colors to standard ones to prevent crashes
                $safeColor = $task.Color
                if ($safeColor -eq "Teal") { $safeColor = "Cyan" }

                [PSCustomObject]@{
                    Start = [int]$task.Start
                    Dur   = [int]$task.Dur
                    End   = [int]$task.Start + [int]$task.Dur # Pre-calculate
                    Name  = [string]$task.Name
                    Color = [string]$safeColor
                }
            }
        }
    }
    return @($filtered)
}

function Build-HourMap {
    param($Tasks)
    $map = @{}
    # Initialize the 24-hour deterministic lookup table
    for ($h = 0; $h -lt 24; $h++) { $map[$h] = $null }
    foreach ($task in $Tasks) {
        for ($i = $task.Start; $i -lt $task.End; $i++) {
            if ($i -ge 0 -and $i -lt 24) { $map[$i] = $task }
        }
    }
    return $map
}

# --- 2. CONFIGURATION & RENDERING ---

$JsonPath = "$PSScriptRoot/data/schedule.json"
$LiveColor = "Red"; $DimColor = "DarkGray"

# JetBrains Nerd Font Glyphs
$LineChar = [char]0x2500; $StartChar = [char]0x250f
$ContChar = [char]0x2503; $DotChar = [char]0x00b7; $Icon = [char]0xf054

function Show-VerticalPlanner {
    $Schedule = Get-DailySchedule -Path $JsonPath
    $HourMap  = Build-HourMap -Tasks $Schedule
    $Now = Get-Date

    Clear-Host
    Write-Host "`n  DAILY TIMELINE - $($Now.ToString('dd MMM yyyy'))" -ForegroundColor White
    Write-Host "  Tasks Loaded: $($Schedule.Count)" -ForegroundColor Gray
    Write-Host ("  " + ($LineChar.ToString() * 40)) -ForegroundColor Gray
    Write-Host ""

    for ($h = 0; $h -lt 24; $h++) {
        $ActiveTask = $HourMap[$h] # O(1) Lookup
        $IsPastHalf = $Now.Minute -ge 30
        
        $HourPointer = if ($h -eq $Now.Hour -and -not $IsPastHalf) { "> " } else { "  " }
        $RowColor = if ($h -eq $Now.Hour) { $LiveColor } else { $DimColor }

        Write-Host "$HourPointer$( "{0:D2}:00" -f $h ) " -NoNewline -ForegroundColor $RowColor

        if ($null -ne $ActiveTask) {
            $IsStart = ($h -eq $ActiveTask.Start)
            $TaskColor = if ($h -eq $Now.Hour) { $LiveColor } else { $ActiveTask.Color }
            
            $Symbol = if ($IsStart) { $StartChar } else { $ContChar }
            $Txt = if ($IsStart) { "$Icon $($ActiveTask.Name)" } else { "" }
            Write-Host "$Symbol $Txt" -ForegroundColor $TaskColor
        } else {
            Write-Host $DotChar -ForegroundColor $DimColor
        }

        if ($h -lt 23) {
            $IsTickActive = ($h -eq $Now.Hour -and $IsPastHalf)
            $TickPointer = if ($IsTickActive) { "> " } else { "  " }
            $TickColor = if ($IsTickActive) { $LiveColor } else { $DimColor }
            $TickSymbol = if ($null -ne $ActiveTask) { $ContChar } else { $DotChar }
            Write-Host "$TickPointer      $TickSymbol" -ForegroundColor $TickColor
        }
    }
    Write-Host "`n  [Now: $($Now.ToString('HH:mm:ss'))] - Ctrl+C to stop" -ForegroundColor DarkGray
}

