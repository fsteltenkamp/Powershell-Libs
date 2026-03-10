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

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.3
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Documentation:
        - https://helpcenter.veeam.com/docs/vbr/powershell/
        Exitcodes:
        - 1: General error
#>

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
        log "error" "Veeam Backup & Replication is not installed."
        exit 1
    }
}

function Import-VeeamPowershellModule {
    <#
    .SYNOPSIS
        Imports the Veeam Backup & Replication PowerShell module.
    #>
    # Depending on version of veeam BR, it is either a SnapIn or a regular module.
    $veeamVersion = Get-VeeamVersion
    if ($veeamVersion -like "10*") {
        # Veeam Backup & Replication v10 and lower use SnapIn
        if (-not (Get-PSSnapin -Name "VeeamPSSnapin" -ErrorAction SilentlyContinue)) {
            try {
                Add-PSSnapin "VeeamPSSnapin" -ErrorAction Stop
                log "info" "Veeam Backup & Replication PowerShell SnapIn imported successfully."
            } catch {
                log "error" "Failed to import Veeam Backup & Replication PowerShell SnapIn: $_"
                exit 1
            }
        } else {
            log "info" "Veeam Backup & Replication PowerShell SnapIn is already imported."
        }
    } else {
        # Veeam Backup & Replication v11 and higher use regular module
        if (-not (Get-Module -Name "Veeam.Backup.PowerShell" -ErrorAction SilentlyContinue)) {
            try {
                Import-Module "Veeam.Backup.PowerShell" -ErrorAction Stop
                log "info" "Veeam Backup & Replication PowerShell module imported successfully."
            } catch {
                log "error" "Failed to import Veeam Backup & Replication PowerShell module: $_"
                exit 1
            }
        } else {
            log "info" "Veeam Backup & Replication PowerShell module is already imported."
        }
    }
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
        log "error" "Failed to get Veeam Backup & Replication backup jobs: $_"
        exit 1
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
        log "error" "Failed to get Veeam Backup & Replication sessions: $_"
        exit 1
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
        log "error" "Failed to get Veeam Backup & Replication services: $_"
        exit 1
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
        log "error" "Failed to get failed Veeam Backup & Replication jobs: $_"
        exit 1
    }
}

function Get-VeeamBrRepositories {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication repositories and their status.
    #>
    try {
        $repositories = Get-VBRBackupRepository
        return $repositories
    } catch {
        log "error" "Failed to get Veeam Backup & Replication repositories: $_"
        exit 1
    }
}

function Get-VeeamLicenseStatus {
    <#
    .SYNOPSIS
        Returns details about the license installed on the Veeam Backup & Replication server.
    .NOTES
        Uses Get-VBRInstalledLicense.
        Documentation: https://helpcenter.veeam.com/docs/vbr/powershell/get-vbrinstalledlicense.html
    #>
    try {
        $license = Get-VBRInstalledLicense
        return $license
    } catch {
        log "error" "Failed to get Veeam Backup & Replication license status: $_"
        exit 1
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
        log "error" "Failed to get Veeam Backup & Replication server info: $_"
        exit 1
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "Get-VeeamVersion",
    "Import-VeeamPowershellModule",
    "Get-VeeamJobs",
    "Get-VeeamSessions",
    "Get-VeeamServices",
    "Get-FailedJobs",
    "Get-VeeamBrRepositories",
    "Get-VeeamLicenseStatus",
    "Get-VeeamServerInfo"
)