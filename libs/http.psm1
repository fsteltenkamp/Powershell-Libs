<#
    .SYNOPSIS
        Library for HTTP-Operations

    .DESCRIPTION
        Provides functions for HTTP operations like sending requests, handling responses, etc.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function Save-RemoteFile {
    <#
    .SYNOPSIS
        Downloads a file from a URL and saves it to a local path.
    .PARAMETER DownloadUrl
        The URL to download the file from.
    .PARAMETER SavePath
        The local path to save the file to.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DownloadUrl,
        [Parameter(Mandatory)]
        [string]$SavePath
    )
    log "debug" "Downloading file from $DownloadUrl to $SavePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($DownloadUrl, $SavePath)
        Write-Host "File downloaded successfully."
    } catch {
        Write-Host "Error occurred while downloading the file: $_"
    } finally {
        $webClient.Dispose()
    }
}

function New-RequestHeaders {
    <#
    .SYNOPSIS
        Builds a headers hashtable, merging defaults with any provided headers.
    .PARAMETER Headers
        Additional headers to merge in.
    .PARAMETER UseAuth
        Whether to include a Bearer token Authorization header.
    #>
    param(
        [hashtable]$Headers = $null,
        [bool]$UseAuth = $false
    )
    $defaultHeaders = @{ "Accept" = "application/json" }
    $authHeader = @{ "Authorization" = "Bearer $apiToken" }
    if ($UseAuth) {
        $defaultHeaders = $defaultHeaders + $authHeader
    }
    if ($null -ne $Headers) {
        $Headers = $defaultHeaders + $Headers
    } else {
        $Headers = $defaultHeaders
    }
    $jsonHeaders = (ConvertTo-Json $Headers)
    return @{ "raw" = $Headers; "json" = $jsonHeaders }
}

function New-RequestParams {
    <#
    .SYNOPSIS
        Builds a query-parameter hashtable, merging defaults with any provided params.
    .PARAMETER Params
        Additional parameters to merge in.
    #>
    param(
        [hashtable]$Params = $null
    )
    $defaultParams = @{ "ScriptVersion" = $Version }
    if ($null -ne $Params) {
        $Params = $defaultParams + $Params
    } else {
        $Params = $defaultParams
    }
    $jsonParams = (ConvertTo-Json $Params)
    return @{ "raw" = $Params; "json" = $jsonParams }
}

function Resolve-UrlPlaceholders {
    <#
    .SYNOPSIS
        Replaces known placeholders in a URL string.
    .PARAMETER Url
        The URL containing placeholders to resolve.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )
    $Url = $Url.Replace('{dId}', $dId)
    log "debug" "URL after replacing placeholders: $Url"
    return $Url
}

function ConvertFrom-RawContent {
    <#
    .SYNOPSIS
        Parses raw key:value line content into an array of hashtables.
    .PARAMETER RawContent
        The raw string content to parse.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RawContent
    )
    $parsedContent = @()
    $lines = $RawContent -split '\r?\n'
    foreach ($line in $lines) {
        $kvp = $line -split ':'
        $parsedContent += @{ $kvp[0] = $kvp[1] }
    }
    return $parsedContent
}

Export-ModuleMember -Function Save-RemoteFile, New-RequestHeaders, New-RequestParams, Resolve-UrlPlaceholders, ConvertFrom-RawContent
