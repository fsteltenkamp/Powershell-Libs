<#
    .SYNOPSIS
        Library for Logging

    .DESCRIPTION
        Provides functions for Logging

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
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

function setLogLevel {
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

function checkCreateLogfile {
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

function enableLogfile {
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
    checkCreateLogfile
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
        [Parameter(Mandatory)]
        [string]$Level,
        [Parameter(Mandatory, Position = 1)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($script:logLevelValues[$Level] -ge $script:logLevelValues[$script:logLevel]) {
        Write-Host "[$timestamp] [$Level] $Message"
        if ($script:logFileEnabled) {
            checkCreateLogfile
            # append log entry to file
            $logEntry = "[$timestamp] [$Level] $Message`n"
            Add-Content -Path $script:logFilePath -Value $logEntry
        }
    }
}

Export-ModuleMember -Function setLogLevel, enableLogfile, log