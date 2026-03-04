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

$script:xmlFilePath = "$env:TEMP\winsat.xml"

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
    $script:xmlFilePath = $Path
    Write-Host "WinSAT XML file location set to '$Path'."
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
    $winSatArgs = "formal -restart clean -v -xml $script:xmlFilePath"
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
    # Determine the type of disk test based on the parameters:
    if ($Sequential.IsPresent -and -not $Random.IsPresent) {$winSatArgs += "-seq "}
    elseif ($Random.IsPresent -and -not $Sequential.IsPresent) {$winSatArgs += "-rand "}
    # If a drive letter is provided, add it to the arguments:
    if ($null -ne $DriveLetter) {$winSatArgs += "-drive $DriveLetter "}
    $winSatArgs += "-xml $script:xmlFilePath"
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
    $winSatArgs += " -xml $script:xmlFilePath"
    Invoke-WinSAT -Arguments $winSatArgs
}

function Invoke-WinSATMemoryTest {
    <#
    .SYNOPSIS
        Runs the WinSAT memory (RAM) bandwidth test.
    #>
    $winSatArgs = "mem -xml $script:xmlFilePath"
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
    $xmlArg = " -xml $script:xmlFilePath"

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
        Retrieves the WinSAT metrics from the XML results file.
    .DESCRIPTION
        Parses the WinSAT XML output and returns the child elements of the
        WinSAT/Metrics node (e.g. CPUMetrics, GraphicsMetrics, DiskMetrics)
        as a PowerShell XML object.
    .PARAMETER MetricName
        Optional. Return only a specific metric node (e.g. "DiskMetrics", "CPUMetrics").
        If omitted, all metrics are returned.
    #>
    param(
        [string]$MetricName = $null
    )
    if (-not (Test-Path -Path $script:xmlFilePath)) {
        Write-Host "WinSAT XML file not found at '$script:xmlFilePath'."
        return $null
    }
    try {
        [xml]$xmlContent = Get-Content -Path $script:xmlFilePath
        $metrics = $xmlContent.WinSAT.Metrics
        if ($null -eq $metrics) {
            Write-Host "No Metrics node found in WinSAT XML."
            return $null
        }
        if ($MetricName) {
            return $metrics.$MetricName
        }
        return $metrics
    } catch {
        Write-Host "Error parsing WinSAT XML: $_"
        return $null
    }
}

Export-ModuleMember -Function Set-XmlFileLocation, Invoke-WinSAT, Invoke-FullWinSAT, Invoke-WinSATDiskTest, Invoke-WinSATCpuTest, Invoke-WinSATMemoryTest, Invoke-WinSATGraphicsTest, Get-WinSATResults
