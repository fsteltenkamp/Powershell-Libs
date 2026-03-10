<#
    .SYNOPSIS
        Library for checking Veeam Backup & Replication services and components.

    .DESCRIPTION
        Provides functions to check the status of Veeam Backup & Replication services and components.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function getVeeamBrVersion {
    <#
    .SYNOPSIS
        Checks the installation status of Veeam Backup & Replication.
    #>
    # Get veeam version by checking the uninstall registry
    $displayName = "^Veeam Backup & Replication"
    $registryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $registryKeyWow6432 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    # get values
    $veeamInstalled = Get-ChildItem -Path $registryKey, $registryKeyWow6432 -ErrorAction SilentlyContinue |
        Where-Object { $_.GetValue("DisplayName") -like "$displayName*" } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate -First 1
    if ($veeamInstalled) {
        return $veeamInstalled.DisplayVersion
    } else {
        log "error" "Veeam Backup & Replication is not installed."
        exit 1
    }
}

function getVeeamO365Version {
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
        Where-Object { $_.GetValue("DisplayName") -like "$displayName*" } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate -First 1
    if ($veeamInstalled) {
        return $veeamInstalled.DisplayVersion
    } else {
        log "error" "Veeam Backup for Microsoft 365 is not installed."
        exit 1
    }
}

function importVeeamPowershellModule {
    <#
    .SYNOPSIS
        Imports the Veeam Backup & Replication PowerShell module.
    #>
    # Depending on version of veeam BR, it is either a SnapIn or a regular module.
    $veeamVersion = getVeeamBrVersion
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

function getVbrJobs {
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

function getVboJobs {
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

function getVeeamServices {
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

function getFailedVbrJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have failed in Veeam Backup & Replication.
    #>
    $jobs = getVbrJobs
    $failedJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Failed" }
    return $failedJobs
}

function getFailedVboJobs {
    <#
    .SYNOPSIS
        Retrieves a list of all jobs that have failed in Veeam Backup for Microsoft 365.
    #>
    $jobs = getVboJobs
    $failedJobs = $jobs | Where-Object { $_.GetLastResult() -eq "Failed" }
    return $failedJobs
}