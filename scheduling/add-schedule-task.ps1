<#
.SYNOPSIS
    Adds a new scheduled task to the daily JSON tracking file with collision detection.

.DESCRIPTION
    This script serves as the data entry point for the Vertical Planner. It performs 
    three critical "stabilization" steps before saving:
    1. Color Assignment: If no color is provided, it picks a high-contrast terminal color.
    2. Date Isolation: It specifically targets 'today' to keep the JSON manageable.
    3. Collision Logic: It calculates the time window of the new task ($Start + $Dur$) 
       and compares it against existing tasks to prevent overlapping schedules.

.PARAMETER Start
    The starting hour of the task (0-23).
.PARAMETER Dur
    The duration of the task in hours.
.PARAMETER Name
    The display name of the task.
.PARAMETER Color
    (Optional) The color for the UI. Defaults to a random selection from a neon palette.

.EXAMPLE
    .\add-schedule-task.ps1 -Start 14 -Dur 2 -Name "Deep Work" -Color "Magenta"
    Adds a 2-hour "Deep Work" block starting at 2:00 PM.

.EXAMPLE
    .\add-schedule-task.ps1 9 1 "Gym"
    Uses positional parameters to add a 1-hour Gym session at 9:00 AM with a random color.
#>

param (
    [Parameter(Mandatory=$true, Position=0)] [int]$Start,
    [Parameter(Mandatory=$true, Position=1)] [int]$Dur,
    [Parameter(Mandatory=$true, Position=2)] [string]$Name,
    [Parameter(Mandatory=$false, Position=3)] [string]$Color
)

$JsonPath = "$PSScriptRoot/data/schedule.json"
$Today = (Get-Date).ToString("yyyy-MM-dd")

# 1. Handle Random Color Logic
if (-not $Color) {
    $Palette = "Cyan", "Magenta", "Green", "Blue", "Yellow", "Mauve"
    $Color = Get-Random -InputObject $Palette
}

# 2. Load and Filter (Force Array with @ symbol)
if (Test-Path $JsonPath) {
    $RawData = Get-Content $JsonPath | ConvertFrom-Json
    # The @() ensures $Schedule is always an array, even with 1 item
    $Schedule = @($RawData | Where-Object { $_.Date -eq $Today })
} else {
    $Schedule = @()
}

# 3. Collision Detection Logic
$NewEnd = $Start + $Dur
$Overlap = $Schedule | Where-Object {
    $ExistingStart = $_.Start
    $ExistingEnd = $_.Start + $_.Dur
    ($Start -lt $ExistingEnd) -and ($NewEnd -gt $ExistingStart)
} | Select-Object -First 1

if ($null -ne $Overlap) {
    Write-Host "`n[!] ERROR: Task Overlap Detected" -ForegroundColor Red
    Write-Host "Conflict: $($Overlap.Name) ($($Overlap.Start):00 - $($Overlap.Start + $Overlap.Dur):00)" -ForegroundColor Yellow
    return
}

# 4. Add and Save
$NewTask = [PSCustomObject]@{
    Date  = $Today
    Start = $Start
    Dur   = $Dur
    Name  = $Name
    Color = $Color
}

$Schedule += $NewTask
$Schedule | ConvertTo-Json -Depth 10 | Set-Content $JsonPath

Write-Host "`n[+] SUCCESS: '$Name' added for $Today." -ForegroundColor Green
