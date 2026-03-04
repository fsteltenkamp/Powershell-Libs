<#
    .SYNOPSIS
        Test the Update function

    .DESCRIPTION
        This script tests the Update function of the updater.ps1 script.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 0.1
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

# Define libraries to import:
$libs = @("crypt", "file", "http", "logger", "util", "winsat")
# Download and import the Updater Script:
$updaterUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/updater.psm1"
$updaterPath = "$PSScriptRoot\updater.psm1"
Invoke-WebRequest -Uri $updaterUrl -OutFile $updaterPath -UseBasicParsing
Import-Module $updaterPath -Force
# Run the update function:
Update-Libs -Libs $libs

# Test if the libraries were imported successfully by calling a function from each library:

# crypt library test:
try {
    Get-StringHash -String "Test String"
    $validateHash = "bd08ba3c982eaad768602536fb8e1184"
    if ((Get-StringHash -String "Test String").Replace("-", "") -ne $validateHash) {
        throw "Hash does not match expected value."
    }
    Write-Host "Get-StringHash function from crypt library is working."
} catch {
    Write-Host "Error: Get-StringHash function from crypt library is not working."
}

# file library test:
try {
    $testFilePath = "$PSScriptRoot\testfolder"
    Confirm-Folder -Path $testFilePath
    if (-not (Test-Path -Path $testFilePath)) {
        throw "Failed to create test folder."
    }
    Write-Host "Folder creation test for file library is working."
} catch {
    Write-Host "Error: Folder creation test for file library is not working."
}

# http library test:
try {
    $headers = New-RequestHeaders -UseAuth $false
    if ($null -eq $headers.raw) {
        throw "Failed to create request headers."
    }
    Write-Host "New-RequestHeaders function from http library is working. Headers: $($headers.raw | Format-List)"
} catch {
    Write-Host "Error: New-RequestHeaders function from http library is not working."
}

# Logger library test:
try {
    setLogLevel -Level "debug"
    enableLogfile -FilePath "$PSScriptRoot\testlog.txt"
    log -Level "info" -Message "This is a test log message."
    if (-not (Test-Path -Path "$PSScriptRoot\testlog.txt")) {
        throw "Failed to create log file."
    }
    Write-Host "Logger library functions are working."
} catch {
    Write-Host "Error: Logger library functions are not working."
}

# util library test:
try {
    $publicIp = Get-PublicIp
    if ($null -eq $publicIp.ipv4) {
        throw "Failed to retrieve public IPv4 address."
    }
    Write-Host "Get-PublicIp function from util library is working. Public IPv4: $($publicIp.ipv4)"
} catch {
    Write-Host "Error: Get-PublicIp function from util library is not working."
}

# winsat library test:
try {
    Invoke-WinSATDiskTest -DriveLetter "C"
    $winsatResults = Get-WinSATResults
    if ($null -eq $winsatResults) {
        throw "Failed to retrieve WinSAT results."
    }
    Write-Host "Get-WinSATResults function from winsat library is working."
    # Display available metric names:
    Write-Host "Available metrics: $($winsatResults.ChildNodes.Name -join ', ')"
} catch {
    Write-Host "Error: Get-WinSATResults function from winsat library is not working."
}