<#
    Copyright (C) 2026  Florian Steltenkamp

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
    
    .SYNOPSIS
        Library for Utility functions

    .DESCRIPTION
        Provides functions for Utility operations.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.1
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

function Get-UnixTimestamp {
    <#
    .SYNOPSIS
        Returns the current Unix timestamp.
    #>
    $ts = [int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds
    return $ts
}

Export-ModuleMember -Function Get-PublicIp, Get-Hostname, Get-UnixTimestamp
