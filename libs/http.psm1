<#
    .SYNOPSIS
        Library for HTTP-Operations

    .DESCRIPTION
        Provides self-contained functions for HTTP operations including sending
        requests (GET, POST, PUT, PATCH, DELETE, HEAD), downloading files,
        building headers/query-strings, and parsing response content.

        Every function is fully parameterised — no external variables are
        assumed. Errors are caught internally and returned as structured
        result objects so the calling script can decide how to handle them.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.1
        Url     : https://github.com/fsteltenkamp/powershell-libs
#>

# ---------------------------------------------------------------------------
#  Private helper – builds the standard response object every public
#  request function returns.
# ---------------------------------------------------------------------------
function New-HttpResult {
    param(
        [bool]$Success,
        [int]$StatusCode = 0,
        $Data = $null,
        $Headers = $null,
        [string]$Error = $null
    )
    return [PSCustomObject]@{
        Success    = $Success
        StatusCode = $StatusCode
        Data       = $Data
        Headers    = $Headers
        Error      = $Error
    }
}

# ---------------------------------------------------------------------------
#  Public functions
# ---------------------------------------------------------------------------

function Save-RemoteFile {
    <#
    .SYNOPSIS
        Downloads a file from a URL and saves it to a local path.
    .DESCRIPTION
        Uses Invoke-WebRequest to download the file. Returns a result object
        with Success, StatusCode, and Error properties.
    .PARAMETER DownloadUrl
        The URL to download the file from.
    .PARAMETER SavePath
        The local path to save the file to.
    .PARAMETER Headers
        Optional headers hashtable to send with the request.
    .PARAMETER TimeoutSec
        Timeout in seconds for the download (default 300).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    .EXAMPLE
        $result = Save-RemoteFile -DownloadUrl "https://example.com/file.zip" -SavePath "C:\temp\file.zip"
        if (-not $result.Success) { Write-Error $result.Error }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadUrl,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SavePath,

        [hashtable]$Headers = @{},

        [int]$TimeoutSec = 300
    )

    try {
        $parentDir = Split-Path -Path $SavePath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $splat = @{
            Uri             = $DownloadUrl
            OutFile         = $SavePath
            UseBasicParsing = $true
            TimeoutSec      = $TimeoutSec
            ErrorAction     = 'Stop'
        }
        if ($Headers.Count -gt 0) { $splat['Headers'] = $Headers }

        Invoke-WebRequest @splat

        return New-HttpResult -Success $true -StatusCode 200 -Data $SavePath
    }
    catch {
        $statusCode = 0
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        return New-HttpResult -Success $false -StatusCode $statusCode `
            -Error "Download failed for ${DownloadUrl}: $_"
    }
}

function New-RequestHeaders {
    <#
    .SYNOPSIS
        Builds a headers hashtable, merging defaults with any provided headers.
    .PARAMETER Headers
        Additional headers to merge with the defaults.
    .PARAMETER BearerToken
        If supplied, an Authorization: Bearer header is added.
    .PARAMETER ContentType
        The Accept / Content-Type value (default "application/json").
    .OUTPUTS
        Hashtable – the merged headers ready for Invoke-RestMethod / Invoke-WebRequest.
    .EXAMPLE
        $h = New-RequestHeaders -BearerToken $token -Headers @{ "X-Custom" = "value" }
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Headers = @{},

        [string]$BearerToken = $null,

        [string]$ContentType = "application/json"
    )

    $merged = @{ "Accept" = $ContentType }

    if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
        $merged["Authorization"] = "Bearer $BearerToken"
    }

    foreach ($key in $Headers.Keys) {
        $merged[$key] = $Headers[$key]
    }

    return $merged
}

function New-RequestParams {
    <#
    .SYNOPSIS
        Builds a query-parameter hashtable by merging defaults with provided params.
    .PARAMETER Params
        Additional parameters to merge with the defaults.
    .PARAMETER Defaults
        Default parameters (if any). If omitted an empty hashtable is used.
    .OUTPUTS
        Hashtable – the merged parameters.
    .EXAMPLE
        $qp = New-RequestParams -Defaults @{ "api-version" = "2.0" } -Params @{ "page" = 1 }
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Params = @{},
        [hashtable]$Defaults = @{}
    )

    $merged = @{}
    foreach ($key in $Defaults.Keys) { $merged[$key] = $Defaults[$key] }
    foreach ($key in $Params.Keys)   { $merged[$key] = $Params[$key] }

    return $merged
}

function Resolve-UrlPlaceholders {
    <#
    .SYNOPSIS
        Replaces placeholders in a URL string with supplied values.
    .DESCRIPTION
        Accepts a hashtable of placeholder-name → value pairs and replaces
        every occurrence of {name} in the URL.
    .PARAMETER Url
        The URL containing placeholders to resolve.
    .PARAMETER Placeholders
        Hashtable mapping placeholder names (without braces) to their values.
    .OUTPUTS
        String – the URL with all placeholders resolved.
    .EXAMPLE
        Resolve-UrlPlaceholders -Url "https://api.example.com/users/{userId}/posts/{postId}" `
            -Placeholders @{ userId = 42; postId = 7 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable]$Placeholders
    )

    foreach ($key in $Placeholders.Keys) {
        $Url = $Url.Replace("{$key}", [string]$Placeholders[$key])
    }

    return $Url
}

