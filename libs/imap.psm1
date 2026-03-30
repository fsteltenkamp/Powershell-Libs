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
        Version : 1.1.1
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
        [bool]$Recursive,
        [switch]$Verbose
    )
    
    try {
        if ($Verbose) { Write-Host "Rufe Ordnerliste ab..." }
        
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
        
        if ($Verbose) { Write-Host "Gefundene Ordner: $($folders.Count)" -ForegroundColor Green }
        return $folders
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Abrufen der Ordner: $_" -ForegroundColor Red }
        return @()
    }
}

function Download-EmailsFromFolder {
    param(
        [hashtable]$Connection,
        [string]$FolderName,
        [string]$TargetPath,
        [int]$MaxEmails,
        [switch]$DeleteAfterDownload,
        [switch]$Verbose
    )
    
    try {
        # Ordner erstellen
        if (-not (Test-Path $TargetPath)) {
            New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
            if ($Verbose) { Write-Host "Ordner erstellt: $TargetPath" }
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
            if ($Verbose) { Write-Host "Keine E-Mails in Ordner: $FolderName" }
            return 0
        }
        
        # Limit anpassen falls gesetzt
        if ($MaxEmails -gt 0 -and $emailCount -gt $MaxEmails) {
            $emailCount = $MaxEmails
        }
        
        if ($Verbose) { Write-Host "Lade $emailCount E-Mails aus '$FolderName' herunter..." }

        $downloadedInFolder = 0

        for ($msgNo = 1; $msgNo -le $emailCount; $msgNo++) {
            $counter = $Connection.CommandCounter
            $Connection.CommandCounter++
            $tag = "A$($counter.ToString('000'))"
            $fetchCmd = "$tag FETCH $msgNo (INTERNALDATE BODY.PEEK[])"

            $writer.WriteLine($fetchCmd)
            $writer.Flush()

            $inMessageData = $false
            $sawLiteralStart = $false
            $receivedDate = $null
            $messageBuilder = New-Object System.Text.StringBuilder

            while ($true) {
                $line = $reader.ReadLine()
                if ($null -eq $line) { break }

                if (-not $receivedDate -and $line -match 'INTERNALDATE "([^"]+)"') {
                    $internalDateRaw = $matches[1]
                    $internalDateNormalized = $internalDateRaw -replace ' ([+-]\d{2})(\d{2})$', ' $1:$2'

                    $parsedInternalDate = [DateTimeOffset]::MinValue
                    if ([DateTimeOffset]::TryParse($internalDateNormalized, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsedInternalDate)) {
                        $receivedDate = $parsedInternalDate.LocalDateTime
                    }
                }

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

                if (-not $receivedDate) {
                    $dateHeaderMatch = [System.Text.RegularExpressions.Regex]::Match($messageBuilder.ToString(), '(?im)^Date:\s*(.+)$')
                    if ($dateHeaderMatch.Success) {
                        $parsedHeaderDate = [DateTimeOffset]::MinValue
                        if ([DateTimeOffset]::TryParse($dateHeaderMatch.Groups[1].Value.Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsedHeaderDate)) {
                            $receivedDate = $parsedHeaderDate.LocalDateTime
                        }
                    }
                }

                [System.IO.File]::WriteAllText($filename, $messageBuilder.ToString(), [System.Text.Encoding]::UTF8)
                if ($receivedDate) {
                    [System.IO.File]::SetLastWriteTime($filename, $receivedDate)
                }

                $downloadedInFolder++

                if ($DeleteAfterDownload) {
                    if (Remove-ImapMessage -Connection $Connection -MessageNumber $msgNo -SkipExpunge -Verbose:$Verbose) {
                        Write-Host "X" -NoNewline
                    } else {
                        if ($Verbose) { Write-Host "Nachricht $msgNo konnte nicht gelöscht werden." -ForegroundColor Yellow }
                        Write-Host "!" -NoNewline
                    }
                } else {
                    Write-Host "." -NoNewline
                }
            } elseif (-not $sawLiteralStart) {
                if ($Verbose) { Write-Host "Nachricht $msgNo in '$FolderName' konnte nicht gelesen werden (kein Literal im FETCH-Response)." -ForegroundColor Yellow }
            }
        }
        
        Write-Host ""  # Neue Zeile nach den Punkten
        if ($Verbose) { Write-Host "Ordner '$FolderName': $downloadedInFolder E-Mails heruntergeladen" -ForegroundColor Green }
        
        return $downloadedInFolder
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Download aus Ordner '$FolderName': $_" -ForegroundColor Red }
        $script:errorCount++
        return 0
    }
}

