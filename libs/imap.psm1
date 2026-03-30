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
        Library for interacting with imap servers.

    .DESCRIPTION
        This library provides functions to interact with imap servers.

    .NOTES
        Author  : Florian Steltenkamp
        Version : 1.0
        Url     : https://github.com/fsteltenkamp/powershell-libs
        Documentation:
        - https://helpcenter.veeam.com/docs/vbr/powershell/
#>

function Send-ImapCommand {
    param(
        [System.IO.Stream]$Stream,
        [string]$Command,
        [bool]$ExpectData = $false
    )

    try {
        $writer = New-Object System.IO.StreamWriter($Stream)
        $writer.WriteLine($Command)
        $writer.Flush()

        $reader = New-Object System.IO.StreamReader($Stream)
        $response = @()

        do {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            $response += $line
        } until ($line -match "^\w+ (OK|NO|BAD)" -and -not $ExpectData)

        return $response -join "`n"
    } catch {
        Write-Error "Failed to send IMAP command: $_"
        return $null
    }
}

function Connect-ImapServer {
    param(
        [string]$Server,
        [int]$Port = 993,
        [string]$Username,
        [string]$Password,
        [switch]$UseSsl = $true
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient($Server, $Port)
        if ($UseSsl) {
            $Stream = New-Object System.Net.Security.SslStream($client.GetStream(), $false, { $true })
            $Stream.AuthenticateAsClient($Server)
        } else {
            $Stream = $client.GetStream()
        }
        
        # Read the server's greeting
        $reader = New-Object System.IO.StreamReader($Stream)
        $welcome = $reader.ReadLine()
        Write-Host "Server Greeting: $welcome"

        # Login:
        $loginCommand = "A001 LOGIN $Username $Password`r`n"
        Send-ImapCommand -Stream $Stream -Command $loginCommand | Out-Null
        Write-Host "Successfully connected to IMAP server: $Server"

        return @{
            Client = $client
            Stream = $Stream
            Reader = $reader
            CommandCounter = 1
        }
    } catch {
        Write-Error "Failed to connect to IMAP server: $_"
        return $null
    }
}

function Get-ImapFolders {
    param(
        [hashtable]$Connection,
        [bool]$Recursive
    )
    
    try {
        Write-Log "Info" "Rufe Ordnerliste ab..."
        
        $counter = $Connection.CommandCounter
        $Connection.CommandCounter++
        $cmd = "A$($counter.ToString('000')) LIST `"`"`" `"*`""
        
        $writer = New-Object System.IO.StreamWriter($Connection.Stream)
        $writer.WriteLine($cmd)
        $writer.Flush()
        
        $folders = @()
        $reader = $Connection.Reader
        
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            
            if ($line -match '\* LIST.*"([^"]*)"' -or $line -match '\* LIST.*([^ ]+)$') {
                $folder = ($matches[1] -replace '\s+', '').Trim('"')
                if ($folder -and $folder -ne "NIL") {
                    $folders += $folder
                }
            } elseif ($line -match "^A$($counter.ToString('000')) (OK|BAD|NO)") {
                break
            }
        }
        
        Write-Log "Success" "Gefundene Ordner: $($folders.Count)"
        return $folders
    } catch {
        Write-Log "Error" "Fehler beim Abrufen der Ordner: $_"
        return @()
    }
}

function Download-EmailsFromFolder {
    param(
        [hashtable]$Connection,
        [string]$FolderName,
        [string]$TargetPath,
        [int]$MaxEmails
    )
    
    try {
        # Ordner erstellen
        if (-not (Test-Path $TargetPath)) {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
            Write-Log "Info" "Ordner erstellt: $TargetPath"
        }
        
        # Ordner auswählen
        $counter = $Connection.CommandCounter
        $Connection.CommandCounter++
        $selectCmd = "A$($counter.ToString('000')) SELECT `"$FolderName`""
        
        $writer = New-Object System.IO.StreamWriter($Connection.Stream)
        $writer.WriteLine($selectCmd)
        $writer.Flush()
        
        $reader = $Connection.Reader
        $emailCount = 0
        
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }
            
            if ($line -match '(\d+)\s+EXISTS') {
                $emailCount = [int]$matches[1]
            } elseif ($line -match "^A$($counter.ToString('000')) (OK|BAD|NO)") {
                break
            }
        }
        
        if ($emailCount -eq 0) {
            Write-Log "Info" "Keine E-Mails in Ordner: $FolderName"
            return 0
        }
        
        # Limit anpassen falls gesetzt
        if ($MaxEmails -gt 0 -and $emailCount -gt $MaxEmails) {
            $emailCount = $MaxEmails
        }
        
        Write-Log "Info" "Lade $emailCount E-Mails aus '$FolderName' herunter..."

        $downloadedInFolder = 0

        for ($msgNo = 1; $msgNo -le $emailCount; $msgNo++) {
            $counter = $Connection.CommandCounter
            $Connection.CommandCounter++
            $tag = "A$($counter.ToString('000'))"
            $fetchCmd = "$tag FETCH $msgNo BODY.PEEK[]"

            $writer.WriteLine($fetchCmd)
            $writer.Flush()

            $inMessageData = $false
            $sawLiteralStart = $false
            $messageBuilder = New-Object System.Text.StringBuilder

            while ($true) {
                $line = $reader.ReadLine()
                if ($null -eq $line) { break }

                if (-not $inMessageData -and $line -match '^\* \d+ FETCH .*\{\d+\}$') {
                    $inMessageData = $true
                    $sawLiteralStart = $true
                    continue
                }

                if ($inMessageData) {
                    if ($line -eq ")") {
                        $inMessageData = $false
                        continue
                    }

                    [void]$messageBuilder.Append($line)
                    [void]$messageBuilder.Append("`r`n")
                    continue
                }

                if ($line -match "^$tag (OK|BAD|NO)") {
                    break
                }
            }

            if ($messageBuilder.Length -gt 0) {
                $filename = "$TargetPath\Email_$($msgNo.ToString('00000')).eml"
                [System.IO.File]::WriteAllText($filename, $messageBuilder.ToString(), [System.Text.Encoding]::UTF8)
                $downloadedInFolder++
                Write-Host "." -NoNewline
            } elseif (-not $sawLiteralStart) {
                Write-Log "Warning" "Nachricht $msgNo in '$FolderName' konnte nicht gelesen werden (kein Literal im FETCH-Response)."
            }
        }
        
        Write-Host ""  # Neue Zeile nach den Punkten
        Write-Log "Success" "Ordner '$FolderName': $downloadedInFolder E-Mails heruntergeladen"
        
        return $downloadedInFolder
    } catch {
        Write-Log "Error" "Fehler beim Download aus Ordner '$FolderName': $_"
        $script:errorCount++
        return 0
    }
}

function Disconnect-ImapServer {
    param(
        [hashtable]$Connection
    )
    
    try {
        $counter = $Connection.CommandCounter
        $Connection.CommandCounter++
        $logoutCmd = "A$($counter.ToString('000')) LOGOUT"
        
        $writer = New-Object System.IO.StreamWriter($Connection.Stream)
        $writer.WriteLine($logoutCmd)
        $writer.Flush()
        $writer.Dispose()
        
        $Connection.Reader.Dispose()
        $Connection.Stream.Dispose()
        $Connection.Client.Dispose()
        
        Write-Log "Info" "Verbindung getrennt"
    } catch {
        Write-Log "Warning" "Fehler beim Trennen der Verbindung: $_"
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'Connect-ImapServer',
    'Send-ImapCommand',
    'Get-ImapFolders',
    'Get-ImapMessages',
    'Disconnect-ImapServer'
)