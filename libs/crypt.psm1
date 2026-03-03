<#
    .SYNOPSIS
        Library for Cryptography-Operations

    .DESCRIPTION
        Provides functions for cryptography operations like encryption, decryption, hashing, etc.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Exitcodes:
        - 1: General error
#>

function Get-StringHash {
    <#
    .SYNOPSIS
        Returns the MD5 hash of a string.
    .PARAMETER String
        The string to hash.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$String
    )
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    return [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($String)))
}

function Get-FileChecksum {
    <#
    .SYNOPSIS
        Returns the hash of a file.
    .PARAMETER FilePath
        The path to the file to hash.
    .PARAMETER Algorithm
        The hashing algorithm to use. Defaults to SHA256.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [ValidateSet("MD5", "SHA256")]
        [string]$Algorithm = "SHA256"
    )
    return Get-FileHash -Path $FilePath -Algorithm $Algorithm
}

Export-ModuleMember -Function Get-StringHash, Get-FileChecksum
