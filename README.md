# PowerShell Libraries

This repository provides a collection of PowerShell modules (.psm1) for common tasks, designed to be easily imported and updated at runtime.

## Usage

Libraries are PowerShell modules with proper Verb-Noun function naming. They can be used standalone or with the updater script.

### Standalone Usage
Download the desired `.psm1` file and import it:
```powershell
Import-Module ./libs/crypt.psm1
Get-StringHash -String "Hello World"
```

### Using the Updater
The updater script automatically downloads, updates, and imports modules. Add this to the top of your script:
```powershell
# Define libraries to import (replace with your needs)
$libs = @("crypt", "file", "logger", "util")
# Download and import the Updater Script:
$updaterUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/updater.psm1"
$updaterPath = "$PSScriptRoot\updater.psm1"
Invoke-WebRequest -Uri $updaterUrl -OutFile $updaterPath -UseBasicParsing
Import-Module $updaterPath -Force
# Run the update function:
Update-Libs -Libs $libs
```

After importing, functions are available as if defined locally.

## Libraries

### Crypt Library
Cryptographic operations.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `Get-StringHash` | `-String`: The string to hash | `Get-StringHash -String "Test"` | Returns MD5 hash of the string |
| `Get-FileChecksum` | `-FilePath`: Path to file, `-Algorithm`: MD5 or SHA256 | `Get-FileChecksum -FilePath file.txt -Algorithm SHA256` | Returns file checksum |

### File Library
File and directory operations.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `New-Folder` | `-Path`: Directory path | `New-Folder -Path "C:\NewDir"` | Creates a new directory |
| `Confirm-Folder` | `-Path`: Directory path | `Confirm-Folder -Path "C:\Dir"` | Ensures directory exists, creates if needed |

### HTTP Library
Fully self-contained HTTP request handling. Every request function returns a structured result object instead of throwing exceptions, so the calling script has full control over error handling.

**Result Object** — all request functions return:
| Property | Type | Description |
|----------|------|-------------|
| `Success` | bool | `$true` if the request completed with a success status code |
| `StatusCode` | int | HTTP status code (0 if the request never reached the server) |
| `Data` | object | Parsed JSON body, raw string, or file path (for downloads) |
| `Headers` | object | Response headers |
| `Error` | string | Error message including response body when available |

#### HTTP Verb Functions

| Function | Parameters | Purpose |
|----------|------------|---------|
| `Invoke-HttpGet` | `-Url`, `-Headers`, `-QueryParams`, `-TimeoutSec` | Sends a GET request |
| `Invoke-HttpPost` | `-Url`, `-Body`, `-Headers`, `-QueryParams`, `-ContentType`, `-TimeoutSec` | Sends a POST request |
| `Invoke-HttpPut` | `-Url`, `-Body`, `-Headers`, `-QueryParams`, `-ContentType`, `-TimeoutSec` | Sends a PUT request |
| `Invoke-HttpPatch` | `-Url`, `-Body`, `-Headers`, `-QueryParams`, `-ContentType`, `-TimeoutSec` | Sends a PATCH request |
| `Invoke-HttpDelete` | `-Url`, `-Headers`, `-QueryParams`, `-TimeoutSec` | Sends a DELETE request |
| `Invoke-HttpHead` | `-Url`, `-Headers`, `-QueryParams`, `-TimeoutSec` | Sends a HEAD request |
| `Invoke-HttpRequest` | `-Method`, `-Url`, `-Body`, `-Headers`, `-QueryParams`, `-ContentType`, `-TimeoutSec` | General-purpose request (any HTTP method) |

#### Utility Functions

| Function | Parameters | Purpose |
|----------|------------|---------|
| `Save-RemoteFile` | `-DownloadUrl`, `-SavePath`, `-Headers`, `-TimeoutSec` | Downloads a file to disk |
| `New-RequestHeaders` | `-Headers`, `-BearerToken`, `-ContentType` | Builds a merged headers hashtable |
| `New-RequestParams` | `-Params`, `-Defaults` | Merges default and custom query parameters |
| `Resolve-UrlPlaceholders` | `-Url`, `-Placeholders` | Replaces `{name}` placeholders in a URL from a hashtable |
| `ConvertFrom-RawContent` | `-RawContent` | Parses `key:value` lines into an ordered hashtable |
| `ConvertTo-QueryString` | `-Params` | Converts a hashtable to a URL-encoded query string |
| `Test-Url` | `-Url`, `-TimeoutSec` | Checks whether a URL is reachable (HEAD request) |

