#
#  Copyright (c) Microsoft Corporation. All rights reserved.
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

<# 
.Synopsis
   A simple ad-hoc webserver written in PowerShell.
   
.DESCRIPTION
   This script implements a simple webserver for development purposes.

   The implementation is pretty much as efficient as you can get in PowerShell,
   but it's not going to win any prizes for speed. Good when you need an adhoc
   webserver.
   
   It supports 
    - setting base folder (current directory by default)
    - navigable directory listings (on by default)
    - arbitrary ports (default 80/443),
    - arbitrary host names    
    - HTTP  
    - HTTPS -- use my CertScriptTool to help make a cert for that: http://github.com/fearthecowboy/CertScriptTool 
   
   =========================
   Nifty Feature Of the Week
   =========================
   This webserver script watches itself to see if it's modified and restarts 
   itself when it detects a new version. This makes it really easy to launch 
   the webserver, then open this script in an editor, and make changes that
   take effect immediately upon saving.
   
   ========================
   Second Nifty Feature
   ========================
   The script has a place to cherry-pick a URL if you want to send something 
   specific -- look for the comment: 
       # handle a few paths manually
   and add your own custom responses.
   
    Default custom responses:
    
    http://localhost/about -- shows an about page
    http://localhost/restart -- restarts the webserver script
    http://localhost/quit -- stops the webserver script

.EXAMPLE
    WebServer.ps1 
    # starts a simple webserver, hosting files from the current directory on 
    # http://*:80 and https://*:443 
    
.EXAMPLE
    WebServer.ps1 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # http://*:80 and https://*:443 
    
.EXAMPLE
    WebServer.ps1 -http 80,8080 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # http://*:80 and http://*:8080
    
.EXAMPLE
    WebServer.ps1 -https 443 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # https://*:443 (secure only)
    
.PARAMETER Root
  The folder from which to serve files from. Defaults to $PWD
  
.PARAMETER Hosts 
  The list of host names or ip addresses to listen on. Defaults to '*' (meaning all)
  
.PARAMETER Https
  The HTTPS (SSL) ports to listen on (a cert must be bound on the port for that to work!)
  
  If either Https or Http are speficied, it will *only* use what's specified.

.PARAMETER Http
  The HTTP ports to listen on.
  
  If either Https or Http are speficied, it will *only* use what's specified.
  
.PARAMETER NoFolderListing
  Specifiyng this will disable folder browsing.
  
#>
param(
     [IO.DirectoryInfo]$root = $PWD.Path
    ,[String[]]$hosts = @("*")
    ,[int[]]$Https = @()
    ,[int[]]$Http = @()
    ,[Switch]$NoFolderListing
) 
$global:restart = $false
$script:listener = $null
$counter = 0

