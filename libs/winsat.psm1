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

function ConvertFrom-XmlNode {
    <#
    .SYNOPSIS
        Recursively converts an XML element into an ordered hashtable.
    .DESCRIPTION
        Leaf nodes become: @{ value = "innerText"; tags = @{ attr1 = "v1"; ... } }
        Container nodes become: @{ child1 = ...; child2 = ... }
        Duplicate sibling names (e.g. multiple AvgThroughput) are collected into arrays.
    #>
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$Node
    )
    $result = [ordered]@{}

    foreach ($child in $Node.ChildNodes) {
        if ($child.NodeType -ne 'Element') { continue }

        # Collect attributes as tags
        $tags = [ordered]@{}
        foreach ($attr in $child.Attributes) {
            $tags[$attr.Name] = $attr.Value
        }

        # Check whether this element has child elements or is a leaf
        $childElements = @($child.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })

        if ($childElements.Count -gt 0) {
            # Container node — recurse
            $entry = ConvertFrom-XmlNode -Node $child
        } else {
            # Leaf node
            $entry = [ordered]@{ "value" = $child.InnerText }
        }

        # Attach tags if any attributes exist
        if ($tags.Count -gt 0) {
            $entry["tags"] = $tags
        }

        # Handle duplicate sibling names by collecting into an array
        if ($result.Contains($child.Name)) {
            if ($result[$child.Name] -is [System.Collections.ArrayList]) {
                $result[$child.Name].Add($entry) | Out-Null
            } else {
                $existing = $result[$child.Name]
                $result[$child.Name] = [System.Collections.ArrayList]@($existing, $entry)
            }
        } else {
            $result[$child.Name] = $entry
        }
    }

    return $result
}

function Get-WinSATResults {
    <#
    .SYNOPSIS
        Retrieves structured WinSAT results from the XML output.
    .DESCRIPTION
        Parses the WinSAT XML and returns an ordered hashtable with four sections:
        - ProgramInfo     : WinSAT program metadata (Name, Version, CmdLine, etc.)
        - SystemEnvironment: System state at test time (ExecDateTOD, IsOfficial, etc.)
        - WinSPR          : Windows System Performance Rating scores
        - Metrics         : Actual benchmark results (CpuMetrics, DiskMetrics, etc.)

        Each leaf value is returned as @{ value = "..."; tags = @{ attr = "..." } }.
        Duplicate XML siblings (e.g. multiple AvgThroughput entries) are grouped into arrays.
    .PARAMETER Section
        Optional. Return only a specific section or subsection using a path (e.g., "Metrics/DiskMetrics").
        If omitted, all sections are returned.
    .PARAMETER Format
        Output format: "object" (default) returns a PowerShell ordered hashtable,
        "json" returns a JSON string.
    #>
    param(
        [string]$Section = $null,
        [ValidateSet("object", "json")]
        [string]$Format = "object"
    )
    if (-not (Test-Path -Path $script:xmlFilePath)) {
        Write-Host "WinSAT XML file not found at '$script:xmlFilePath'."
        return $null
    }
    try {
        [xml]$xmlContent = Get-Content -Path $script:xmlFilePath
        $winsat = $xmlContent.WinSAT
        if ($null -eq $winsat) {
            Write-Host "No WinSAT root node found in XML."
            return $null
        }

        $results = [ordered]@{}

        # Parse each section if it exists
        $sections = @("ProgramInfo", "SystemEnvironment", "WinSPR", "Metrics")
        foreach ($s in $sections) {
            if ($winsat.$s) {
                $results[$s] = ConvertFrom-XmlNode -Node $winsat.$s
            }
        }

        # Filter to a specific path if requested
        if ($Section) {
            $pathParts = $Section -split '/'
            $current = $results
            foreach ($part in $pathParts) {
                if ($current.Contains($part)) {
                    $current = $current[$part]
                } else {
                    Write-Host "Section '$Section' not found in WinSAT results."
                    return $null
                }
            }
            $output = $current
        } else {
            $output = $results
        }

        # Return in the requested format
        if ($Format -eq "json") {
            return ($output | ConvertTo-Json -Depth 10 -Compress)
        }
        return $output
    } catch {
        Write-Host "Error parsing WinSAT XML: $_"
        return $null
    }
}

Export-ModuleMember -Function Set-XmlFileLocation, Invoke-WinSAT, Invoke-FullWinSAT, Invoke-WinSATDiskTest, Invoke-WinSATCpuTest, Invoke-WinSATMemoryTest, Invoke-WinSATGraphicsTest, Get-WinSATResults
