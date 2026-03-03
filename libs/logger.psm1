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

$global:logLevel = "info"
$global:logFileEnabled = $false
$global:logFilePath = "$env:TEMP\powershell-libs.log"
$global:logLevelValues = @{
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
    if ($logLevelValues.ContainsKey($Level)) {
        $global:logLevel = $Level
        Write-Host "Log level set to '$Level'."
    } else {
        Write-Host "Invalid log level '$Level'. Valid levels are: $($logLevelValues.Keys -join ", ")."
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
    $global:logFileEnabled = $true
    $global:logFilePath = $FilePath
    Write-Host "Logging to file enabled at '$FilePath'."
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
    if ($logLevelValues[$Level] -ge $logLevelValues[$global:logLevel]) {
        Write-Host "[$timestamp] [$Level] $Message"
        if ($global:logFileEnabled) {
            # create logfile path if it doesn't exist
            $logDir = Split-Path -Path $global:logFilePath -Parent
            if (-not (Test-Path -Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            # create logfile if it doesn't exist
            if (-not (Test-Path -Path $global:logFilePath)) {
                New-Item -Path $global:logFilePath -ItemType File -Force | Out-Null
            }
            # append log entry to file
            $logEntry = "[$timestamp] [$Level] $Message`n"
            Add-Content -Path $global:logFilePath -Value $logEntry
        }
    }
}

Export-ModuleMember -Function setLogLevel, enableLogfile, log