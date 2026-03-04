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
HTTP request handling.

| Function | Parameters | Example | Purpose |
|----------|------------|---------|---------|
| `Save-RemoteFile` | `-DownloadUrl`, `-SavePath` | `Save-RemoteFile -DownloadUrl "http://example.com/file.zip" -SavePath "C:\file.zip"` | Downloads a file |
| `New-RequestHeaders` | `-Headers`, `-UseAuth` | `New-RequestHeaders -UseAuth $true` | Builds request headers |
| `New-RequestParams` | `-Params` | `New-RequestParams -Params @{key="value"}` | Builds query parameters |
| `Resolve-UrlPlaceholders` | `-Url` | `Resolve-UrlPlaceholders -Url "http://api.com/{id}"` | Replaces placeholders in URL |
| `ConvertFrom-RawContent` | `-RawContent` | `ConvertFrom-RawContent -RawContent "key:value\nkey2:value2"` | Parses raw key:value content |

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