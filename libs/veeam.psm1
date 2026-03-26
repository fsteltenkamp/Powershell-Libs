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
        Version : 1.6
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

function Import-VeeamPowershellModule {
    <#
    .SYNOPSIS
        Imports the Veeam Backup & Replication PowerShell module.
    #>
    # Depending on version of veeam BR, it is either a SnapIn or a regular module.
    $veeamVersion = Get-VeeamVersion
    if ($veeamVersion -like "10*" -or $veeamVersion -like "9*" -or $veeamVersion -like "8*") {
        # Veeam Backup & Replication v10 and lower use SnapIn
        if (-not (Get-PSSnapin -Name "VeeamPSSnapin" -ErrorAction SilentlyContinue)) {
            try {
                Add-PSSnapin "VeeamPSSnapin" -ErrorAction Stop
                Write-Host "Veeam Backup & Replication PowerShell SnapIn imported successfully."
                $snapInLoaded = $true
            } catch {
                Write-Host "Error: Failed to import Veeam Backup & Replication PowerShell SnapIn: $_"
                throw "Failed to import Veeam Backup & Replication PowerShell SnapIn: $_"
            }
        } else {
            Write-Host "Veeam Backup & Replication PowerShell SnapIn is already imported."
        }        
    } elseif ($veeamVersion -like "11*" -or $veeamVersion -like "12*" -or $veeamVersion -like "13*") {
        # Veeam Backup & Replication v11 and higher use regular module
        if (-not (Get-Module -Name "Veeam.Backup.PowerShell" -ErrorAction SilentlyContinue)) {
            try {
                Import-Module "Veeam.Backup.PowerShell" -ErrorAction Stop
                Write-Host "Veeam Backup & Replication PowerShell module imported successfully."
                $moduleLoaded = $true
            } catch {
                Write-Host "Error: Failed to import Veeam Backup & Replication PowerShell module: $_"
                throw "Failed to import Veeam Backup & Replication PowerShell module: $_"
            }
        } else {
            Write-Host "Veeam Backup & Replication PowerShell module is already imported."
        }
    }
    # Check if commands are available, meaning the import was successful:
    if ((Get-Command).Name -notcontains "Get-VBRJob") {
        Write-Host "Error: Veeam Backup & Replication PowerShell module is not available after import."
        throw "Veeam Backup & Replication PowerShell module is not available after import."
    } else {
        Write-Host "Import of PS Module Successful."
        return $true
    }
    return $false
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