function Invoke-ImapTaggedCommand {
    param(
        [hashtable]$Connection,
        [string]$Command,
        [bool]$ReadResponse = $true,
        [switch]$Verbose
    )

    try {
        $counter = $Connection.CommandCounter
        $Connection.CommandCounter++
        $tag = "A$($counter.ToString('000'))"
        $fullCommand = "$tag $Command"

        $writer = New-Object System.IO.StreamWriter($Connection.Stream)
        $writer.WriteLine($fullCommand)
        $writer.Flush()

        if (-not $ReadResponse) {
            return [PSCustomObject]@{
                Tag     = $tag
                Status  = $null
                Command = $fullCommand
                Lines   = @()
            }
        }

        $lines = @()
        $status = $null
        $reader = $Connection.Reader

        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line) { break }

            $lines += $line

            if ($line -match "^$tag (OK|BAD|NO)") {
                $status = $matches[1]
                break
            }
        }

        return [PSCustomObject]@{
            Tag     = $tag
            Status  = $status
            Command = $fullCommand
            Lines   = $lines
        }
    } catch {
        if ($Verbose) { Write-Host "Fehler beim IMAP-Befehl '$Command': $_" -ForegroundColor Red }
        return [PSCustomObject]@{
            Tag     = $null
            Status  = "BAD"
            Command = $Command
            Lines   = @()
        }
    }
}

function Select-ImapFolder {
    param(
        [hashtable]$Connection,
        [string]$FolderName
    )

    $safeFolder = $FolderName.Replace('"', '""')
    $result = Invoke-ImapTaggedCommand -Connection $Connection -Command "SELECT `"$safeFolder`""
    return $result.Status -eq "OK"
}

function Get-ImapMessageCount {
    param(
        [hashtable]$Connection,
        [string]$FolderName,
        [switch]$Verbose
    )

    try {
        $safeFolder = $FolderName.Replace('"', '""')
        $result = Invoke-ImapTaggedCommand -Connection $Connection -Command "STATUS `"$safeFolder`" (MESSAGES)"
        if ($result.Status -ne "OK") {
            return 0
        }

        foreach ($line in $result.Lines) {
            if ($line -match '\* STATUS .*\(.*MESSAGES\s+(\d+)') {
                return [int]$matches[1]
            }
        }

        return 0
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Abrufen der Nachrichtenanzahl: $_" -ForegroundColor Red }
        return 0
    }
}

