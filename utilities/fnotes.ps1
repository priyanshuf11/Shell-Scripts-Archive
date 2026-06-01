<#
.SYNOPSIS
    Field Notes: a data-first append-only developer journal.

.DESCRIPTION
    A lightweight CLI tool for capturing quick thoughts, work logs, ideas,
    debugging notes, and snippets.

    Entries are stored locally as JSON for easy parsing, scripting,
    automation, or future analysis.

    Schema:
    { id, timestamp, category, tags, content }

.PARAMETER InputData
    Entry text to save, or use 'list' to display today's notes.

.EXAMPLE
    .\fnotes.ps1 "Fix auth timeout bug"

.EXAMPLE
    .\fnotes.ps1 list

.NOTES
    Author: Priyanshu Farkonde (gh: priyanshuf11)
    Version: 1.0
    Storage: $HOME\.fnotes\data.json
#>

# TODO: implement search parameter to query historical entries

[CmdletBinding()]
param (
    [Parameter(Position=0, Mandatory=$true)]
    [string]$InputData,

    [Parameter(Mandatory=$false)]
    [Alias("c")]
    [string]$Category = "work",

    [Parameter(Mandatory=$false)]
    [Alias("t")]
    [string]$TagsRaw
)

# --- Configuration ---
$DataDir  = "$HOME\.fnotes"  # NOTE: change the Directory or file if required
$DataFile = "$DataDir\data.json"

# --- Initialisation (Deterministic) ---
# Ensures the storage layer exists before attempting any I/O operations.
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
if (-not (Test-Path $DataFile)) { Set-Content -Path $DataFile -Value "[]" -Encoding UTF8 }

# --- Process Logic ---
# Reserved keywords trigger commands. Everything else is a log entry.
switch ($InputData) {
    "list" {
        # --- RECALL MODE ---
        try {
            $JsonContent = Get-Content -Path $DataFile -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($null -eq $JsonContent) { $JsonContent = @() }
            if ($JsonContent -isnot [Array]) { $JsonContent = @($JsonContent) }

            $TodayStr = Get-Date -Format "yyyy-MM-dd"
            Write-Host "--- Field Notes for $TodayStr ---" -ForegroundColor Cyan

            # Filter & Render (View Logic)
            $JsonContent | Where-Object { $_.timestamp -like "$TodayStr*" } | ForEach-Object {
                # 1. Parse Timestamp Correctly (No string splitting)
                $TimeObj = [DateTimeOffset]::Parse($_.timestamp)
                $TimeDisplay = $TimeObj.ToString("HH:mm:ss")

                # 2. Format Tags (View Concern)
                $TagStr = ""
                if ($null -ne $_.tags -and $_.tags.Count -gt 0) {
                    $TagStr = "(tags: $($_.tags -join ', '))"
                }

                Write-Host "[$TimeDisplay] [$($_.category)] $($_.content) $TagStr"
            }
        }
        catch {
            Write-Error "Read Error: $_"
            exit 1
        }
    }

    Default {
        # --- CAPTURE MODE ---
        try {
            $Now = Get-Date
            # ISO 8601 (Round-trip format)
            $IsoTimestamp = $Now.ToString("o") 
            
            # Parse Tags
            $TagArray = @()
            if (-not [string]::IsNullOrWhiteSpace($TagsRaw)) {
                $TagArray = $TagsRaw -split "," | ForEach-Object { $_.Trim() }
            }

            # Construct Schema (Raw Data Only)
            $NewEntry = [PSCustomObject]@{
                id        = $IsoTimestamp
                timestamp = $IsoTimestamp
                category  = $Category
                tags      = $TagArray
                content   = $InputData  # $InputData is the message here
            }

            # Atomic-ish Append
            # FIXME: : reading entire file for every append is inefficient
            $CurrentData = Get-Content -Path $DataFile -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($null -eq $CurrentData) { $CurrentData = @() }
            if ($CurrentData -isnot [Array]) { $CurrentData = @($CurrentData) }

            $CurrentData += $NewEntry

            # Save
            $CurrentData | ConvertTo-Json -Depth 10 | Set-Content -Path $DataFile -Encoding UTF8
            Write-Host "Entry logged." -ForegroundColor Green
        }
        catch {
            Write-Error "Write Error: $_"
            exit 1
        }
    }
}
