<#
.SYNOPSIS
    A lightning-fast project navigator for terminal-centric workflows.

.DESCRIPTION
    Maps directories to alphabetical keys, prioritizing home-row keys (f, g, h, i, j, k) 
    for frequently used projects.
.PARAMETER Selection
    The key mapped to a specific project. If empty, displays the navigation menu.

.EXAMPLE
    ./Navigator.ps1 f
    Jumps to the first special project.
    tip: use profile function like `goto` or `g`
.NOTES
    Author: Priyanshu Farkonde (gh: priyanshuf11)
    Version: 1.0
    Requirements: A terminal with Nerd Font support (e.g., Cascadia Code NF, JetBrainsMono NF).
#>
     
param ([string]$Selection)

#----Configuration----
# Root folder(s) containing your repositories
$Roots = @(
    # "$env:USERPROFILE\Projects",
)

# priority projects can be moved to more ergonomic position to reach faster
# priority projects mapped to 'f,g,h,i,j,k'
$Specials = @(
    # "ProjectXYZ",
)

# 1. Gather all projects
$AllDirs = @(
    foreach ($Root in $Roots) {
        if (Test-Path $Root) {
            Get-ChildItem -Path $Root -Directory -Exclude "node_modules" | Select-Object -ExpandProperty Name
        }
    }
) | Select-Object -Unique | Sort-Object

$Others = $AllDirs | Where-Object { 
    $dir = $_
    -not ($Specials | Where-Object { $_ -ieq $dir })
}

# 2. Build the Map
$FinalMap = @{}
$otherIdx = 0
$specialIdx = 0
$HomeRowKeys = @('f','g','h','i','j','k')

foreach ($ascii in 97..122) {
    $char = [char]$ascii
    if ($HomeRowKeys -contains $char) {
        if ($specialIdx -lt $Specials.Count) {
            $FinalMap[$char] = $Specials[$specialIdx]
            $specialIdx++
        }
    }
    else {
        if ($otherIdx -lt $Others.Count) {
            $FinalMap[$char] = $Others[$otherIdx]
            $otherIdx++
        }
    }
}

$glyph = [char]::ConvertFromUtf32(0xF07B) # Nerd Font Folder Icon

# --- LOGIC ---

# 3. Handle 'Home' Jump (~ or ;)
if ($Selection -eq "~" -or $Selection -eq ";") {
    Set-Location $env:USERPROFILE
    Write-Host "$glyph User Home" -ForegroundColor Blue
    return
}

# 4. Handle Menu Rendering
if ([string]::IsNullOrWhiteSpace($Selection)) {
    Write-Host "`n  Project Navigator" -ForegroundColor Magenta
    
    # Render the ROOT option at the top
    Write-Host " [~] " -NoNewline -ForegroundColor Gray
    Write-Host "User Home (Root)" -ForegroundColor Cyan

    foreach ($ascii in 97..122) {
        $char = [char]$ascii
        if ($FinalMap.ContainsKey($char)) {
            $isHome = $HomeRowKeys -contains $char
            $indexColor = if ($isHome) { "White" } else { "DarkGray" }
            $projColor = if ($isHome) { "Yellow" } else { "Cyan" }
            
            Write-Host " [$char] " -NoNewline -ForegroundColor $indexColor
            Write-Host "$($FinalMap[$char])" -ForegroundColor $projColor
        }
    }
    Write-Host ""
}
# 5. Handle Project Jump
else {
    $inputChar = $Selection.ToLower()[0]
    if ($FinalMap.ContainsKey($inputChar)) {
        $ProjName = $FinalMap[$inputChar]
        foreach ($Root in $Roots) {
            $Target = Join-Path $Root $ProjName
            if (Test-Path $Target) {
                Set-Location $Target
                $glyph = [char]::ConvertFromUtf32(0xF07B)
                Write-Host "$glyph $ProjName" -ForegroundColor Green
                return
            }
        }
    } else {
        Write-Host "No project assigned to: $Selection" -ForegroundColor Red
    }
}
