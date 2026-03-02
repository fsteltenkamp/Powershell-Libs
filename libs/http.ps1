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

function downloadFile($downloadUrl, $savePath) {
    log "debug" "downloading file from $url to $outFile"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($downloadUrl, $savePath)
        Write-Host "File downloaded successfully."
    } catch {
        Write-Host "Error occurred while downloading the file: $_"
    } finally {
        $webClient.Dispose()
    }
}

function handleHeaders($headers, $useAuth) {
    $defaultHeaders = @{"Accept" = "application/json"}
    # add auth header
    $authHeader = @{"Authorization" = "Bearer $apiToken"}
    if ($useAuth) {
        $defaultHeaders = $defaultHeaders + $authHeader
    }
    # add headers
    if ($null -ne $headers) {
        $headers = $defaultHeaders + $headers
    } else {
        $headers = $defaultHeaders
    }
    $jsonHeaders = (convertToJson $headers)
    return @{"raw" = $headers; "json" = $jsonHeaders}
}

function handleParams($params) {
    $defaultParams = @{"ScriptVersion" = $Version}
    # add Params
    if ($null -ne $params) {
        $params = $defaultParams + $params
    } else {
        $params = $defaultParams
    }
    $jsonParams = (convertToJson $params)
    return @{"raw" = $params; "json" = $jsonParams}
}

function handleUrlPlaceholders($url) {
    $url = $url.Replace('{dId}',$dId)
    log "debug" "URL after replacing placeholders: $url"
    return $url
}

function parseRawContent($rawContent) {
    $parsedContent = @()
    $lines = $rawContent -split '\r?\n'
    foreach ($line in $lines) {
        $kvp = $line -split ':'
        $parsedContent += @{$kvp[0] = $kvp[1]}
    }
    return $parsedContent
}