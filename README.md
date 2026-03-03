# Powershell Libraries

This repository aims to implement a lot of commonly used code as libraries  
that can easily be added at runtime.  

## Usage

The individual Library files can be used stand-alone or in conjuction with the updater script.  
To use them standalone, just download them and reference them using powershells
```powershell
Import-Module <path>
```
  
To use the updater, add this code-snippet at the top of your script:
```powershell
# Define libraries to import: (Replace with the libraries you want to use)
$libs = @("logger", "util")
# Download and import the Updater Script:
$updaterUrl = "https://raw.githubusercontent.com/fsteltenkamp/powershell-libs/main/updater.psm1"
$updaterPath = "$PSScriptRoot\updater.psm1"
Invoke-WebRequest -Uri $updaterUrl -OutFile $updaterPath -UseBasicParsing
Import-Module $updaterPath -Force
# Run the update function:
Update-Libs -Libs $libs
```

The Updater is automatically downlaoded and handles the loading, updating and importing of the libraries automatically.  
After the Libraries are imported, you can use their Methods as if they were defined in the main script itself:

### Crypt Library
This Library contains Methods that allow for easy cryptographic opterations on commonly used formats.

|Method|Parameters|Example|Purpose|
|---|---|---|---|
|Get-StringHash|String: the string to hash|`Get-StringHash -String "Test string"`|Returns the Md5 Hash of the String|
|Get-FileChecksum|FilePath: the path to the file, Algorithm: Either Md5 or SHA256|`Get-FileChecksum -FilePath hashme.txt -Algorithm Md5`|Returns the Checksum for a file in either Md5 or SHA256 Algorithm|

### File Library

...

### Http Library

...

### Logger Library

...

### Util Library

...

### WinSAT Library

...