#### Full Usage Example

```powershell
# ---- Import the module ----
Import-Module ./libs/http.psm1 -Force

# ---- Build authenticated headers ----
$headers = New-RequestHeaders -BearerToken "my-secret-token" `
    -Headers @{ "X-Custom-Header" = "my-value" }

# ---- GET request with query parameters ----
$result = Invoke-HttpGet -Url "https://jsonplaceholder.typicode.com/posts" `
    -Headers $headers `
    -QueryParams @{ userId = 1; _limit = 5 }

if ($result.Success) {
    Write-Host "Got $($result.Data.Count) posts (HTTP $($result.StatusCode))"
    $result.Data | ForEach-Object { Write-Host " - $($_.title)" }
} else {
    Write-Error "GET failed: $($result.Error)"
}

# ---- POST request with a JSON body ----
$newPost = @{
    title  = "Hello from PowerShell"
    body   = "This post was created via Invoke-HttpPost"
    userId = 1
}
$postResult = Invoke-HttpPost -Url "https://jsonplaceholder.typicode.com/posts" `
    -Body $newPost -Headers $headers

if ($postResult.Success) {
    Write-Host "Created post with ID $($postResult.Data.id)"
} else {
    Write-Error "POST failed (HTTP $($postResult.StatusCode)): $($postResult.Error)"
}

# ---- URL placeholder resolution ----
$url = Resolve-UrlPlaceholders `
    -Url "https://api.example.com/users/{userId}/posts/{postId}" `
    -Placeholders @{ userId = 42; postId = 7 }
# Result: https://api.example.com/users/42/posts/7

# ---- Download a file ----
$dlResult = Save-RemoteFile `
    -DownloadUrl "https://example.com/archive.zip" `
    -SavePath "$PSScriptRoot\downloads\archive.zip"

if (-not $dlResult.Success) {
    Write-Error "Download failed: $($dlResult.Error)"
}

# ---- Quick reachability check ----
$health = Test-Url -Url "https://example.com" -TimeoutSec 5
if ($health.Success) {
    Write-Host "Site is up (HTTP $($health.StatusCode))"
} else {
    Write-Warning "Site is down: $($health.Error)"
}
```

### Logger Library
Logging functionality.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `Set-LogLevel` | `-Level`: debug, info, warning, error, success | `Set-LogLevel -Level "debug"` | Sets logging level |
| `Enable-Logfile` | `-FilePath`: Log file path | `Enable-Logfile -FilePath "C:\log.txt"` | Enables file logging |
| `Log` | `-Level`, `-Message` | `Log -Level "info" -Message "Test message"` | Logs a message |

### Util Library
Utility functions.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `Get-PublicIp` | None | `Get-PublicIp` | Returns public IPv4/IPv6 addresses |
| `Get-Hostname` | None | `Get-Hostname` | Returns machine hostname |

### WinSAT Library
Windows System Assessment Tool integration.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `Invoke-WinSATDiskTest` | `-DriveLetter`, `-ReadOnly`, `-WriteOnly`, `-Sequential`, `-Random` | `Invoke-WinSATDiskTest -DriveLetter "C"` | Runs disk performance test |
| `Invoke-WinSATCpuTest` | `-Encryption`, `-Compression` | `Invoke-WinSATCpuTest -Encryption` | Runs CPU performance test |
| `Invoke-WinSATMemoryTest` | None | `Invoke-WinSATMemoryTest` | Runs memory bandwidth test |
| `Invoke-WinSATGraphicsTest` | `-D3DOnly`, `-DwmOnly`, `-DirectX10` | `Invoke-WinSATGraphicsTest -D3DOnly` | Runs graphics tests |
| `Invoke-FullWinSAT` | None | `Invoke-FullWinSAT` | Runs complete WinSAT assessment |
| `Get-WinSATResults` | `-Section`, `-Format` | `Get-WinSATResults -Section "Metrics" -Format "json"` | Retrieves parsed results |

`Get-WinSATResults` returns structured data from the XML output, including ProgramInfo, SystemEnvironment, WinSPR scores, and detailed Metrics with tags.