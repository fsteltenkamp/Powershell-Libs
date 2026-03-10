<#
    .SYNOPSIS
        Automatically updates and imports libraries

    .DESCRIPTION
        This script checks for updates to the libraries and imports them into the current session.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 0.1
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function log {
    param (
        [string]$message,
        [bool]$Verbose
    )
    if ($Verbose) {
        Write-Host "$message"
    }
}

function Update-Libs {
    param (
        [string[]]$Libs
        [switch]$Verbose
        [switch]$Force
    )

    # Resolve the libs folder relative to the updater module's own location
    $libsPath = "${PSScriptRoot}\libs"

    # Check if the libs folder exists
    if (-not (Test-Path -Path $libsPath)) {
        # Create the folder:
        New-Item -ItemType Directory -Path $libsPath -Force | Out-Null
        log "| Created libs folder at ${libsPath}" -Verbose $Verbose
    }

    log "+-----------------------------------------------------------------------+" -Verbose $Verbose
    log "|                     Updating and Importing Libraries                  |" -Verbose $Verbose
    log "+-----------------------------------------------------------------------+" -Verbose $Verbose
    
    # Get which libraries should be imported:
    if ($Libs.Count -eq 0) {
        # If no libraries are specified, quit.
        log "| No libraries specified for import. Exiting." -Verbose $Verbose
        exit 0
    } else {
        log "| Libraries specified for import: $($Libs -join ', ')" -Verbose $Verbose
    }

    # Loop through the specified libraries, update and import them:
    foreach ($lib in $Libs) {
        log "+-------- Processing library: ${lib}" -Verbose $Verbose
        $libPath = "${libsPath}\${lib}.psm1"
        log "| Library path: ${libPath}" -Verbose $Verbose
        # Update it:
        $updateUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/libs/${lib}.psm1"
        $verUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/versions/${lib}.version"
        # Get the latest version number from the repository:
        try {
            $latestVersion = (Invoke-WebRequest -Uri $verUrl -UseBasicParsing).Content.Trim()
        } catch {
            log "| Error fetching version for $lib." -Verbose $Verbose
            continue
        }
        # Check if the library file exists locally:
        if (Test-Path -Path $libPath) {
            # If it exists, read the local version number:
            $localVersion = Get-Content -Path $libPath -Raw | Select-String -Pattern 'Version : (\d+\.\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
            if ($localVersion -ne $latestVersion) {
                log "| Updating ${lib} from version ${localVersion} to ${latestVersion}..." -Verbose $Verbose
                try {
                    Invoke-WebRequest -Uri $updateUrl -OutFile $libPath -UseBasicParsing
                } catch {
                    log "| Error updating ${lib}: ${_}" -Verbose $Verbose
                }
            } else {
                log "| $lib is already up to date (version ${localVersion})." -Verbose $Verbose
            }
        } else {
            # If it doesn't exist, download it:
            log "| Downloading ${lib} version ${latestVersion}..." -Verbose $Verbose
            try {
                Invoke-WebRequest -Uri $updateUrl -OutFile $libPath -UseBasicParsing
            } catch {
                log "| Error downloading ${lib}: ${_}" -Verbose $Verbose
            }
        }
        # Import the library into the global session scope so the caller can use it:
        try {
            Import-Module $libPath -Force -Global
            log "| ${lib} imported successfully." -Verbose $Verbose
        } catch {
            log "| Error importing ${lib}: ${_}" -Verbose $Verbose
        }
    }

    log "+-----------------------------------------------------------------------+" -Verbose $Verbose
}

Export-ModuleMember -Function Update-Libs