
# ============================================================
# Update-Composer.ps1
#
# Updates Composer to the latest stable version.
# Requires administrator privileges.
# Windows PowerShell 5.1
# ============================================================

$ErrorActionPreference = 'Stop'

$LogDirectory = Join-Path $env:ProgramData 'DevToolsUpdater'
$LogFile = Join-Path $LogDirectory 'composer.log'
$Composer = 'C:\ProgramData\ComposerSetup\bin\composer.bat'

New-Item -ItemType Directory -Path $LogDirectory -Force |
    Out-Null

# Clear log at the start of each run.
Set-Content -Path $LogFile -Value ''

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] $Message"

    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

Write-Log '=== Composer update started ==='

try {
    # Verify administrator privileges.
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw 'Administrator privileges required'
    }

    if (-not (Test-Path $Composer)) {
        throw "Composer not found: $Composer"
    }

    # Check installed version.
    $before = & $Composer --version --no-ansi
    Write-Log "Before: $before"

    # Update Composer.
    & $Composer self-update --stable --no-interaction --no-ansi

    if ($LASTEXITCODE -ne 0) {
        throw "Composer self-update failed (exit code $LASTEXITCODE)"
    }

    # Verify updated version.
    $after = & $Composer --version --no-ansi

    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to verify Composer version'
    }

    Write-Log "After: $after"
    Write-Log 'SUCCESS: Composer update completed'
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Log '=== Composer update finished ==='
}
