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
        Library for JSON functions

    .DESCRIPTION
        Provides functions for JSON operations.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.1
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function convertToJson {
    <#
    .SYNOPSIS
        Converts an object to a JSON string.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [object]$anything
    )
    try {
        $OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8;
        $output = ConvertTo-Json -InputObject $anything -Depth 100 -Compress
        return $output
    } catch {
        log "error" "Error converting to JSON: $anything"
        exit 16
    }
}

function convertFromJson {
    <#
    .SYNOPSIS
        Converts a JSON string to an object.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$jsonString
    )
    try {
        $output = ConvertFrom-Json -InputObject $jsonString
        return $output
    } catch {
        log "error" "Error converting JSON: $jsonString"
        exit 16
    }
}

function pjson {
    <#
    .SYNOPSIS
        Pretty-prints a JSON string.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$json
    )
    try {
        ($json | convertfrom-json | convertto-json -depth 100)
        return $json
    } catch {
        log "error" "Error pretty-printing JSON: $json"
        exit 16
    }

}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "convertToJson",
    "convertFromJson",
    "pjson"
)