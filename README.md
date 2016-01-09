# WebServer.ps1

Really flexible adhoc webserver written in PowerShell.

# Description

   This script implements a simple webserver for development purposes.

   The implementation is pretty much as efficient as you can get in PowerShell,
   but it's not going to win any prizes for speed. Good when you need an adhoc
   webserver.
   
   It supports:
   
    - setting base folder (current directory by default)
    - navigable directory listings (on by default)
    - arbitrary ports (default 80/443),
    - arbitrary host names    
    - HTTP  
    - HTTPS -- use my CertScriptTool to help make a cert for that: http://github.com/fearthecowboy/CertScriptTool 
   
### Nifty Feature Of the Week
   
   This webserver script watches itself to see if it's modified and restarts 
   itself when it detects a new version. This makes it really easy to launch 
   the webserver, then open this script in an editor, and make changes that
   take effect immediately upon saving.
   
### Second Nifty Feature

   The script has a place to cherry-pick a URL if you want to send something 
   specific -- look for the comment: 
       # handle a few paths manually
   and add your own custom responses.
   
    Default custom responses:
    
    http://localhost/about -- shows an about page
    http://localhost/restart -- restarts the webserver script
    http://localhost/quit -- stops the webserver script

#### EXAMPLE

``` powershell
    PS c:\ > WebServer.ps1 
    # starts a simple webserver, hosting files from the current directory on 
    # http://*:80 and https://*:443 
```

#### EXAMPLE

``` powershell
    PS c:\ > WebServer.ps1 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # http://*:80 and https://*:443 
```
   
#### EXAMPLE

``` powershell
    PS c:\ > WebServer.ps1 -http 80,8080 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # http://*:80 and http://*:8080
```    
    
#### EXAMPLE

``` powershell    
    PS c:\ > WebServer.ps1 -https 443 -root c:\
    # starts a webserver, hosting files from the c:\ directory on 
    # https://*:443 (secure only)
```

#### PARAMETER `Root`
  The folder from which to serve files from. Defaults to $PWD
  
#### PARAMETER `Hosts`
  The list of host names or ip addresses to listen on. Defaults to '*' (meaning all)
  
#### PARAMETER `Https`
  The HTTPS (SSL) ports to listen on (a cert must be bound on the port for that to work!)
  
  If either Https or Http are speficied, it will *only* use what's specified.

#### PARAMETER `Http`
  The HTTP ports to listen on.
  
  If either Https or Http are speficied, it will *only* use what's specified.
  
#### PARAMETER `NoFolderListing`
  Specifiyng this will disable folder browsing.