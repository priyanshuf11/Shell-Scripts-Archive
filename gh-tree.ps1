param(
    [Parameter(Mandatory=$true)]
    [string]$Target,

    [int]$Depth = 3
)

# ================= CONFIG =================
$IgnoreList = @(
    "node_modules", ".git", ".github", ".next", ".vscode", ".idea", 
    "dist", "build", "coverage", "__pycache__", "venv", "env",
    ".DS_Store", "yarn.lock", "package-lock.json"
)

$Annotations = @{
    "package.json"       = "Node.js Config"
    "requirements.txt"   = "Python Dependencies"
    "Dockerfile"         = "Container Config"
    "docker-compose.yml" = "Multi-container Setup"
    "tsconfig.json"      = "TypeScript Config"
    "next.config.js"     = "Next.js Settings"
    "manage.py"          = "Django Entry"
    "app.py"             = "App Entry Point"
    "server.js"          = "Express Entry Point"
    ".env"               = "Env Variables"
    ".env.local"         = "Local Env"
    "README.md"          = "Documentation"
    "Cargo.toml"         = "Rust Config"
    "pom.xml"            = "Maven Config"
    "build.gradle"       = "Gradle Config"
}

# ================= COLORS & SYMBOLS =================
$e = [char]27
$C = @{
    Reset    = "$e[0m"
    Mauve    = "$e[38;2;203;166;247m" 
    Green    = "$e[38;2;166;227;161m" 
    Peach    = "$e[38;2;250;179;135m" 
    Lavender = "$e[38;2;180;190;254m" 
    Gray     = "$e[38;2;108;112;134m"
}

# Safe Tree Characters (Prevents Encoding Errors)
$Sym = @{
    Branch = "$([char]0x251C)$([char]0x2500)$([char]0x2500) " # ├── 
    Last   = "$([char]0x2514)$([char]0x2500)$([char]0x2500) " # └── 
    Pipe   = "$([char]0x2502)   "                             # │   
    Empty  = "    "
}

# ================= DATA FETCHING =================
$RootNode = @{}
$RootName = ""

# MODE 1: GITHUB URL
# Errror in API call, to be fixed in future
if ($Target -match "^https?://github\.com/([^/]+)/([^/]+)") {
    $Owner = $Matches[1]
    $Repo  = $Matches[2].TrimEnd(".git")
    $RootName = "$Owner/$Repo"
    
    Write-Host ""
    Write-Host "$($C.Lavender)Fetching from GitHub API...$($C.Reset)"

    try {
        $RepoInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo" -ErrorAction Stop
        $Branch = $RepoInfo.default_branch
        $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/git/trees/$Branch?recursive=1"
        $Json = Invoke-RestMethod -Uri $ApiUrl -ErrorAction Stop
        $RawItems = $Json.tree
    } catch {
        Write-Host "$($C.Red)Error: Could not fetch repo (Check URL or Private/Public status).$($C.Reset)"
        exit
    }

    foreach ($Item in $RawItems) {
        $PathParts = $Item.path -split "/"
        
        # Filtering
        $Skip = $false
        foreach ($Part in $PathParts) { if ($IgnoreList -contains $Part) { $Skip = $true; break } }
        if ($Skip) { continue }

        # Build Tree
        $Current = $RootNode
        foreach ($Part in $PathParts) {
            if (-not $Current.ContainsKey($Part)) {
                $Current[$Part] = @{ "_Type" = "Folder"; "_Children" = @{} }
            }
            if ($Part -eq $PathParts[-1] -and $Item.type -eq "blob") {
                 $Current[$Part]["_Type"] = "File"
            }
            $Current = $Current[$Part]["_Children"]
        }
    }

# MODE 2: LOCAL DIRECTORY
} else {
    if (Test-Path $Target) {
        $ResolvedPath = Resolve-Path $Target
        $RootName = Split-Path $ResolvedPath -Leaf
        
        Write-Host ""
        Write-Host "$($C.Lavender)Scanning Local Directory...$($C.Reset)"
        
        $Items = Get-ChildItem $ResolvedPath -Recurse -Depth $Depth -ErrorAction SilentlyContinue

        foreach ($Item in $Items) {
            # Get relative path
            $RelPath = $Item.FullName.Substring($ResolvedPath.Path.Length + 1)
            $PathParts = $RelPath -split "[\\/]"

            # Filtering
            $Skip = $false
            foreach ($Part in $PathParts) { if ($IgnoreList -contains $Part) { $Skip = $true; break } }
            if ($Skip) { continue }

            # Build Tree
            $Current = $RootNode
            foreach ($Part in $PathParts) {
                if (-not $Current.ContainsKey($Part)) {
                    $Current[$Part] = @{ "_Type" = "Folder"; "_Children" = @{} }
                }
                if ($Part -eq $PathParts[-1] -and -not $Item.PSIsContainer) {
                        $Current[$Part]["_Type"] = "File"
                }
                $Current = $Current[$Part]["_Children"]
            }
        }
    } else {
        Write-Host "$($C.Red)Error: Path not found.$($C.Reset)"
        exit
    }
}

# ================= RENDER LOGIC =================
function Show-Tree {
    param([hashtable]$Nodes, [string]$Prefix, [int]$Level)

    if ($Level -ge $Depth) { return }

    # Sort: Folders first, then Files
    $Keys = $Nodes.Keys | Sort-Object { 
        if ($Nodes[$_]["_Type"] -eq "Folder") { "0_$_" } else { "1_$_" } 
    }

    $Count = 0
    foreach ($Key in $Keys) {
        $Count++
        $IsLast = ($Count -eq $Keys.Count)
        
        if ($IsLast) {
            $Pointer = $Sym.Last
            $NextPrefix = $Prefix + $Sym.Empty
        } else {
            $Pointer = $Sym.Branch
            $NextPrefix = $Prefix + $Sym.Pipe
        }

        $Node = $Nodes[$Key]
        $Type = $Node["_Type"]
        
        # Color & Note
        $Note = ""
        if ($Type -eq "Folder") {
            $Color = $C.Mauve
            $Suffix = "/"
        } else {
            $Color = $C.Green
            $Suffix = ""
            if ($Annotations.ContainsKey($Key)) {
                $Note = "  $($C.Gray)<-- $($C.Peach)$($Annotations[$Key])"
            }
        }

        Write-Host "$($C.Lavender)$Prefix$Pointer$($Color)$Key$Suffix$($C.Reset)$Note"

        if ($Type -eq "Folder") {
            Show-Tree -Nodes $Node["_Children"] -Prefix $NextPrefix -Level ($Level + 1)
        }
    }
}

Write-Host "$($C.Mauve)$RootName/$($C.Reset)"
Show-Tree -Nodes $RootNode -Prefix "" -Level 0
Write-Host ""
