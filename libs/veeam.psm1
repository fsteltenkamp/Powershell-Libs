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
        Version : 1.2
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function Get-VeeamBrVersion {
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

function Get-VeeamO365Version {
    <#
    .SYNOPSIS
        Checks the installation status of Veeam Backup for Microsoft 365.
    #>
    # Get veeam version by checking the uninstall registry
    $displayName = "^Veeam.*365"
    $registryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $registryKeyWow6432 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    # get values
    $veeamInstalled = Get-ChildItem -Path $registryKey, $registryKeyWow6432 -ErrorAction SilentlyContinue |
        Where-Object { $_.GetValue("DisplayName") -match $displayName } |
        Select-Object @{Name="DisplayName"; Expression={$_.GetValue("DisplayName")}},
            @{Name="DisplayVersion"; Expression={$_.GetValue("DisplayVersion")}},
            @{Name="Publisher"; Expression={$_.GetValue("Publisher")}},
            @{Name="InstallDate"; Expression={$_.GetValue("InstallDate")}} -First 1
    if ($veeamInstalled) {
        return $veeamInstalled.DisplayVersion
    } else {
        log "error" "Veeam Backup for Microsoft 365 is not installed."
        exit 1
    }
}

function Import-VeeamPowershellModule {
    <#
    .SYNOPSIS
        Imports the Veeam Backup & Replication PowerShell module.
    #>
    # Depending on version of veeam BR, it is either a SnapIn or a regular module.
    $veeamVersion = Get-VeeamBrVersion
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

function Get-VeeamBrJobs {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup & Replication backup jobs.
    #>
    try {
        $backupJobs = Get-VBRJob -Type Backup
        return $backupJobs
    } catch {
        log "error" "Failed to get Veeam Backup & Replication backup jobs: $_"
        exit 1
    }
}

function Get-VeeamO365Jobs {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup for Microsoft 365 backup jobs.
    #>
    try {
        $backupJobs = Get-VBOJob
        return $backupJobs
    } catch {
        log "error" "Failed to get Veeam Backup for Microsoft 365 backup jobs: $_"
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

function Get-FailedVbrJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have failed in Veeam Backup & Replication.
    #>
    try {
        $jobs = Get-VeeamBrJobs
        $failedJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Failed" }
        return $failedJobs
    } catch {
        log "error" "Failed to get failed Veeam Backup & Replication jobs: $_"
        exit 1
    }
}

function Get-FailedVboJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have failed in Veeam Backup for Microsoft 365.
    #>
    try {
        $jobs = Get-VeeamO365Jobs
        $failedJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Failed" }
        return $failedJobs
    } catch {
        log "error" "Failed to get failed Veeam Backup for Microsoft 365 jobs: $_"
        exit 1
    }
}

function Get-OldVbrJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have not been run in the last specified number of days in Veeam Backup & Replication.
    .PARAMETER Days
        The number of days to check for old jobs. Default is 7.
    #>
    param (
        [int]$Days = 7
    )
    try {
        $jobs = Get-VeeamBrJobs
        $oldJobs = $jobs | Where-Object { $_.GetLastRunTime() -lt (Get-Date).AddDays(-$Days) }
        return $oldJobs
    } catch {
        log "error" "Failed to get old Veeam Backup & Replication jobs: $_"
        exit 1
    }
}

function Get-OldVboJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have not been run in the last specified number of days in Veeam Backup for Microsoft 365.
    .PARAMETER Days
        The number of days to check for old jobs. Default is 7.
    #>
    param (
        [int]$Days = 7
    )
    try {
        $jobs = Get-VeeamO365Jobs
        $oldJobs = $jobs | Where-Object { $_.GetLastRunTime() -lt (Get-Date).AddDays(-$Days) }
        return $oldJobs
    } catch {
        log "error" "Failed to get old Veeam Backup for Microsoft 365 jobs: $_"
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

function Get-VeeamO365Repositories {
    <#
    .SYNOPSIS
        Gets a list of all Veeam Backup for Microsoft 365 repositories and their status.
    #>
    try {
        $repositories = Get-VBORepository
        return $repositories
    } catch {
        log "error" "Failed to get Veeam Backup for Microsoft 365 repositories: $_"
        exit 1
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "Get-VeeamBrVersion",
    "Get-VeeamO365Version",
    "Import-VeeamPowershellModule",
    "Get-VeeamBrJobs",
    "Get-VeeamO365Jobs",
    "Get-VeeamServices",
    "Get-FailedVbrJobs",
    "Get-FailedVboJobs",
    "Get-OldVbrJobs",
    "Get-OldVboJobs",
    "Get-VeeamBrRepositories",
    "Get-VeeamO365Repositories"
)