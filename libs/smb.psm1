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
        Library for SMB-Specific Operations

    .DESCRIPTION
        Provides functions for SMB-specific operations like checking connections to SMB shares.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function Check-SmbConnection {
    <#
    .SYNOPSIS
        Checks if a connection to the specified SMB share can be established.
    .PARAMETER Path
        The path of the SMB share to check.
    .PARAMETER Rw
        If set, the function will also check if write permissions are available on the SMB share.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Rw
    )
    try {
        # Check if the Host is reachable on TCP 445:
        $host = ($Path -split '\\')[2]  # Extract the host from the SMB path
        $port = 445
        $connectionResult = Test-NetConnection -ComputerName $host -Port $port -InformationLevel Quiet
        if (-not $connectionResult.TcpTestSucceeded) {
            throw "Host '$host' is not reachable on port $port."
        } else {
            # If the host is reachable, we can try to access the share. This will check if the share is accessible and if we have permissions to access it.
            try {
                Get-ChildItem -Path $Path -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Unable to access SMB share at '$Path'. Please check if the share exists and if you have the necessary permissions."
            }
            if (-not $Rw) {
                # We should not check rw permissions, so we can return here.
                return $true
            }
            # If we can list the contents, we can assume the share is accessible. We can also try to create a test file to check write permissions, but this might not be desirable in all cases.
            $testPath = Join-Path -Path $Path -ChildPath "test.txt"
            try {
                New-Item -Path $testPath -ItemType File -ErrorAction Stop | Out-Null
            } catch {
                throw "Unable to write to SMB share at '$Path'. Please check if you have the necessary permissions."
            }
            try {
                Remove-Item -Path $testPath -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Unable to remove test file from SMB share at '$Path'. Please check if you have the necessary permissions."
            }
            
            return $true
        }
    }
    catch {
        Write-Host "Error occurred while checking SMB connection to '$Path': $_"
        throw
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    "Check-SmbConnection"
)