function ConvertFrom-RawContent {
    <#
    .SYNOPSIS
        Parses raw key:value line content into an ordered hashtable.
    .DESCRIPTION
        Splits the input on newlines, then splits each line on the first ':'
        character. Empty / whitespace-only lines are skipped.
    .PARAMETER RawContent
        The raw string content to parse.
    .OUTPUTS
        [ordered] hashtable of key-value pairs.
    .EXAMPLE
        $data = ConvertFrom-RawContent -RawContent (Get-Content raw.txt -Raw)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RawContent
    )

    $result = [ordered]@{}
    $lines  = $RawContent -split '\r?\n'

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $colonIndex = $line.IndexOf(':')
        if ($colonIndex -lt 0) {
            Write-Warning "Skipping line without ':' delimiter: $line"
            continue
        }

        $key   = $line.Substring(0, $colonIndex).Trim()
        $value = $line.Substring($colonIndex + 1).Trim()

        if ([string]::IsNullOrWhiteSpace($key)) {
            Write-Warning "Skipping line with empty key: $line"
            continue
        }

        $result[$key] = $value
    }

    return $result
}

# ---------------------------------------------------------------------------
#  Core HTTP verb functions
# ---------------------------------------------------------------------------

function Invoke-HttpGet {
    <#
    .SYNOPSIS
        Sends an HTTP GET request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable – appended to the URL.
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    .EXAMPLE
        $r = Invoke-HttpGet -Url "https://api.example.com/items" -Headers (New-RequestHeaders -BearerToken $tok)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'GET' -Url $Url -Headers $Headers `
        -QueryParams $QueryParams -TimeoutSec $TimeoutSec
}

function Invoke-HttpPost {
    <#
    .SYNOPSIS
        Sends an HTTP POST request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Body
        The request body – a hashtable, string, or any object that can be
        serialised to JSON.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable.
    .PARAMETER ContentType
        Body content type (default "application/json").
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    .EXAMPLE
        $r = Invoke-HttpPost -Url "https://api.example.com/items" -Body @{ name = "widget" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        $Body = $null,
        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [string]$ContentType = "application/json",
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'POST' -Url $Url -Body $Body `
        -Headers $Headers -QueryParams $QueryParams `
        -ContentType $ContentType -TimeoutSec $TimeoutSec
}

function Invoke-HttpPut {
    <#
    .SYNOPSIS
        Sends an HTTP PUT request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Body
        The request body.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable.
    .PARAMETER ContentType
        Body content type (default "application/json").
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        $Body = $null,
        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [string]$ContentType = "application/json",
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'PUT' -Url $Url -Body $Body `
        -Headers $Headers -QueryParams $QueryParams `
        -ContentType $ContentType -TimeoutSec $TimeoutSec
}

function Invoke-HttpPatch {
    <#
    .SYNOPSIS
        Sends an HTTP PATCH request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Body
        The request body.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable.
    .PARAMETER ContentType
        Body content type (default "application/json").
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        $Body = $null,
        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [string]$ContentType = "application/json",
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'PATCH' -Url $Url -Body $Body `
        -Headers $Headers -QueryParams $QueryParams `
        -ContentType $ContentType -TimeoutSec $TimeoutSec
}

function Invoke-HttpDelete {
    <#
    .SYNOPSIS
        Sends an HTTP DELETE request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable.
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'DELETE' -Url $Url -Headers $Headers `
        -QueryParams $QueryParams -TimeoutSec $TimeoutSec
}

