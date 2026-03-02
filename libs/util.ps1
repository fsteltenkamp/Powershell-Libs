<#
    .SYNOPSIS
        Library for Utility functions

    .DESCRIPTION
        Provides functions for Utility operations.
    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function getPublicIp() {
    $ipv4ApiUrl = "https://api.ipify.org?format=json"
    $ipv6ApiUrl = "https://api6.ipify.org?format=json"
    #get IPv4
    $ownIpReq = Invoke-WebRequest -UseBasicParsing -Uri $ipv4ApiUrl | ConvertFrom-Json
    $ipv4 = $ownIpReq.ip
    #get IPv6, schlägt nach >2 sek. fehl.
    try {
        $ownIpReq = Invoke-WebRequest -TimeoutSec 2 -UseBasicParsing -Uri $ipv6ApiUrl | ConvertFrom-Json
        $ipv6 = $ownIpReq.ip
    } catch {
        $ipv6 = $null
    }
    return @{"ipv4" = $ipv4; "ipv6" = $ipv6}
}

function getHostname() {
    $hostname = $env:COMPUTERNAME
    return $hostname
}