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

function stringHash($str) {
    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    $hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($str)))
    return $hash
}

function fileHash($filePath, $algo = "sha256") {
    if ($algo -eq "md5") {
        $md5 = Get-FileHash $filePath -Algorithm MD5
        return $md5
    }
    if ($algo -eq "sha256") {
        $sha256 = Get-FileHash $filePath -Algorithm sha256
        return $sha256
    }
}