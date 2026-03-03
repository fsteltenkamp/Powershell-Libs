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
    Write-Host "WinSAT XML file location set to '$Path'."
}

function Enable-XmlOutput {
    <#
    .SYNOPSIS
        Enables saving WinSAT results as XML.
    #>
    $global:saveAsXml = $true
    Write-Host "WinSAT XML output enabled."
}

function Disable-XmlOutput {
    <#
    .SYNOPSIS
        Disables saving WinSAT results as XML.
    #>
    $global:saveAsXml = $false
    Write-Host "WinSAT XML output disabled."
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
    Write-Host "WinSAT JSON file location set to '$Path'."
}

function Enable-JsonOutput {
    <#
    .SYNOPSIS
        Enables saving WinSAT results as JSON.
    #>
    $global:saveAsJson = $true
    # due to winsat not supporting JSON output natively, we will convert the XML output to JSON after the assessment is completed
    $global:saveAsXml = $true # ensure XML output is enabled to have the source data for JSON conversion
    Write-Host "WinSAT JSON output enabled."
}

function Disable-JsonOutput {
    <#
    .SYNOPSIS
        Disables saving WinSAT results as JSON.
    #>
    $global:saveAsJson = $false
    Write-Host "WinSAT JSON output disabled."
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
            Write-Host "WinSAT results converted to JSON and saved to '$global:jsonFilePath'."
        } catch {
            Write-Host "An error occurred while converting WinSAT XML to JSON: $_"
        }
    } else {
        Write-Host "WinSAT XML file not found at '$global:xmlFilePath'. Cannot convert to JSON."
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
            Write-Host "Running WinSAT with arguments: $Arguments"
            Start-Process -FilePath $winSatPath -ArgumentList $Arguments -Wait -NoNewWindow
            Write-Host "WinSAT assessment completed."
        } else {
            Write-Host "WinSAT executable not found at '$winSatPath'."
        }
    } catch {
        Write-Host "An error occurred while running WinSAT: $_"
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
    param(
        [string]$DriveLetter = $null,
        [switch]$ReadOnly,
        [switch]$WriteOnly,
        [switch]$Sequential,
        [switch]$Random
    )
    $winSatArgs = "disk "
    # Determine the type of disk test based on the parameters:
    if ($ReadOnly.IsPresent -and -not $WriteOnly.IsPresent) {$winSatArgs += "-read "}
    elseif ($WriteOnly.IsPresent -and -not $ReadOnly.IsPresent) {$winSatArgs += "-write "}
    else {$winSatArgs += "-read -write "}
    # Determine the type of disk test based on the parameters:
    if ($Sequential.IsPresent -and -not $Random.IsPresent) {$winSatArgs += "-seq "}
    elseif ($Random.IsPresent -and -not $Sequential.IsPresent) {$winSatArgs += "-rand "}
    else {$winSatArgs += "-seq -rand "}
    # If a drive letter is provided, add it to the arguments:
    if ($null -ne $DriveLetter) {$winSatArgs += "-drive $DriveLetter"}
    Invoke-WinSAT -Arguments $winSatArgs
}

function Invoke-WinSATCpuTest {
    <#
    .SYNOPSIS
        Runs the WinSAT CPU performance test.
    .PARAMETER Encryption
        If specified, includes an AES encryption benchmark.
    .PARAMETER Compression
        If specified, includes a compression benchmark.
    #>
    param(
        [switch]$Encryption,
        [switch]$Compression
    )
    $winSatArgs = "cpu"
    if ($Encryption.IsPresent)  { $winSatArgs += " -encryption" }
    if ($Compression.IsPresent) { $winSatArgs += " -compression" }
    if ($global:saveAsXml)      { $winSatArgs += " -xml $global:xmlFilePath" }
    Invoke-WinSAT -Arguments $winSatArgs
}

function Invoke-WinSATMemoryTest {
    <#
    .SYNOPSIS
        Runs the WinSAT memory (RAM) bandwidth test.
    #>
    $winSatArgs = "mem"
    if ($global:saveAsXml) { $winSatArgs += " -xml $global:xmlFilePath" }
    Invoke-WinSAT -Arguments $winSatArgs
}

function Invoke-WinSATGraphicsTest {
    <#
    .SYNOPSIS
        Runs WinSAT graphics tests.
    .DESCRIPTION
        Runs the Direct3D benchmark and/or the Desktop Window Manager (DWM) benchmark.
        By default both are run. Use -D3DOnly or -DwmOnly to run just one.
    .PARAMETER D3DOnly
        If specified, only the Direct3D benchmark is run.
    .PARAMETER DwmOnly
        If specified, only the Desktop Window Manager benchmark is run.
    .PARAMETER DirectX10
        If specified, the Direct3D test targets DirectX 10 instead of DirectX 9.
    #>
    param(
        [switch]$D3DOnly,
        [switch]$DwmOnly,
        [switch]$DirectX10
    )
    $dxFlag = if ($DirectX10.IsPresent) { "-dx10" } else { "-dx9" }
    $xmlArg = if ($global:saveAsXml) { " -xml $global:xmlFilePath" } else { "" }

    if ($D3DOnly.IsPresent) {
        Invoke-WinSAT -Arguments "d3d $dxFlag$xmlArg"
    } elseif ($DwmOnly.IsPresent) {
        Invoke-WinSAT -Arguments "dwm$xmlArg"
    } else {
        Invoke-WinSAT -Arguments "d3d $dxFlag$xmlArg"
        Invoke-WinSAT -Arguments "dwm$xmlArg"
    }
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
            Write-Host "WinSAT XML file not found at '$global:xmlFilePath'."
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
            Write-Host "WinSAT JSON file not found at '$global:jsonFilePath'."
            return $null
        }
    }
}

Export-ModuleMember -Function Set-XmlFileLocation, Enable-XmlOutput, Disable-XmlOutput, Set-JsonFileLocation, Enable-JsonOutput, Disable-JsonOutput, Convert-ToJson, Invoke-WinSAT, Invoke-FullWinSAT, Invoke-WinSATDiskTest, Invoke-WinSATCpuTest, Invoke-WinSATMemoryTest, Invoke-WinSATGraphicsTest, Get-WinSATResults
