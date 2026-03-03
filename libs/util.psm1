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

function Get-PublicIp {
    <#
    .SYNOPSIS
        Returns the machine's public IPv4 and IPv6 addresses.
    #>
    $ipv4ApiUrl = "https://api.ipify.org?format=json"
    $ipv6ApiUrl = "https://api6.ipify.org?format=json"

    $ownIpReq = Invoke-WebRequest -UseBasicParsing -Uri $ipv4ApiUrl | ConvertFrom-Json
    $ipv4 = $ownIpReq.ip

    # IPv6 lookup — fails gracefully after 2 seconds
    try {
        $ownIpReq = Invoke-WebRequest -TimeoutSec 2 -UseBasicParsing -Uri $ipv6ApiUrl | ConvertFrom-Json
        $ipv6 = $ownIpReq.ip
    } catch {
        $ipv6 = $null
    }

    return @{ "ipv4" = $ipv4; "ipv6" = $ipv6 }
}

function Get-Hostname {
    <#
    .SYNOPSIS
        Returns the machine's hostname.
    #>
    return $env:COMPUTERNAME
}

Export-ModuleMember -Function Get-PublicIp, Get-Hostname