function Search-ImapMessages {
    param(
        [hashtable]$Connection,
        [string]$Criteria = "ALL",
        [switch]$UseUid,
        [switch]$Verbose
    )

    try {
        $prefix = ""
        if ($UseUid) { $prefix = "UID " }

        $result = Invoke-ImapTaggedCommand -Connection $Connection -Command "$prefix`SEARCH $Criteria"
        if ($result.Status -ne "OK") {
            return @()
        }

        foreach ($line in $result.Lines) {
            if ($line -match '^\* SEARCH\s*(.*)$') {
                $ids = $matches[1].Trim()
                if ([string]::IsNullOrWhiteSpace($ids)) {
                    return @()
                }

                return ($ids -split '\s+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
            }
        }

        return @()
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Suchen von Nachrichten: $_" -ForegroundColor Red }
        return @()
    }
}

function Set-ImapMessageFlags {
    param(
        [hashtable]$Connection,
        [int]$MessageNumber,
        [string[]]$Flags,
        [switch]$Add,
        [switch]$Remove,
        [switch]$UseUid,
        [switch]$Verbose
    )

    try {
        if ($null -eq $Flags -or $Flags.Count -eq 0) {
            if ($Verbose) { Write-Host "Keine Flags angegeben." -ForegroundColor Yellow }
            return $false
        }

        $mode = "FLAGS.SILENT"
        if ($Add) {
            $mode = "+FLAGS.SILENT"
        } elseif ($Remove) {
            $mode = "-FLAGS.SILENT"
        }

        $idPrefix = ""
        if ($UseUid) { $idPrefix = "UID " }

        $flagList = ($Flags -join ' ')
        $result = Invoke-ImapTaggedCommand -Connection $Connection -Command "$idPrefix`STORE $MessageNumber $mode ($flagList)"
        return $result.Status -eq "OK"
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Setzen von Flags: $_" -ForegroundColor Red }
        return $false
    }
}

function Remove-ImapMessage {
    param(
        [hashtable]$Connection,
        [int]$MessageNumber,
        [switch]$UseUid,
        [switch]$SkipExpunge,
        [switch]$Verbose
    )

    try {
        $deletedSet = Set-ImapMessageFlags -Connection $Connection -MessageNumber $MessageNumber -Flags @('\\Deleted') -Add -UseUid:$UseUid -Verbose:$Verbose
        if (-not $deletedSet) {
            return $false
        }

        if ($SkipExpunge) {
            return $true
        }

        $expunge = Invoke-ImapTaggedCommand -Connection $Connection -Command "EXPUNGE"
        return $expunge.Status -eq "OK"
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Löschen der Nachricht $MessageNumber : $_" -ForegroundColor Red }
        return $false
    }
}

function Move-ImapMessage {
    param(
        [hashtable]$Connection,
        [int]$MessageNumber,
        [string]$DestinationFolder,
        [switch]$UseUid,
        [switch]$ExpungeSource,
        [switch]$Verbose
    )

    try {
        $safeFolder = $DestinationFolder.Replace('"', '""')

        $copyPrefix = ""
        if ($UseUid) { $copyPrefix = "UID " }

        $copyResult = Invoke-ImapTaggedCommand -Connection $Connection -Command "$copyPrefix`COPY $MessageNumber `"$safeFolder`""
        if ($copyResult.Status -ne "OK") {
            return $false
        }

        return Remove-ImapMessage -Connection $Connection -MessageNumber $MessageNumber -UseUid:$UseUid -SkipExpunge:(-not $ExpungeSource) -Verbose:$Verbose
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Verschieben der Nachricht $MessageNumber : $_" -ForegroundColor Red }
        return $false
    }
}

function Get-ImapMessages {
    param(
        [hashtable]$Connection,
        [string]$FolderName,
        [string]$TargetPath,
        [int]$MaxEmails = 0,
        [switch]$Verbose
    )

    return Download-EmailsFromFolder -Connection $Connection -FolderName $FolderName -TargetPath $TargetPath -MaxEmails $MaxEmails -Verbose:$Verbose
}

function Disconnect-ImapServer {
    param(
        [hashtable]$Connection,
        [switch]$Verbose
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
        
        if ($Verbose) { Write-Host "Verbindung getrennt" }
    } catch {
        if ($Verbose) { Write-Host "Fehler beim Trennen der Verbindung: $_" -ForegroundColor Yellow }
    }
}

# ---------------------------------------------------------------------------
#  Exports
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'Connect-ImapServer',
    'Send-ImapCommand',
    'Get-ImapFolders',
    'Select-ImapFolder',
    'Get-ImapMessageCount',
    'Search-ImapMessages',
    'Set-ImapMessageFlags',
    'Remove-ImapMessage',
    'Move-ImapMessage',
    'Download-EmailsFromFolder',
    'Get-ImapMessages',
    'Disconnect-ImapServer'
)