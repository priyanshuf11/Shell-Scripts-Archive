
# ================= CONFIG =================
$ProjectRoots = @(
  "$env:USERPROFILE\Projects",
  "$env:USERPROFILE\Documents\shortcuts\Projects",
  "F:\Projects",
  "$env:USERPROFILE\Documents\DSA_Questions\"
)

# How many commits to show
$Limit = 10 

# ================= CATPPUCCIN COLORS (MOCHA) =================
$e = [char]27
$C = @{
    Reset     = "$e[0m"
    Mauve     = "$e[38;2;203;166;247m" 
    Lavender  = "$e[38;2;180;190;254m" 
    Subtext1  = "$e[38;2;186;194;222m" 
    Subtext0  = "$e[38;2;166;173;200m" 
    Green     = "$e[38;2;166;227;161m" 
    Yellow    = "$e[38;2;249;226;175m" 
    Peach     = "$e[38;2;250;179;135m" 
    Red       = "$e[38;2;243;139;168m" 
    Overlay   = "$e[38;2;147;153;178m" 
}

# ================= FIND REPOS =================
Write-Host "$($C.Overlay)Scanning repositories...$($C.Reset)"

$GitRepos = foreach ($root in $ProjectRoots) {
  if (Test-Path $root) {
    Get-ChildItem $root -Recurse -Depth 4 -Directory -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq ".git" } |
      ForEach-Object { $_.Parent }
  }
}

# ================= FETCH COMMITS =================
$AllCommits = @()

foreach ($Repo in $GitRepos) {
  Push-Location $Repo.FullName
  try {
    # Fetch last 5 commits from each repo
    # Format: UnixTimestamp | Hash | AuthorName | Message
    $LogCommand = git log -n 5 --format="%at|%h|%an|%s" 2>$null 
    
    if ($LogCommand) {
      foreach ($line in $LogCommand) {
        # Split into max 4 parts to keep message intact
        $parts = $line -split "\|", 4
        if ($parts.Count -eq 4) {
             $AllCommits += [PSCustomObject]@{
                Timestamp = [int64]$parts[0]
                Hash      = $parts[1]
                Author    = $parts[2]
                Message   = $parts[3]
                Repo      = $Repo.Name
            }
        }
      }
    }
  } catch {}
  Pop-Location
}

# Sort by time descending and take top N
$RecentCommits = $AllCommits | Sort-Object Timestamp -Descending | Select-Object -First $Limit

# ================= RENDER SETTINGS =================
$BoxWidth   = 85
$InnerWidth = $BoxWidth - 2

function Truncate($str, $len) {
    if ($str.Length -gt $len) { return $str.Substring(0, $len-2) + ".." }
    return $str
}

# ================= OUTPUT =================
Write-Host ""

# Define simple ASCII borders
$BorderLine = '-' * $InnerWidth
$TopBorder  = "+$BorderLine+"
$MidBorder  = "+$BorderLine+"
$BotBorder  = "+$BorderLine+"

# 1. Top Border
Write-Host "$($C.Lavender)$TopBorder$($C.Reset)"

# 2. Header
$Title = "RECENT GIT ACTIVITY"
$TPadL = [math]::Floor(($InnerWidth - $Title.Length) / 2)
$TPadR = [math]::Ceiling(($InnerWidth - $Title.Length) / 2)
Write-Host "$($C.Lavender)|$(' ' * $TPadL)$($C.Mauve)$Title$(' ' * $TPadR)$($C.Lavender)|$($C.Reset)"

# 3. Separator
Write-Host "$($C.Lavender)$MidBorder$($C.Reset)"

# 4. Rows
if ($RecentCommits.Count -eq 0) {
    $Msg = "No recent commits found."
    $Pad = " " * ($InnerWidth - $Msg.Length)
    Write-Host "$($C.Lavender)|$($C.Subtext0)$Msg$Pad$($C.Lavender)|$($C.Reset)"
} else {
    foreach ($commit in $RecentCommits) {
        # Convert Timestamp
        $DateObj = (Get-Date "1970-01-01 00:00:00").AddSeconds($commit.Timestamp).ToLocalTime()
        $DateStr = $DateObj.ToString("MM-dd HH:mm")
        
        # Truncate Data
        $RepoStr = Truncate $commit.Repo 15
        
        # Calc Message Width: 
        # Total(85) - Border(2) - Margin(2) - Date(11) - Space(1) - Repo(15) - Space(1) = 53
        $MsgWidth = $InnerWidth - 11 - 1 - 15 - 1 - 2
        $MsgStr   = Truncate $commit.Message $MsgWidth
        
        # Format
        $FmtDate = "{0,-11}" -f $DateStr
        $FmtRepo = "{0,-15}" -f $RepoStr
        
        # Padding Calculation
        $CurrentLen = $FmtDate.Length + 1 + $FmtRepo.Length + 1 + $MsgStr.Length
        $PadLen = $InnerWidth - $CurrentLen
        if ($PadLen -lt 0) { $PadLen = 0 }
        $Padding = " " * $PadLen

        # Construct content
        $Content = "$($C.Green)$FmtDate $($C.Peach)$FmtRepo $($C.Subtext1)$MsgStr$Padding"
        
        # Final Print with Pipe | separators
        Write-Host "$($C.Lavender)| $Content$($C.Lavender)|$($C.Reset)"
    }
}

# 5. Bottom Border
Write-Host "$($C.Lavender)$BotBorder$($C.Reset)"
Write-Host ""
