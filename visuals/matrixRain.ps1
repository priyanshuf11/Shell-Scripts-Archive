
<#
.SYNOPSIS
    Catppuccin Matrix Rain (Smart Inputs)
.DESCRIPTION
    High-performance rendering with simplified numeric inputs.
    It inherits the BackgroundColor of Terminal.
    Usage: .\matrixRain.ps1 [Color 1-4] [Speed ms]
#>

param(
    # 1=Blue (Default), 2=Mauve, 3=Green, 4=Red
    [Parameter(Position=0)]
    [ValidateRange(1, 4)]
    [Alias("c")]
    [int]$Color = 1,

    # Speed in ms (Lower is faster). Default 40.
    [Parameter(Position=1)]
    [Alias("s")]
    [int]$Speed = 40,

    [double]$Density = 0.5
)

# --- Class Definition ---
class RainStream {
    # Instance Properties
    [int]$X
    [int]$Y
    [int]$FallSpeed
    [int]$SpeedCounter
    [int]$Length
    [int]$WindowHeight
    [string]$CharBuffer

    # Static Resources
    static [string] $HeadColor
    static [string] $BodyColor
    static [string] $TailColor
    static [string] $ResetColor
    static [string] $BgColor
    static [char[]] $Charset

    # Static method to configure colors based on user input
    static ConfigureTheme([int]$mode) {
        $e = [char]27
        [RainStream]::ResetColor = "$e[0m"
        [RainStream]::BgColor    = "$e[4p9m" # Base (Transparent)
        [RainStream]::TailColor  = "$e[38;2;69;71;90m" # Surface1 (Ghostly Fade)

        switch ($mode) {
            2 { # Mauve
                [RainStream]::HeadColor = "$e[38;2;245;194;231m" # Pink
                [RainStream]::BodyColor = "$e[38;2;203;166;247m" # Mauve
            }
            3 { # Green
                [RainStream]::HeadColor = "$e[38;2;166;227;161m" # Green
                [RainStream]::BodyColor = "$e[38;2;148;226;213m" # Teal
            }
            4 { # Red
                [RainStream]::HeadColor = "$e[38;2;243;139;168m" # Red
                [RainStream]::BodyColor = "$e[38;2;235;160;172m" # Maroon
            }
            Default { # 1 = Blue
                [RainStream]::HeadColor = "$e[38;2;180;190;254m" # Lavender
                [RainStream]::BodyColor = "$e[38;2;137;180;250m" # Blue
            }
        }

        # Pre-generate charset (Katakana + Latin + Numbers)
        [RainStream]::Charset = [char[]]((0x30A0..0x30FF) + (0x0041..0x005A) + (0x0030..0x0039))
    }

    # Instance Constructor
    RainStream([int]$x, [int]$h) {
        $this.X = $x
        $this.WindowHeight = $h
        $this.Reset($true)
    }

    # Helper to get random char
    [string] GetChar() {
        return [RainStream]::Charset[(Get-Random -Max ([RainStream]::Charset.Length))]
    }

    Reset([bool]$randomStart) {
        $this.Y = if ($randomStart) { Get-Random -Min 0 -Max $this.WindowHeight } else { 0 }
        $this.Length = Get-Random -Min 5 -Max 20
        $this.FallSpeed = Get-Random -Min 1 -Max 3
        $this.SpeedCounter = 0
        $this.CharBuffer = $this.GetChar()
    }

    Update() {
        # Speed Throttling
        $this.SpeedCounter++
        if ($this.SpeedCounter -lt $this.FallSpeed) { return }
        $this.SpeedCounter = 0

        $e = [char]27 
        
        # 1. DRAW HEAD
        if ($this.Y -lt $this.WindowHeight) {
            $char = $this.GetChar()
            $this.CharBuffer = $char
            $col = [RainStream]::HeadColor
            [Console]::Out.Write("$e[$($this.Y);$($this.X)H$col$char")
        }

        # 2. DRAW BODY
        $prevY = $this.Y - 1
        if ($prevY -ge 1 -and $prevY -lt $this.WindowHeight) {
            $col = [RainStream]::BodyColor
            [Console]::Out.Write("$e[$($prevY);$($this.X)H$col$($this.CharBuffer)")
        }

        # 3. DRAW TAIL
        $fadeY = $this.Y - ($this.Length - 4)
        if ($fadeY -ge 1 -and $fadeY -lt $this.WindowHeight) {
            $col = [RainStream]::TailColor
            $ghostChar = $this.GetChar()
            [Console]::Out.Write("$e[$($fadeY);$($this.X)H$col$ghostChar")
        }

        # 4. ERASE TAIL
        $eraseY = $this.Y - $this.Length
        if ($eraseY -ge 1 -and $eraseY -le $this.WindowHeight) {
            [Console]::Out.Write("$e[$($eraseY);$($this.X)H ")
        }

        # Move Logic
        $this.Y++
        if (($this.Y - $this.Length) -gt $this.WindowHeight) {
            $this.Reset($false)
        }
    }
}

# --- Main Setup ---

# Apply User Theme (Positional Input)
[RainStream]::ConfigureTheme($Color)

# Save Terminal State
$origVisible = [Console]::CursorVisible
$origBg = [Console]::BackgroundColor
$origFg = [Console]::ForegroundColor

try {
    # Initialize Screen
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::CursorVisible = $false
    $e = [char]27
    
    # Full clear and set BG
    [Console]::Out.Write("$e[?25l$([RainStream]::BgColor)$e[2J$e[H")

    $W = [Console]::WindowWidth
    $H = [Console]::WindowHeight

    # Create Streams
    $Streams = [System.Collections.Generic.List[RainStream]]::new()
    $ColCount = [Math]::Floor($W * $Density)
    
    # Randomize columns
    $AvailableCols = 1..$W | Sort-Object { Get-Random }
    
    for ($i = 0; $i -lt $ColCount; $i++) {
        if ($i -lt $AvailableCols.Count) {
            $Streams.Add([RainStream]::new($AvailableCols[$i], $H))
        }
    }

    # Main Loop
    while ($true) {
        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq "Escape") { break }
        }
        
        # Handle Resize
        if ([Console]::WindowWidth -ne $W -or [Console]::WindowHeight -ne $H) {
            $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
            [Console]::Out.Write("$e[2J") # Clear
            foreach ($s in $Streams) { $s.WindowHeight = $H; $s.Reset($true) }
        }

        foreach ($s in $Streams) {
            $s.Update()
        }
        Start-Sleep -Milliseconds $Speed
    }

} finally {
    # Cleanup
    $e = [char]27
    [Console]::Out.Write("$e[0m$e[?25h$e[2J$e[H")
    [Console]::CursorVisible = $origVisible
    [Console]::BackgroundColor = $origBg
    [Console]::ForegroundColor = $origFg
}
