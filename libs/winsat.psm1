<#
    .SYNOPSIS
        Library for WinSAT Testing

    .DESCRIPTION
        Provides functions for running the Windows System Assessment Tool (WinSAT) and retrieving its results.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

$global:xmlFilePath = "$env:TEMP\winsat.xml"
$global:saveAsXml = $true
$global:jsonFilePath = "$env:TEMP\winsat.json"
$global:saveAsJson = $false

function Set-XmlFileLocation {
    <#
    .SYNOPSIS
        Sets the location of the WinSAT XML results file.
    .PARAMETER Path
        The path to the WinSAT XML results file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    $global:xmlFilePath = $Path
    log "info" "WinSAT XML file location set to '$Path'."
}

function Enable-XmlOutput {
    <#
    .SYNOPSIS
        Enables saving WinSAT results as XML.
    #>
    $global:saveAsXml = $true
    log "info" "WinSAT XML output enabled."
}

function Disable-XmlOutput {
    <#
    .SYNOPSIS
        Disables saving WinSAT results as XML.
    #>
    $global:saveAsXml = $false
    log "info" "WinSAT XML output disabled."
}

function Set-JsonFileLocation {
    <#
    .SYNOPSIS
        Sets the location of the WinSAT JSON results file.
    .PARAMETER Path
        The path to the WinSAT JSON results file.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    $global:jsonFilePath = $Path
    log "info" "WinSAT JSON file location set to '$Path'."
}

function Enable-JsonOutput {
    <#
    .SYNOPSIS
        Enables saving WinSAT results as JSON.
    #>
    $global:saveAsJson = $true
    # due to winsat not supporting JSON output natively, we will convert the XML output to JSON after the assessment is completed
    $global:saveAsXml = $true # ensure XML output is enabled to have the source data for JSON conversion
    log "info" "WinSAT JSON output enabled."
}

function Disable-JsonOutput {
    <#
    .SYNOPSIS
        Disables saving WinSAT results as JSON.
    #>
    $global:saveAsJson = $false
    log "info" "WinSAT JSON output disabled."
}

function Convert-ToJson {
    <#
    .SYNOPSIS
        Converts the WinSAT XML results to JSON format.
    #>
    if (Test-Path -Path $global:xmlFilePath) {
        try {
            $xmlContent = Get-Content -Path $global:xmlFilePath
            $jsonContent = $xmlContent | ConvertTo-Json
            Set-Content -Path $global:jsonFilePath -Value $jsonContent
            log "info" "WinSAT results converted to JSON and saved to '$global:jsonFilePath'."
        } catch {
            log "error" "An error occurred while converting WinSAT XML to JSON: $_"
        }
    } else {
        log "error" "WinSAT XML file not found at '$global:xmlFilePath'. Cannot convert to JSON."
    }
}

function Invoke-WinSAT {
    <#
    .SYNOPSIS
        Runs the WinSAT assessment with specified arguments.
    .PARAMETER Arguments
        The arguments to pass to the WinSAT command.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Arguments
    )
    try {
        $winSatPath = "$env:windir\system32\winsat.exe"
        if (Test-Path -Path $winSatPath) {
            log "info" "Running WinSAT with arguments: $Arguments"
            Start-Process -FilePath $winSatPath -ArgumentList $Arguments -Wait -NoNewWindow
            log "info" "WinSAT assessment completed."
        } else {
            log "error" "WinSAT executable not found at '$winSatPath'."
        }
    } catch {
        log "error" "An error occurred while running WinSAT: $_"
    }
}

function Invoke-FullWinSAT {
    <#
    .SYNOPSIS
        Runs the full WinSAT assessment.
    #>
    $winSatArgs = "formal -restart clean -v"
    if ($global:saveAsXml) {
        $winSatArgs += " -xml $global:xmlFilePath"
    }
    Invoke-WinSAT -Arguments $winSatArgs
}

function Invoke-WinSATDiskTest {
    <#
    .SYNOPSIS
        Runs the WinSAT disk performance test.
    .DESCRIPTION
        This function runs the WinSAT disk performance test, which assesses the read and write performance of the system's storage devices.
        If a drive letter is provided, it will test that specific drive. Otherwise, it will test all drives.
    .PARAMETER DriveLetter
        The drive letter to test (e.g., "C:"). If not provided, all drives will be tested.
    .PARAMETER ReadOnly
        If specified, only the read performance will be tested.
    .PARAMETER WriteOnly
        If specified, only the write performance will be tested.
    .PARAMETER Sequential
        If specified, the test will focus on sequential read/write performance. Otherwise, it will include both sequential and random tests.
    .PARAMETER Random
        If specified, the test will focus on random read/write performance. Otherwise, it will include both sequential and random tests.
     #>
    #>
    param(
        [string]$DriveLetter = $null
        [switch]$ReadOnly,
        [switch]$WriteOnly,
        [switch]$Sequential,
        [switch]$Random
    )
    $winSatArgs = "disk "
    # Determine the type of disk test based on the parameters:
    if ($ReadOnly.IsPresent -and -not $WriteOnly.IsPresent) {
        $winSatArgs += "-read "
    } elseif ($WriteOnly.IsPresent -and -not $ReadOnly.IsPresent) {
        $winSatArgs += "-write "
    } else {
        $winSatArgs += "-read -write "
    }
    # Determine the type of disk test based on the parameters:
    if ($Sequential.IsPresent -and -not $Random.IsPresent) {
        $winSatArgs += "-seq "
    } elseif ($Random.IsPresent -and -not $Sequential.IsPresent) {
        $winSatArgs += "-rand "
    } else {
        $winSatArgs += "-seq -rand "
    }
    # If a drive letter is provided, add it to the arguments:
    if ($null -ne $DriveLetter) {
        $winSatArgs += " -drive $DriveLetter"
    }
    Invoke-WinSAT -Arguments $winSatArgs
}

function Get-WinSATResults {
    <# 
    .SYNOPSIS
        Retrieves the WinSAT results in the specified format (XML or JSON).
    .PARAMETER Format
        The format to retrieve the results in ("xml" or "json").
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("xml", "json")]
        [string]$Format
    )
    if ($Format -eq "xml") {
        # return content of the xml file if it exists, otherwise log an error and return null
        if (Test-Path -Path $global:xmlFilePath) {
            # return content of the xml file
            return Get-Content -Path $global:xmlFilePath
        } else {
            log "error" "WinSAT XML file not found at '$global:xmlFilePath'."
            return $null
        }
    } elseif ($Format -eq "json") {
        # convert xml to json, save it in the file, remove the xml file.
        Convert-ToJson
        if (Test-Path -Path $global:jsonFilePath) {
            # remove xml file:
            Remove-Item -Path $global:xmlFilePath -ErrorAction SilentlyContinue
            # return content of the json file
            return Get-Content -Path $global:jsonFilePath
        } else {
            log "error" "WinSAT JSON file not found at '$global:jsonFilePath'."
            return $null
        }
    }
}

Export-ModuleMember -Function Set-XmlFileLocation, Enable-XmlOutput, Disable-XmlOutput, Set-JsonFileLocation, Enable-JsonOutput, Disable-JsonOutput, Convert-ToJson, Invoke-WinSAT, Invoke-WinSATDiskTest, Invoke-FullWinSAT, Get-WinSATResults
