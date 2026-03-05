<#
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