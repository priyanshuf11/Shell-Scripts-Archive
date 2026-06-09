# ================= SETUP =================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Hide Cursor
try { $Host.UI.RawUI.CursorSize = 0 } catch {}

# ================= COLORS (Catppuccin Mocha) =================
$e = [char]27
$C = @{
    Reset    = "$e[0m"
    Base     = "$e[48;2;30;30;46m"    # Background
    Clock    = "$e[38;2;203;166;247m" # Mauve (Purple-ish)
    Colon    = "$e[38;2;147;153;178m" # Overlay2
    Date     = "$e[38;2;137;180;250m" # Blue
}

# ================= THICK ASCII DIGITS =================
# 5 Lines High, 7 Characters Wide
$Digits = @{
    '0' = @(
        " ##### ",
        "##   ##",
        "##   ##",
        "##   ##",
        " ##### "
    )
    '1' = @(
        "   ##  ",
        "  ###  ",
        "   ##  ",
        "   ##  ",
        " ######"
    )
    '2' = @(
        " ##### ",
        "     ##",
        " ##### ",
        "##     ",
        "#######"
    )
    '3' = @(
        " ##### ",
        "     ##",
        " ##### ",
        "     ##",
        " ##### "
    )
    '4' = @(
        "##   ##",
        "##   ##",
        "#######",
        "     ##",
        "     ##"
    )
    '5' = @(
        "#######",
        "##     ",
        "#######",
        "     ##",
        "#######"
    )
    '6' = @(
        " ##### ",
        "##     ",
        "#######",
        "##   ##",
        " ##### "
    )
    '7' = @(
        "#######",
        "     ##",
        "    ## ",
        "   ##  ",
        "  ##   "
    )
    '8' = @(
        " ##### ",
        "##   ##",
        " ##### ",
        "##   ##",
        " ##### "
    )
    '9' = @(
        " ##### ",
        "##   ##",
        "#######",
        "     ##",
        " ##### "
    )
    ':' = @(
        "       ",
        "  ###  ",
        "       ",
        "  ###  ",
        "       "
    )
    ' ' = @(
        "       ",
        "       ",
        "       ",
        "       ",
        "       "
    )
}

function Center-Text($text, $width) {
    $pad = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
    return (" " * $pad) + $text + (" " * $pad)
}

# ================= MAIN LOOP =================
Clear-Host
# Set background
Write-Host "$($C.Base)$(' ' * ($Host.UI.RawUI.WindowSize.Width * $Host.UI.RawUI.WindowSize.Height))" -NoNewline

try {
    while ($true) {
        $Now = Get-Date
        $TimeStr = $Now.ToString("HH:mm:ss")
        $DateStr = $Now.ToString("D") # Long date format
        
        # Blink Logic for Colon
        if ($Now.Second % 2 -eq 0) {
            $DisplayTime = $TimeStr # Show colons
        } else {
            $DisplayTime = $TimeStr -replace ":", " " # Hide colons
        }

        $Width  = $Host.UI.RawUI.WindowSize.Width
        $Height = $Host.UI.RawUI.WindowSize.Height
        
        # Clock is approx 64 chars wide (8 chars * 7 width + spaces)
        $ClockWidth = 64
        $StartX = [math]::Max(0, [math]::Floor(($Width - $ClockWidth) / 2))
        $StartY = [math]::Max(0, [math]::Floor(($Height - 8) / 2)) 

        # 1. DRAW CLOCK
        for ($row = 0; $row -lt 5; $row++) {
            [Console]::SetCursorPosition($StartX, $StartY + $row)
            
            foreach ($char in $DisplayTime.ToCharArray()) {
                $Art = $Digits["$char"]
                # If it's a colon, dim it slightly, else use bright color
                $Color = if ($char -eq ':') { $C.Colon } else { $C.Clock }
                
                Write-Host "$($C.Base)$Color$($Art[$row]) $($C.Reset)" -NoNewline
            }
        }

        # 2. DRAW DATE
        $DateY = $StartY + 6
        [Console]::SetCursorPosition(0, $DateY)
        Write-Host "$($C.Base)$($C.Date)$(Center-Text $DateStr $Width)$($C.Reset)" -NoNewline

        Start-Sleep -Milliseconds 500
    }
}
finally {
    Write-Host $C.Reset
    try { $Host.UI.RawUI.CursorSize = 25 } catch {}
    Clear-Host
}
