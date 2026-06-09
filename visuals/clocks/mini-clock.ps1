# ================= SETUP =================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$b = [char]0x2588 

# Hide Cursor
try { $Host.UI.RawUI.CursorSize = 0 } catch {}

# ================= COLORS (Foreground Only) =================
$e = [char]27
$C = @{
    Reset    = "$e[0m"
    White    = "$e[38;2;248;250;252m" 
    Green    = "$e[38;2;166;227;161m" 
    Mauve    = "$e[38;2;203;166;247m" 
    Peach    = "$e[38;2;250;179;135m" 
    Red      = "$e[38;2;243;139;168m" 
    Colon    = "$e[38;2;147;153;178m" 
    Date     = "$e[38;2;137;180;250m" 
}

$ColorMap = @{
    '1' = $C.Green
    '2' = $C.Mauve
    '3' = $C.Peach
    '4' = $C.Red
    ':' = $C.Colon
}

# ================= 5x3 DIGITAL STRUCTURE =================
$Patterns = @{
    '0' = @("111","101","101","101","111")
    '1' = @("010","110","010","010","111")
    '2' = @("111","001","111","100","111")
    '3' = @("111","001","111","001","111")
    '4' = @("101","101","111","001","001")
    '5' = @("111","100","111","001","111")
    '6' = @("111","100","111","101","111")
    '7' = @("111","001","001","001","001")
    '8' = @("111","101","111","101","111")
    '9' = @("111","101","111","001","111")
    ':' = @("000","010","000","010","000")
}

# Convert logic to blocks
$Digits = @{}
foreach ($key in $Patterns.Keys) {
    $Digits[$key] = foreach ($line in $Patterns[$key]) {
        $line -replace '1', "$b$b" -replace '0', "  "
    }
}

function Center-Text($text, $width) {
    $pad = [math]::Max(0, [math]::Floor(($width - $text.Length) / 2))
    return (" " * $pad) + $text
}

# ================= MAIN LOOP =================
Clear-Host

try {
    while ($true) {
        $Now = Get-Date
        # CHANGED: Format to Hours and Minutes only
        $TimeStr = $Now.ToString("HH:mm")
        $DateStr = $Now.ToString("D") 

        $Width  = $Host.UI.RawUI.WindowSize.Width
        $Height = $Host.UI.RawUI.WindowSize.Height
        
        $DigitWidth = ($Digits['0'][0]).Length
        # Spacing calculation: Digits + 2 spaces between each
        $ClockWidth = ($DigitWidth + 2) * $TimeStr.Length
        
        $StartX = [math]::Max(0, [math]::Floor(($Width - $ClockWidth) / 2))
        $StartY = [math]::Max(0, [math]::Floor(($Height - 6) / 2)) 

        # 1. DRAW CLOCK
        for ($row = 0; $row -lt 5; $row++) {
            [Console]::SetCursorPosition($StartX, $StartY + $row)
            foreach ($char in $TimeStr.ToCharArray()) {
                $Art = $Digits["$char"]
                $Color = if ($ColorMap.ContainsKey($char)) { $ColorMap[$char] } else { $C.White }
                Write-Host "$($Color)$($Art[$row])  " -NoNewline
            }
        }

        # 2. DRAW DATE
        $DateY = $StartY + 6
        [Console]::SetCursorPosition(0, $DateY)
        Write-Host "$($C.Date)$(Center-Text $DateStr $Width)$($C.Reset)" -NoNewline

        # Sleep longer since we don't need to update seconds
        Start-Sleep -Seconds 1
    }
}
finally {
    Write-Host $C.Reset
    try { $Host.UI.RawUI.CursorSize = 25 } catch {}
}
