<#
    Copyright (C) 2026  Florian Steltenkamp

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

    .SYNOPSIS
        Library for checking Veeam Backup & Replication services and components.

    .DESCRIPTION
        Provides functions to check the status of Veeam Backup & Replication services and components.
        Imports the SnapIn for 8,9,10 and the Module for 11,12,13 automatically based on the installed version.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.7
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Documentation:
        - https://helpcenter.veeam.com/docs/vbr/powershell/
#>

$snapInLoaded = $false
$moduleLoaded = $false

function Get-VeeamVersion {
    <#
    .SYNOPSIS
        Checks the installation status of Veeam Backup & Replication.
    #>
    # Get veeam version by checking the uninstall registry
    $displayName = "Veeam Backup & Replication"
    $registryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $registryKeyWow6432 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    # get values
    $veeamInstalled = Get-ChildItem -Path $registryKey, $registryKeyWow6432 -ErrorAction SilentlyContinue |
        Where-Object { $_.GetValue("DisplayName") -eq "$displayName" } |
        Select-Object @{Name="DisplayName"; Expression={$_.GetValue("DisplayName")}},
            @{Name="DisplayVersion"; Expression={$_.GetValue("DisplayVersion")}},
            @{Name="Publisher"; Expression={$_.GetValue("Publisher")}},
            @{Name="InstallDate"; Expression={$_.GetValue("InstallDate")}} -First 1
    if ($veeamInstalled) {
        return $veeamInstalled.DisplayVersion
    } else {
        Write-Host "Error: Veeam Backup & Replication is not installed."
        throw "Veeam Backup & Replication is not installed."
    }
}

function Get-LatestVeeamVersion {
    <#
    .SYNOPSIS
        Checks the latest available version of Veeam Backup & Replication.
    #>
    return "13.0.1.2067" # Fallback to latest known version in case the web request fails, to prevent errors in other functions that rely on this.
    # TODO: Implement web scraping to get the latest version from the Veeam website, or use an API if available.
}

function Import-VeeamPowershellModule {
    <#
    .SYNOPSIS
        Imports the Veeam Backup & Replication PowerShell module.
    .DESCRIPTION
        Detects the installed Veeam version and loads the appropriate
        PowerShell integration:
          - v8 / v9 / v10  → PSSnapIn  (VeeamPSSnapin)
          - v11+           → Module    (Veeam.Backup.PowerShell)
        Use -Debug to see detailed import diagnostics.
    #>
    [CmdletBinding()]
    param()

    $veeamVersion = Get-VeeamVersion
    $majorVersion = [int]($veeamVersion -split '\.')[0]
    Write-Host "Detected Veeam version string: $veeamVersion (major: $majorVersion)"

    if ($majorVersion -ge 8 -and $majorVersion -le 10) {
        # Veeam Backup & Replication v10 and lower use SnapIn
        $snapInName = "VeeamPSSnapin"
        Write-Host "Version $majorVersion requires PSSnapIn '$snapInName'."

        if (Get-PSSnapin -Name $snapInName -ErrorAction SilentlyContinue) {
            Write-Host "PSSnapIn '$snapInName' is already loaded."
        } else {
            # Verify the snap-in is registered on this system before loading
            $registered = Get-PSSnapin -Registered -Name $snapInName -ErrorAction SilentlyContinue
            if (-not $registered) {
                throw "PSSnapIn '$snapInName' is not registered on this system. Ensure the Veeam console is installed."
            }
            Write-Host "PSSnapIn '$snapInName' is registered — loading now."
            try {
                Add-PSSnapin -Name $snapInName -ErrorAction Stop
                Write-Host "PSSnapIn '$snapInName' loaded successfully."
            } catch {
                throw "Failed to load PSSnapIn '${snapInName}': $_"
            }
        }
        $script:snapInLoaded = $true
        $importedName = $snapInName

    } elseif ($majorVersion -ge 11) {
        # Veeam Backup & Replication v11 and higher use regular module
        $moduleName = "Veeam.Backup.PowerShell"
        Write-Host "Version $majorVersion requires module '$moduleName'."

        if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
            Write-Host "Module '$moduleName' is already loaded."
        } else {
            Write-Host "Module '$moduleName' not loaded — importing now."
            try {
                Import-Module $moduleName -ErrorAction Stop
                Write-Host "Module '$moduleName' imported successfully."
            } catch {
                throw "Failed to import module '${moduleName}': $_"
            }
        }
        $script:moduleLoaded = $true
        $importedName = $moduleName

    } else {
        throw "Unsupported Veeam Backup & Replication major version: $majorVersion (full: $veeamVersion)"
    }

    # Verify that Veeam commands are now available
    $probe = Get-Command -Name "Get-VBRJob" -ErrorAction SilentlyContinue
    if (-not $probe) {
        throw "Veeam commands not available after importing '$importedName'. Get-VBRJob was not found."
    }

    Write-Host "Post-import check passed — Get-VBRJob is available."
    Write-Host "Veeam PowerShell integration loaded via '$importedName' (v$veeamVersion)."
    return $true
}

function Get-VeeamJobs {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication backup jobs.
    #>
    try {
        $backupJobs = Get-VBRJob
        return $backupJobs
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication backup jobs: $_"
        throw "Failed to get Veeam Backup & Replication backup jobs: $_"
    }
}

