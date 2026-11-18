
# ============================================================
# Update-DevTools.ps1
#
# Developer Tools Updater - Regular User
# Windows PowerShell 5.1
#
# Updates:
#   1. Global Laravel Installer
#   2. GitHub CLI (via WinGet)
#   3. PIE (verified GitHub release)
#   4. Node.js (latest LTS via fnm)
#   5. npm (latest stable)
#
# Composer itself is updated separately as administrator.
# PHP, Xdebug and project dependencies are not updated.
#
# Log is cleared at the beginning of each run.
# ============================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LogDirectory = Join-Path $env:LOCALAPPDATA 'DevToolsUpdater'
$LogFile = Join-Path $LogDirectory 'updates.log'
$PiePath = 'C:\tools\pie.exe'

New-Item -ItemType Directory -Path $LogDirectory -Force |
    Out-Null

# Clear previous log.
if (Test-Path -LiteralPath $LogFile) {
    Clear-Content -LiteralPath $LogFile
}
else {
    New-Item -ItemType File -Path $LogFile -Force |
        Out-Null
}

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"

    Add-Content -LiteralPath $LogFile -Value $line
    Write-Host $line
}

function Find-Tool {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($command) {
            return $command.Source
        }
    }

    return $null
}

# Run commands with stdout and stderr captured separately.
# Only the exit code determines success.
function Invoke-Tool {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments = @()
    )

    Write-Log "Starting $Name"

    $stdout = Join-Path $env:TEMP (
        [guid]::NewGuid().ToString() + '.out'
    )

    $stderr = Join-Path $env:TEMP (
        [guid]::NewGuid().ToString() + '.err'
    )

    try {
        $process = Start-Process `
            -FilePath $Executable `
            -ArgumentList $Arguments `
            -Wait `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr

        foreach ($file in @($stdout, $stderr)) {
            if (Test-Path -LiteralPath $file) {
                Get-Content -LiteralPath $file | ForEach-Object {
                    if (-not [string]::IsNullOrWhiteSpace($_)) {
                        Write-Log "  $_"
                    }
                }
            }
        }

        if ($process.ExitCode -ne 0) {
            Write-Log "FAILED: $Name (exit code $($process.ExitCode))"
            return $false
        }

        Write-Log "SUCCESS: $Name"
        return $true
    }
    catch {
        Write-Log "FAILED: $Name - $($_.Exception.Message)"
        return $false
    }
    finally {
        Remove-Item $stdout, $stderr `
            -Force -ErrorAction SilentlyContinue
    }
}

function Get-LatestNodeLts {
    param([string]$FnmPath)

    $out = Join-Path $env:TEMP (
        [guid]::NewGuid().ToString() + '.txt'
    )

    try {
        $process = Start-Process `
            -FilePath $FnmPath `
            -ArgumentList @('list-remote', '--lts') `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $out

        if ($process.ExitCode -ne 0) {
            throw 'fnm list-remote --lts failed'
        }

        $content = Get-Content $out -Raw

        $found = [regex]::Matches(
            $content, 'v\d+\.\d+\.\d+'
        )

        if ($found.Count -eq 0) {
            throw 'No Node.js LTS versions found'
        }

        $versions = @(
            $found | ForEach-Object {
                [version]$_.Value.TrimStart('v')
            } | Sort-Object -Unique
        )

        return $versions[-1].ToString()
    }
    finally {
        Remove-Item $out -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# GitHub CLI update
# ============================================================

function Update-GitHubCli {
    $winget = Find-Tool @('winget.exe', 'winget')

    if (-not $winget) {
        Write-Log 'SKIPPED: GitHub CLI (WinGet not found)'
        return
    }

    $gh = Find-Tool @('gh.exe', 'gh')

    if (-not $gh) {
        Write-Log 'SKIPPED: GitHub CLI not installed'
        return
    }

    Write-Log 'Checking GitHub CLI updates through WinGet'

    $stdout = Join-Path $env:TEMP (
        [guid]::NewGuid().ToString() + '.out'
    )
    $stderr = Join-Path $env:TEMP (
        [guid]::NewGuid().ToString() + '.err'
    )

    try {
        $process = Start-Process `
            -FilePath $winget `
            -ArgumentList @(
                'upgrade',
                '--id',
                'GitHub.cli',
                '--exact',
                '--accept-source-agreements',
                '--disable-interactivity'
            ) `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdout `
            -RedirectStandardError $stderr

        $output = Get-Content $stdout -Raw

        # WinGet may return a nonzero exit code when no
        # upgrade is available. This is not a failure.
        if ($output -match 'No available upgrade found|No newer package versions are available') {
            Write-Log 'SUCCESS: GitHub CLI already current'
            return
        }

        if ($process.ExitCode -ne 0) {
            $errorOutput = Get-Content $stderr -Raw `
                -ErrorAction SilentlyContinue

            throw "WinGet check failed (exit code $($process.ExitCode)): $output $errorOutput"
        }

        # WinGet includes a package row when an upgrade
        # is available.
        $upgradeAvailable = $output -match '(?m)^\s*GitHub CLI\s+GitHub\.cli\s+'

        if (-not $upgradeAvailable) {
            Write-Log 'SUCCESS: GitHub CLI already current'
            return
        }

        Write-Log 'GitHub CLI upgrade available'

        $updated = Invoke-Tool `
            -Name 'GitHub CLI upgrade' `
            -Executable $winget `
            -Arguments @(
                'upgrade',
                '--id',
                'GitHub.cli',
                '--exact',
                '--silent',
                '--accept-package-agreements',
                '--accept-source-agreements',
                '--disable-interactivity'
            )

        if (-not $updated) {
            Write-Log 'WARNING: GitHub CLI upgrade unsuccessful'
        }
    }
    finally {
        Remove-Item $stdout, $stderr `
            -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# PIE update
# ============================================================

function Update-Pie {
    Write-Log 'Checking latest stable PIE release'

    $release = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/php/pie/releases/latest' `
        -Headers @{ 'User-Agent' = 'DevToolsUpdater' }

    $asset = $release.assets |
        Where-Object {
            $_.name -eq 'pie-Windows-X64.exe'
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw 'Windows x64 PIE asset not found'
    }

    $latestVersion = [version](
        $release.tag_name.TrimStart('v')
    )

    $installedVersion = $null

    if (Test-Path -LiteralPath $PiePath) {
        $versionText = & $PiePath --version | Out-String

        if ($LASTEXITCODE -eq 0 -and
            $versionText -match 'PIE\)\s+(\d+\.\d+\.\d+)') {
            $installedVersion = [version]$Matches[1]
        }
    }

    Write-Log "Latest PIE version: $latestVersion"

    if ($installedVersion) {
        Write-Log "Installed PIE version: $installedVersion"

        if ($installedVersion -ge $latestVersion) {
            Write-Log 'SUCCESS: PIE already current'
            return
        }
    }

    $gh = Find-Tool @('gh.exe', 'gh')

    if (-not $gh) {
        throw 'GitHub CLI required for PIE verification'
    }

    $tempDir = Join-Path $env:TEMP (
        'pie-update-' + [guid]::NewGuid().ToString()
    )

    New-Item -ItemType Directory -Path $tempDir |
        Out-Null

    $download = Join-Path $tempDir 'pie-Windows-X64.exe'
    $backup = "$PiePath.bak"
    $hadExisting = Test-Path -LiteralPath $PiePath

    try {
        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $download `
            -UseBasicParsing

        if ($asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
            throw 'Release asset has no valid SHA-256 digest'
        }

        $expectedHash = $Matches[1]
        $actualHash = (
            Get-FileHash $download -Algorithm SHA256
        ).Hash

        if ($actualHash -ne $expectedHash) {
            throw 'PIE SHA-256 verification failed'
        }

        Write-Log 'SUCCESS: PIE SHA-256 verified'

        $verified = Invoke-Tool `
            -Name 'PIE GitHub attestation verification' `
            -Executable $gh `
            -Arguments @(
                'attestation',
                'verify',
                $download,
                '--repo',
                'php/pie'
            )

        if (-not $verified) {
            throw 'PIE attestation verification failed'
        }

        $newVersionText = & $download --version | Out-String

        if ($LASTEXITCODE -ne 0 -or
            $newVersionText -notmatch 'PIE\)\s+(\d+\.\d+\.\d+)') {
            throw 'Downloaded PIE failed version validation'
        }

        if ([version]$Matches[1] -ne $latestVersion) {
            throw 'Downloaded PIE version does not match release'
        }

        $pieDirectory = Split-Path -Parent $PiePath

        New-Item -ItemType Directory -Path $pieDirectory `
            -Force | Out-Null

        if ($hadExisting) {
            Copy-Item $PiePath $backup -Force
        }

        try {
            Copy-Item $download $PiePath -Force

            $check = & $PiePath --version | Out-String

            if ($LASTEXITCODE -ne 0 -or
                $check -notmatch 'PIE\)\s+(\d+\.\d+\.\d+)') {
                throw 'Installed PIE failed validation'
            }

            if ([version]$Matches[1] -ne $latestVersion) {
                throw 'Installed PIE has incorrect version'
            }

            Write-Log "SUCCESS: PIE updated to $latestVersion"
        }
        catch {
            Write-Log 'PIE installation failed; attempting rollback'

            if ($hadExisting -and (Test-Path $backup)) {
                Copy-Item $backup $PiePath -Force
            }
            elseif (-not $hadExisting) {
                Remove-Item $PiePath -Force `
                    -ErrorAction SilentlyContinue
            }

            throw
        }
    }
    finally {
        Remove-Item $tempDir -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Main updater
# ============================================================

Write-Log '=== Developer tools update started ==='

try {

    # 1. Global Laravel Installer
    $composer = Find-Tool @(
        'composer.bat',
        'composer.cmd',
        'composer.exe',
        'composer'
    )

    if ($composer) {
        Invoke-Tool `
            -Name 'Global Laravel Installer' `
            -Executable $composer `
            -Arguments @(
                'global',
                'update',
                'laravel/installer',
                '--no-interaction',
                '--no-progress'
            ) | Out-Null
    }
    else {
        Write-Log 'SKIPPED: Laravel Installer (Composer missing)'
    }

    # 2. GitHub CLI
    try {
        Update-GitHubCli
    }
    catch {
        Write-Log "FAILED: GitHub CLI - $($_.Exception.Message)"
    }

    # 3. PIE
    try {
        Update-Pie
    }
    catch {
        Write-Log "FAILED: PIE - $($_.Exception.Message)"
    }

    # 4. Node.js LTS
    $fnm = Find-Tool @('fnm.exe', 'fnm')

    if ($fnm) {
        try {
            $latestLts = Get-LatestNodeLts $fnm

            Write-Log "Latest Node.js LTS: $latestLts"

            $nodeInstalled = Invoke-Tool `
                -Name 'Node.js latest LTS' `
                -Executable $fnm `
                -Arguments @('install', $latestLts)

            if ($nodeInstalled) {
                Invoke-Tool `
                    -Name 'Set default Node.js LTS' `
                    -Executable $fnm `
                    -Arguments @('default', $latestLts) |
                    Out-Null
            }
        }
        catch {
            Write-Log "FAILED: Node.js - $($_.Exception.Message)"
        }

        # 5. npm
        try {
            Write-Log 'Initializing fnm environment'

            $fnmEnvironment = & $fnm env --shell powershell |
                Out-String

            if ($LASTEXITCODE -ne 0) {
                throw 'fnm environment initialization failed'
            }

            Invoke-Expression $fnmEnvironment

            & $fnm use default | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw 'fnm use default failed'
            }

            $node = Find-Tool @('node.exe', 'node')
            $npm = Find-Tool @('npm.cmd', 'npm')

            if (-not $node -or -not $npm) {
                throw 'Node.js or npm not found'
            }

            Write-Log "Active Node.js: $(& $node --version)"

            Invoke-Tool `
                -Name 'npm latest stable' `
                -Executable $npm `
                -Arguments @(
                    'install',
                    '--global',
                    'npm@latest',
                    '--no-audit',
                    '--no-fund'
                ) | Out-Null
        }
        catch {
            Write-Log "FAILED: npm - $($_.Exception.Message)"
        }
    }
    else {
        Write-Log 'SKIPPED: Node.js and npm (fnm missing)'
    }
}
catch {
    Write-Log "UNEXPECTED ERROR: $($_.Exception.Message)"
}
finally {
    Write-Log '=== Developer tools update finished ==='
}
