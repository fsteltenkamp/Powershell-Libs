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

function newFolder($path) {
    try {
        New-Item -Path $path -ItemType Directory -ErrorAction Stop | Out-Null #-Force
    }
    catch {
        log "error" -Message "Unable to create directory '$path'. Error was: $_"
    }
    log "success" "Successfully created directory '$path'."
}

function checkFolder($path) {
    if(Test-Path -Path $path -PathType Container) {
        log "debug" "$path exists."
    } else {
        log "debug" "$path does not exist, creating..."
        newFolder($path)
        checkFolder $path
    }
}