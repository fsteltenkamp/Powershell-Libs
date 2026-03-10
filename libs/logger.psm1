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
        Library for Logging

    .DESCRIPTION
        Provides functions for Logging

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.1
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

$script:logLevel = "info"
$script:logFileEnabled = $false
$script:logFilePath = "$env:TEMP\powershell-libs.log"
$script:logLevelValues = @{
    "debug" = 0
    "info" = 1
    "warning" = 2
    "error" = 3
    "success" = 4
}

function Set-LogLevel {
    <#
    .SYNOPSIS
        Sets the global log level for the module.
    .PARAMETER Level
        The log level to set (e.g., "info", "debug", "error").
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Level
    )
    if ($script:logLevelValues.ContainsKey($Level)) {
        $script:logLevel = $Level
        Write-Host "Log level set to '$Level'."
    } else {
        Write-Host "Invalid log level '$Level'. Valid levels are: $($script:logLevelValues.Keys -join ", ")."
    }
}

function Check-CreateLogfile {
    <#
    .SYNOPSIS
        Checks if the log file exists and creates it if it doesn't.
    #>
    if ($script:logFileEnabled) {
        $logDir = Split-Path -Path $script:logFilePath -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -Path $script:logFilePath)) {
            New-Item -Path $script:logFilePath -ItemType File -Force | Out-Null
        }
    }
}

function Enable-Logfile {
    <#
    .SYNOPSIS
        Enables logging to a file.
    .PARAMETER FilePath
        The path to the log file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    $script:logFileEnabled = $true
    $script:logFilePath = $FilePath
    Write-Host "Logging to file enabled at '$FilePath'."
    Check-CreateLogfile
}

function log {
    <#
    .SYNOPSIS
        Logs a message with a given level.
    .PARAMETER Level
        The log level (e.g., "info", "debug", "error").
    .PARAMETER Message
        The message to log.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Level,
        [Parameter(Mandatory, Position = 1)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($script:logLevelValues[$Level] -ge $script:logLevelValues[$script:logLevel]) {
        Write-Host "[$timestamp] [$Level] $Message"
        if ($script:logFileEnabled) {
            Check-CreateLogfile
            # append log entry to file
            $logEntry = "[$timestamp] [$Level] $Message`n"
            Add-Content -Path $script:logFilePath -Value $logEntry
        }
    }
}

Export-ModuleMember -Function Set-LogLevel, Enable-Logfile, log