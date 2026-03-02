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
$libs = @("file", "crypt")
# Download and import the Updater Script:
$updaterUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/updater.ps1"
$updaterPath = "$PSScriptRoot\updater.ps1"
Invoke-WebRequest -Uri $updaterUrl -OutFile $updaterPath -UseBasicParsing
. $updaterPath
# Run the update function:
Update-Libs -Libs $libs