# make sure base folder is a directory
if( !($base= (resolve-path "$($root.FullName)\" -ea 0).Path) ) {
    return write-error "Folder '$root' does not exist"
}

function Stop-Listening{
    Get-EventSubscriber | Unregister-Event
    if( $script:listener ) {
        $script:listener.Stop()
        $script:listener = $null
    }
}

function Set-ContentType($ext) {
    $k = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey($ext)
    if( $k ) {
        $v = $k.GetValue("Content Type")
        if( $v ) { $script:rs.ContentType=$v }
        $k.Dispose()
    }
}

function Send-Content($content) {
    try {
        $script:rs.ContentLength64 = $content.Length
        $script:rs.OutputStream.Write($content, 0, $content.Length)
        $script:rs.StatusCode = 200
    } catch {
        $script:rs.StatusCode = 500
    }
    finally {
        $script:rs.Close()
    }
}

function Send-Text($content) {
    Send-Content ([System.Text.Encoding]::UTF8.GetBytes($content))
}

function Send-Html($content) {
    Set-ContentType ".html"
    Send-Text "<html><body><pre>$content</pre></body></html>"
}

function Send-DirectoryInfo( $dir, $path) {
    if( $path ) { $path = "/" + $path }
    send-html $(
        "Directory: $dir<br><br>"
        "Mode            LastWriteTime         Length          Name<br>"
        "------          -------------------   --------------  ------------------------<br>"
        if( $dir -ne $base ) { "d----- $(''.PadLeft(46))<a href='$path/..'>..</a><br>" }
        dir $dir |% { 
            $each = $_
            switch( $each.GetType() ) {
                ([IO.DirectoryInfo]) { "$($each.Mode)          $($each.LastWriteTime)    $(''.PadLeft(13)) <a href='$path/$($each.Name)'>$($each.Name)</a><br>" }
                ([IO.FileInfo])      { "$($each.Mode)          $($each.LastWriteTime)    $("$($each.length)".PadLeft(13)) <a href='$path/$($each.Name)'>$($each.Name)</a><br>" } 
            }
        }
    )
}

function Send-File($file) {
    Set-ContentType ((dir $file).Extension)
    Send-Content (get-content $file -raw -encoding byte)
}

function Send-404 {
    $script:rs.StatusCode = 404
    $script:rs.Close() 
}

# clean up any leftover listeners
Stop-Listening 

# track if this script changes so we can restart.
$fsw = New-Object IO.FileSystemWatcher $PSScriptRoot, $MyInvocation.MyCommand.Name -Property @{IncludeSubdirectories = $false;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite';EnableRaisingEvents = $true }
$null = Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action { $global:restart = $true }

try {
    $script:listener = New-Object System.Net.HttpListener

    # if nothing specified do both on default ports
    if( (-not $Http) -and (-not $Https ) ) { $http = @("80"); $https=@("443") }

    # bind addresses/ports
    $hosts |% { 
        $h = $_
        $http  |% { "http://$($h):$_/" } 
        $https |% { "https://$($h):$_/" } 
    } |% { 
        $script:listener.Prefixes.Add($_)
        Write-Host "Listening on [$_]"
    }
    
    # start listening
    $script:listener.Start()
    $task = $script:listener.GetContextAsync()

    while ($script:listener.IsListening -and (-not $global:restart) )
    {
        # Incoming Request.
        if( $task.IsCompleted ) {
            $requestUrl = $task.Result.Request.Url
            $script:rs = $task.Result.Response
            $task = $script:listener.GetContextAsync()
            
            switch( $path = ($requestUrl.LocalPath) -replace '//','/' ) {
                # handle a few paths manually
                "/about" { Send-Html "FearTheCowboy's Adhoc PowerShell WebServer<br><br>Source on <a href='https://github.com/fearthecowboy/adhoc'>github</a><br>Follow me on <a href='https://twitter.com/fearthecowboy'>Twitter</a>" }
                "/quit" {  Send-Html "Quitting..."; Write-Host "`nQuitting..."; break; }
                "/restart" {Send-Html "Restarting..."; $global:restart= $true;}
                
                # files or directories
                default {
                    if( ($local = (resolve-path "$base\$path" -ea 0)) ) { 
                        switch((Get-Item $local).GetType() ) { 
                            # makes it easier to add more types later :)
                            ([Io.DirectoryInfo]) { if( $NoFolderListing ) { Send-404 } else { Send-DirectoryInfo $local.Path $path.trim("/") } }
                            ([IO.FileInfo])      { Send-File $local}
                            default { Send-404 }
                        }
                    } else { Send-404 }                            
                }
            } 

            Write-Host "$($script:rs.StatusCode): [$requestUrl] > $local"
        } else {
            [Threading.Thread]::Sleep(1)
            if( ($counter += 0.01) -gt 100 ){
                $counter = 0
            }
            Write-Progress -Activity "Listening..." -PercentComplete $counter -CurrentOperation "Idle..." -Status "Waiting For Request."
        }
    }
} finally { 
    Stop-Listening
} 

if( $global:restart ) {
    Write-Host "`nRestarting"
    $global:restart = $null
    . "$PSCommandPath" -root $base -hosts $hosts -https $https -http $http -NoFolderListing:$NoFolderListing
} else {
    Write-Host "`nFinished."
}