function Get-FailedJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have failed in Veeam Backup & Replication.
    #>
    try {
        $jobs = Get-VeeamJobs
        $failedJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Failed" }
        return $failedJobs
    } catch {
        Write-Host "Error: Failed to get failed Veeam Backup & Replication jobs: $_"
        throw "Failed to get failed Veeam Backup & Replication jobs: $_"
    }
}

function Get-SuccessfulJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have not failed in Veeam Backup & Replication.
    #>
    try {
        $jobs = Get-VeeamJobs
        $successfulJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Success" }
        return $successfulJobs
    } catch {
        Write-Host "Error: Failed to get successful Veeam Backup & Replication jobs: $_"
        throw "Failed to get successful Veeam Backup & Replication jobs: $_"
    }
}

function Get-OtherJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have not failed or succeeded in Veeam Backup & Replication.
    #>
    try {
        $jobs = Get-VeeamJobs
        $otherJobs = $jobs | Where-Object { $_.GetLastResult() -ne "Failed" -and $_.GetLastResult() -ne "Success" }
        return $otherJobs
    } catch {
        Write-Host "Error: Failed to get other Veeam Backup & Replication jobs: $_"
        throw "Failed to get other Veeam Backup & Replication jobs: $_"
    }
}

function Get-VeeamSessions {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication sessions and their status.
    .PARAMETER JobName
        Optional. The name of the job to filter sessions by.
    .PARAMETER LastNDays
        Optional. The number of days to look back for sessions. Default is 7.
    .PARAMETER State
        Optional. The state to filter sessions by. Default is "Any".
    #>
    param (
        [string]$JobName,
        [int]$LastNDays = 7,
        [ValidateSet("Any", "None", "Success", "Warning", "Failed")]
        [string]$State = "Any"
    )
    try {
        $sessions = Get-VBRBackupSession |
            Where-Object { $_.CreationTime -ge (Get-Date).AddDays(-$LastNDays) }
        if ($JobName) {
            $sessions = $sessions | Where-Object { $_.JobName -eq $JobName }
        }
        if ($State -ne "Any") {
            $sessions = $sessions | Where-Object { $_.Result -eq $State }
        }
        return $sessions
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication sessions: $_"
        throw "Failed to get Veeam Backup & Replication sessions: $_"
    }
}

function Get-VeeamServices {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication services and their status.
    #>
    try {
        $services = Get-Service -Name "Veeam*"
        return $services
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication services: $_"
        throw "Failed to get Veeam Backup & Replication services: $_"
    }
}

function Get-VeeamRepositories {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication repositories and their status.
    #>
    try {
        return Get-VBRBackupRepository
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication repositories: $_"
        throw "Failed to get Veeam Backup & Replication repositories: $_"
    }
}

function Get-VeeamLicenseStatus {
    <#
    .SYNOPSIS
        Returns details about the license installed on the Veeam Backup & Replication server.
    .PARAMETER Verbose
        Optional. If set, returns detailed information about the license. Otherwise, returns only the license status.
    .PARAMETER Expiry
        Optional. If set, returns the number of days until the license expires.
    .NOTES
        Uses Get-VBRInstalledLicense.
        Documentation: https://helpcenter.veeam.com/docs/vbr/powershell/get-vbrinstalledlicense.html
    #>
    param (
        [switch]$Verbose,
        [switch]$Expiry
    )
    try {
        $license = Get-VBRInstalledLicense
        if ($Verbose) {
            return $license
        } else {
            $status = $license.Status
            if ($status -eq "Valid") {
                return $true
            } else {
                return $false
            }
        }
        if ($Expiry) {
            if ($license.ExpirationDate -ne $null) {
                $expirationDate = [datetime]$license.ExpirationDate
                $daysUntilExpiration = ($expirationDate - (Get-Date)).TotalDays
                return [math]::Round($daysUntilExpiration)
            } else {
                return $null
            }
        }
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication license status: $_"
        throw "Failed to get Veeam Backup & Replication license status: $_"
    }
}

function Get-VeeamServerInfo {
    <#
    .SYNOPSIS
        Returns name, build version and patch level of the Veeam Backup & Replication server.
    .NOTES
        Uses Get-VBRBackupServerInfo.
        Documentation: https://helpcenter.veeam.com/docs/vbr/powershell/get-vbrbackupserverinfo.html
    #>
    try {
        $serverInfo = Get-VBRBackupServerInfo
        return $serverInfo
    } catch {
        Write-Host "Error: Failed to get Veeam Backup & Replication server info: $_"
        throw "Failed to get Veeam Backup & Replication server info: $_"
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "Get-VeeamVersion",
    "Get-LatestVeeamVersion",
    "Import-VeeamPowershellModule",
    "Get-VeeamJobs",
    "Get-FailedJobs",
    "Get-SuccessfulJobs",
    "Get-OtherJobs",
    "Get-VeeamSessions",
    "Get-VeeamServices",
    "Get-VeeamRepositories",
    "Get-VeeamLicenseStatus",
    "Get-VeeamServerInfo"
)