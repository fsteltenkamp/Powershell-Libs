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

function Update-Libs {
    param (
        [string[]]$Libs
    )

    # Get current directory:
    $currentDir = Get-Location
    # Take the path of the current script and append the libs folder
    $libsPath = "${currentDir}\libs"

    # Check if the libs folder exists
    if (-not (Test-Path -Path $libsPath)) {
        # Create the folder:
        New-Item -ItemType Directory -Path $libsPath
    }

    # Get which libraries should be imported:
    if ($Libs.Count -eq 0) {
        # If no libraries are specified, quit.
        Write-Host "No libraries specified for import. Exiting."
        exit 0
    } else {
        Write-Host "Libraries specified for import: $($Libs -join ', ')"
    }

    # Loop through the specified libraries, update and import them:
    foreach ($lib in $Libs) {
        Write-Host "Processing library: ${lib}"
        $libPath = "${libsPath}\${lib}.ps1"
        # Update it:
        $updateUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/libs/${lib}.ps1"
        $verUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/versions/${lib}.version"
        # Get the latest version number from the repository:
        try {
            $latestVersion = (Invoke-WebRequest -Uri $verUrl -UseBasicParsing).Content.Trim()
        } catch {
            Write-Host "Error fetching version for $lib."
            continue
        }
        # Check if the library file exists locally:
        if (Test-Path -Path $libPath) {
            # If it exists, read the local version number:
            $localVersion = Get-Content -Path $libPath -Raw | Select-String -Pattern '# Version : (\d+\.\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
            if ($localVersion -ne $latestVersion) {
                Write-Host "Updating ${lib} from version ${localVersion} to ${latestVersion}..."
                try {
                    Invoke-WebRequest -Uri $updateUrl -OutFile $libPath -UseBasicParsing
                } catch {
                    Write-Host "Error updating ${lib}: ${_}"
                }
            } else {
                Write-Host "$lib is already up to date (version ${localVersion})."
            }
        } else {
            # If it doesn't exist, download it:
            Write-Host "Downloading ${lib} version ${latestVersion}..."
            try {
                Invoke-WebRequest -Uri $updateUrl -OutFile $libPath -UseBasicParsing
            } catch {
                Write-Host "Error downloading ${lib}: ${_}"
            }
        }
        # Import the library:
        try {
            . $libPath
            Write-Host "${lib} imported successfully."
        } catch {
            Write-Host "Error importing ${lib}: ${_}"
        }
    }
}