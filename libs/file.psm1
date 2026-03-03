<#
    .SYNOPSIS
        Library for File-Operations

    .DESCRIPTION
        Provides functions for file operations like copying, moving, deleting, etc.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function New-Folder {
    <#
    .SYNOPSIS
        Creates a new directory at the given path.
    .PARAMETER Path
        The path of the directory to create.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    try {
        New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        log "error" -Message "Unable to create directory '$Path'. Error was: $_"
    }
    log "success" "Successfully created directory '$Path'."
}

function Confirm-Folder {
    <#
    .SYNOPSIS
        Ensures a directory exists, creating it if necessary.
    .PARAMETER Path
        The path of the directory to confirm.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (Test-Path -Path $Path -PathType Container) {
        log "debug" "$Path exists."
    } else {
        log "debug" "$Path does not exist, creating..."
        New-Folder -Path $Path
        Confirm-Folder -Path $Path
    }
}

Export-ModuleMember -Function New-Folder, Confirm-Folder
