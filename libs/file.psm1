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
        Write-Host "Error occurred while creating directory '$Path': $_"
        throw
    }
    Write-Host "Directory '$Path' created successfully."
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
        Write-Host "$Path exists."
    } else {
        Write-Host "$Path does not exist, creating..."
        New-Folder -Path $Path
        Confirm-Folder -Path $Path
    }
}

function Check-Folder {
    <#
    .SYNOPSIS
        Checks if a directory exists at the given path.
    .PARAMETER Path
        The path of the directory to check.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    return Test-Path -Path $Path -PathType Container
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "New-Folder",
    "Confirm-Folder",
    "Check-Folder"
)