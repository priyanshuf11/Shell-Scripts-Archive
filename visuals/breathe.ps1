<#
.SYNOPSIS
    Catppuccin Breathing Nebula 
.DESCRIPTION
    Scattered text that pulses with a "breathing" rhythm.
    Uses StringBuilder buffering to eliminate rendering flicker.
.PARAMETER ColorMode
    1=Blue, 2=Mauve (Default), 3=Green, 4=Red
#>

param(
    [Parameter(Position=0)]
    [int]$ColorMode = 2, 

    [Parameter(Position=1)]
    [int]$Speed = 5,

    [int]$Density = 300
)

# --- Class: Breathing Particle ---
class Particle {
    [int]$X
    [int]$Y
    [char]$Char
    [double]$PhaseOffset 

    # Static Colors
    static [int[]] $ColorLow  
    static [int[]] $ColorHigh 
    static [char[]] $Charset

    static ConfigureTheme([int]$mode) {
        switch ($mode) {
            1 { # Blue
                [Particle]::ColorHigh = @(137, 180, 250) 
                [Particle]::ColorLow  = @(30, 30, 46)    
            }
            3 { # Green
                [Particle]::ColorHigh = @(166, 227, 161) 
                [Particle]::ColorLow  = @(30, 30, 46)
            }
            4 { # Red
                [Particle]::ColorHigh = @(243, 139, 168) 
                [Particle]::ColorLow  = @(30, 30, 46)
            }
            Default { # 2 = Mauve
                [Particle]::ColorHigh = @(203, 166, 247) 
                [Particle]::ColorLow  = @(49, 50, 68)    
            }
        }
        [Particle]::Charset = [char[]]((0x002A..0x002F) + (0x2200..0x224F)) 
    }

    Particle([int]$w, [int]$h) {
        $this.X = Get-Random -Min 0 -Max $w
        $this.Y = Get-Random -Min 0 -Max $h
        $len = ([Particle]::Charset.Length)
        $this.Char = [Particle]::Charset[(Get-Random -Max $len)]
        $this.PhaseOffset = ($this.X / 20.0) + ($this.Y / 10.0)
    }

    # Optimization: Append to buffer instead of writing directly
    Render([double]$time, [System.Text.StringBuilder]$buffer) {
        $e = [char]27
        
        $sin = [Math]::Sin($time + $this.PhaseOffset)
        $intensity = ($sin + 1.0) / 2.0

        $r = [int]([Particle]::ColorLow[0] + ([Particle]::ColorHigh[0] - [Particle]::ColorLow[0]) * $intensity)
        $g = [int]([Particle]::ColorLow[1] + ([Particle]::ColorHigh[1] - [Particle]::ColorLow[1]) * $intensity)
        $b = [int]([Particle]::ColorLow[2] + ([Particle]::ColorHigh[2] - [Particle]::ColorLow[2]) * $intensity)

        # Append ANSI sequence to the frame buffer
        [void]$buffer.Append("$e[$($this.Y);$($this.X)H$e[38;2;$r;$g;$b`m$($this.Char)")
    }
}

# --- Main Setup ---
[Particle]::ConfigureTheme($ColorMode)
$origVisible = [Console]::CursorVisible
$origBg = [Console]::BackgroundColor

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::CursorVisible = $false
    $e = [char]27
    $BgColor ="$e[48;2;30;30;46m"

    # Setup Buffer
    $FrameBuffer = [System.Text.StringBuilder]::new()

    # Clear Screen
    [Console]::Out.Write("$e[?25l$BgColor$e[2J$e[H")

    $W = [Console]::WindowWidth
    $H = [Console]::WindowHeight

    $Particles = [System.Collections.Generic.List[Particle]]::new()
    for ($i = 0; $i -lt $Density; $i++) {
        $Particles.Add([Particle]::new($W, $H))
    }

    $GlobalTime = 0.0

    while ($true) {
        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq "Escape") { break }
        }

        # Clear buffer for new frame
        [void]$FrameBuffer.Clear()

        if ([Console]::WindowWidth -ne $W -or [Console]::WindowHeight -ne $H) {
            $W = [Console]::WindowWidth; $H = [Console]::WindowHeight
            [Console]::Out.Write("$e[2J")
            $Particles.Clear()
            for ($i = 0; $i -lt $Density; $i++) { $Particles.Add([Particle]::new($W, $H)) }
        }

        # Render all particles to buffer
        foreach ($p in $Particles) {
            $p.Render($GlobalTime, $FrameBuffer)
        }
        
        # --- BATCH WRITE (Eliminates Flicker) ---
        [Console]::Out.Write($FrameBuffer.ToString())

        $GlobalTime += ($Speed / 50.0)
        Start-Sleep -Milliseconds 30
    }

} finally {
    $e = [char]27
    [Console]::Out.Write("$e[0m$e[?25h$e[2J$e[H")
    [Console]::CursorVisible = $origVisible
    [Console]::BackgroundColor = $origBg
}