function Invoke-HttpHead {
    <#
    .SYNOPSIS
        Sends an HTTP HEAD request and returns a structured result.
    .PARAMETER Url
        The target URL.
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable.
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data (always $null), Headers, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [int]$TimeoutSec = 30
    )

    return Invoke-HttpRequest -Method 'HEAD' -Url $Url -Headers $Headers `
        -QueryParams $QueryParams -TimeoutSec $TimeoutSec
}

function Invoke-HttpRequest {
    <#
    .SYNOPSIS
        General-purpose HTTP request. Prefer the verb-specific wrappers
        (Invoke-HttpGet, Invoke-HttpPost, …) for readability.
    .PARAMETER Method
        HTTP method (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS).
    .PARAMETER Url
        The target URL.
    .PARAMETER Body
        Optional request body (will be converted to JSON if it is a hashtable / PSObject).
    .PARAMETER Headers
        Optional request headers hashtable.
    .PARAMETER QueryParams
        Optional query parameters hashtable – appended to the URL.
    .PARAMETER ContentType
        Body content type (default "application/json").
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 30).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    .EXAMPLE
        $r = Invoke-HttpRequest -Method 'GET' -Url "https://api.example.com/items"
        if ($r.Success) { $r.Data | ForEach-Object { $_.name } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS')]
        [string]$Method,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        $Body = $null,
        [hashtable]$Headers = @{},
        [hashtable]$QueryParams = @{},
        [string]$ContentType = "application/json",
        [int]$TimeoutSec = 30
    )

    try {
        # ---- Append query parameters to URL ----
        if ($QueryParams.Count -gt 0) {
            $qsParts = foreach ($key in $QueryParams.Keys) {
                "{0}={1}" -f [Uri]::EscapeDataString($key),
                              [Uri]::EscapeDataString([string]$QueryParams[$key])
            }
            $separator = if ($Url.Contains('?')) { '&' } else { '?' }
            $Url = $Url + $separator + ($qsParts -join '&')
        }

        # ---- Build splat ----
        $splat = @{
            Uri                = $Url
            Method             = $Method
            UseBasicParsing    = $true
            TimeoutSec         = $TimeoutSec
            ErrorAction        = 'Stop'
        }

        if ($Headers.Count -gt 0) { $splat['Headers'] = $Headers }

        if ($null -ne $Body -and $Method -notin @('GET','HEAD')) {
            if ($Body -is [string]) {
                $splat['Body'] = $Body
            } else {
                $splat['Body'] = ($Body | ConvertTo-Json -Depth 10)
            }
            $splat['ContentType'] = $ContentType
        }

        # ---- Send request ----
        $response = Invoke-WebRequest @splat

        # ---- Parse response body ----
        $data = $null
        if ($response.Content) {
            try {
                $data = $response.Content | ConvertFrom-Json
            }
            catch {
                # Not JSON – return raw content
                $data = $response.Content
            }
        }

        return New-HttpResult -Success $true `
            -StatusCode ([int]$response.StatusCode) `
            -Data $data `
            -Headers $response.Headers

    }
    catch {
        $statusCode = 0
        $errorBody  = $null

        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode

            try {
                $reader = [System.IO.StreamReader]::new(
                    $_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                $reader.Close()
            } catch {
                # Could not read error body – ignore
            }
        }

        $errorMessage = "$Method $Url failed: $_"
        if ($errorBody) { $errorMessage += "`nResponse body: $errorBody" }

        return New-HttpResult -Success $false -StatusCode $statusCode `
            -Error $errorMessage
    }
}

function ConvertTo-QueryString {
    <#
    .SYNOPSIS
        Converts a hashtable to a URL-encoded query string.
    .PARAMETER Params
        Hashtable of key-value pairs.
    .OUTPUTS
        String – e.g. "key1=val1&key2=val2" (no leading '?').
    .EXAMPLE
        $qs = ConvertTo-QueryString -Params @{ page = 1; size = 20 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable]$Params
    )

    $parts = foreach ($key in $Params.Keys) {
        "{0}={1}" -f [Uri]::EscapeDataString($key),
                      [Uri]::EscapeDataString([string]$Params[$key])
    }

    return ($parts -join '&')
}

function Test-Url {
    <#
    .SYNOPSIS
        Checks whether a URL is reachable by sending an HTTP HEAD request.
    .PARAMETER Url
        The URL to test.
    .PARAMETER TimeoutSec
        Request timeout in seconds (default 10).
    .OUTPUTS
        PSCustomObject with Success, StatusCode, Data, Headers, Error.
    .EXAMPLE
        if ((Test-Url -Url "https://example.com").Success) { "reachable" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,

        [int]$TimeoutSec = 10
    )

    return Invoke-HttpHead -Url $Url -TimeoutSec $TimeoutSec
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    # Utilities
    'New-RequestHeaders'
    'New-RequestParams'
    'Resolve-UrlPlaceholders'
    'ConvertFrom-RawContent'
    'ConvertTo-QueryString'
    'Test-Url'
    'Save-RemoteFile'

    # HTTP verbs
    'Invoke-HttpRequest'
    'Invoke-HttpGet'
    'Invoke-HttpPost'
    'Invoke-HttpPut'
    'Invoke-HttpPatch'
    'Invoke-HttpDelete'
    'Invoke-HttpHead'
)
