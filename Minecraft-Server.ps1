<#
.SYNOPSIS
  Download and optionally start a Minecraft server.

.DESCRIPTION
  This script allows you to download and optionally start a Minecraft server. 
  You can choose the server type (Mojang, Fabric, or PaperMC), specify the version, 
  and manage the server folder. You also have the option to automatically accept 
  the EULA and restart the server if needed.

.PARAMETER Type
  Specifies the type of Minecraft server to download. 
  Default: Mojang
  Values: [Mojang, Fabric, PaperMC]
  - Mojang: Uses the Mojang API to download the Minecraft server jar.
    Source: https://launchermeta.mojang.com/mc/game/version_manifest.json
  - PaperMC: Downloads the server jar from the PaperMC API.
    Source: https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/77/downloads/paper-1.21.1-77.jar
  - Fabric: Downloads the server jar from the Fabric API.
    Source: https://meta.fabricmc.net/v2/versions/loader/1.21.1/0.16.5/1.0.1/server/jar

.PARAMETER Version
  Specifies the Minecraft version to download.
  Default: latest
  Accepts a string representing the Minecraft version or keywords such as [latest, latestSnapshot].
  Example values: 1.21.10, 24w37a
  Auto-complete is available based on $Type using their respective APIs.

.PARAMETER Name
  Have the Server Folder be "$env:MinecraftServersRoot\Minecraft-$Version-Server-$Name\"
  Enables the use of environment variable $env:MinecraftServersRoot
  Overrides -Folder and -JarsFolder options
  Default: $null

.PARAMETER Start
  Automatically start the server after creating it

.PARAMETER AcceptEULA
  Automatically accept the EULA.
  May have to start the server to generate eula.txt

.PARAMETER SkipShowSettings
  Skip the show settings table print

.PARAMETER Folder
  Server Folder
  Default: Minecraft-$Version-Server

.PARAMETER JarsFolder
  Folder where server jars are placed
  Default: $Folder or if $Name is provided $env:MinecraftServersRoot\Jars\

.PARAMETER DuckDNSSubDomain
  If given, Updates the IPAddress of $DuckDNSSubDomain.duckdns.org to your current public ip address
  Uses environment variable DuckDNSToken for authentication. Get your token from https://duckdns.org
  
.PARAMETER InitialHeapSize
  Passes -Xms$InitialHeapSize to java
  
.PARAMETER MaxHeapSize
  Passes -Xms$MaxHeapSize to java

.Example
  # Start a Mojang server on the latest minecraft version in folder .\Minecraft-$Version-Server\
  Minecraft-Server -Start -AcceptEULA

.Example
  # Start a Mojang server on the latest minecraft version in folder .\$env:MinecraftServersRoot\Minecraft-$Version-Server-ExampleServerName\
  Minecraft-Server -Start -AcceptEULA -Name ExampleServerName

.Example
  # Start a Mojang server on the latest minecraft version in folder .\ExampleServerName\
  Minecraft-Server -Start -AcceptEULA -Folder ExampleServerName
#>

param(
  [ValidateSet("Mojang", "PaperMC", "Fabric")]
  [string]$Type = "Mojang",
  [ArgumentCompleter({
      param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
      [string]$serverType = $fakeBoundParameters["ServerType"]
      $versions = @()
      try {
        switch ($serverType) {
          "Mojang" { $versions = (Invoke-RestMethod "https://launchermeta.mojang.com/mc/game/version_manifest.json").versions.id }
          "PaperMC" { $versions = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper").versions ; [Array]::Reverse($versions) }
          "Fabric" { $versions = (Invoke-RestMethod "https://meta.fabricmc.net/v2/versions").game.version }
        }
      }
      catch {
        Write-Warning "Failed to retrieve versions for $serverType : $_"
      }
      $versions = $versions + "latest"
      $versions = $versions + "latestSnapshot"
      $versions = $versions | Where-Object { $_ -like "$wordToComplete*" }
      return $versions
    })]
  [string]$Version = "latest",
  [string]$Name = $null,
  [switch]$Start,
  [switch]$AcceptEULA,
  [switch]$SkipShowSettings,
  [string]$Folder = $null,
  [string]$JarsFolder = $null,
  [ValidatePattern('^[0-9a-zA-z-]+$')]
  [string]$DuckDNSSubDomain = $null,
  [ValidatePattern('^\d+[kKmMgG]$')]
  [string]$InitialHeapSize = $null,
  [ValidatePattern('^\d+[kKmMgG]$')]
  [string]$MaxHeapSize = $null
)

$MinecraftServersRoot = & {
  if (-not $Name) { return $null }
  $MinecraftServersRoot = $env:MinecraftServersRoot
  while (-not [System.IO.Path]::IsPathRooted($MinecraftServersRoot)) {
    $MinecraftServersRoot = Read-Host @"
Environment variable MinecraftServersRoot=`"$MinecraftServersRoot`" is not valid.
Please Enter a Rooted Path for MinecraftServersRoot
"@
  }
  if (-not (Test-Path $MinecraftServersRoot)) {
    New-Item -Path $MinecraftServersRoot -ItemType Directory -Force | Out-Null
  }
  $MinecraftServersRoot = Resolve-Path $MinecraftServersRoot
  if ($env:MinecraftServersRoot -ne "$MinecraftServersRoot") {
    $env:MinecraftServersRoot = "$MinecraftServersRoot"
    [System.Environment]::SetEnvironmentVariable("MinecraftServersRoot", $env:MinecraftServersRoot, "User")
    Write-Host "Updated environment variable MinecraftServersRoot=`"$env:MinecraftServersRoot`""
  }
  return $MinecraftServersRoot
}

$Folder = & {
  if ($Name) {
    $Folder = "$MinecraftServersRoot\Minecraft-$Version-Server-$Name"
  }
  if (-not $Folder) {
    $Folder = "Minecraft-$Version-Server"
  }
  if (-not (Test-Path $Folder)) {
    New-Item -Path $Folder -ItemType Directory -Force | Out-Null
  }
  return Resolve-Path $Folder
}

$JarsFolder = & {
  if ($Name) {
    $JarsFolder = "$MinecraftServersRoot\Jars"
  }
  if (-not $JarsFolder) {
    $JarsFolder = $Folder
  }
  if (-not (Test-Path $JarsFolder)) {
    New-Item -Path $JarsFolder -ItemType Directory -Force | Out-Null
  }
  return Resolve-Path $JarsFolder
}

$Type, $Version, $versionPreResolve, $url, $jarName = & {
  $versionPreResolve = $Version
  switch ($Type) {
    "Mojang" {
      $versionManifest = Invoke-RestMethod "https://launchermeta.mojang.com/mc/game/version_manifest.json"
      switch ($Version) {
        "latest" <#   #> { $Version = $versionManifest.latest.release }
        "latestSnapshot" { $Version = $versionManifest.latest.snapshot }
      }
      $versionInfo = $versionManifest.versions | Where-Object { $_.id -eq $Version } | Select-Object -First 1
      $versionInfo = Invoke-RestMethod $versionInfo.url
      $url = $versionInfo.downloads.server.url
      $jarName = "minecraft-$Version-server.jar"
    }
    "PaperMC" {
      switch ($Version) {
        "latest" <#   #> { $Version = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper").versions[-1] }
        "latestSnapshot" { $Version = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper").versions[-1] }
      }
      $build = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper/versions/$Version").builds[-1]
      $url = "https://api.papermc.io/v2/projects/paper/versions/$Version/builds/$build/downloads/paper-$Version-$build.jar"
      $jarName = "paper-$Version-$build.jar"
    }
    "Fabric" {
      $fabricVersions = Invoke-RestMethod "https://meta.fabricmc.net/v2/versions"
      switch ($Version) {
        "latest" <#   #> { $Version = $fabricVersions.game.version | Where-Object { $_ -match "\d+\.\d+.*" } | Select-Object -First 1 }
        "latestSnapshot" { $Version = $fabricVersions.game.version | Where-Object { $_ -match "\d+w.*" } | Select-Object -First 1 }
      }
      $loader, $launcher = $fabricVersions.loader.version[0], $fabricVersions.installer.version[0]
      $url = "https://meta.fabricmc.net/v2/versions/loader/$Version/$loader/$launcher/server/jar"
      $jarName = "fabric-server-mc.$Version-loader.$loader-launcher.$launcher.jar"
    }
  }
  return $Type, $Version, $versionPreResolve, $url, $jarName
}

$jarPath = & {
  $jarPath = "$JarsFolder\$jarName"
  if (-not(Test-Path $jarPath)) {
    try {
      Write-Host "Starting download of $jarPath"
      Invoke-WebRequest -Uri $url -OutFile $jarPath
    }
    catch {
      Write-Error "Failed to download file from $url : $_"
      throw $_
    }
  }
  return Resolve-Path $jarPath
}

$serverCommand = & {
  $javaArgs = @(
    if ("$InitialHeapSize" <#    #> -match '^\d+[kKmMgG]+$') { "-Xms$InitialHeapSize" }
    if ("$MaxHeapSize" <#        #> -match '^\d+[kKmMgG]+$') { "-Xmx$MaxHeapSize" }
    "-jar"
    "$jarPath"
    "nogui"
  )
  $javaCommand = "java $($javaArgs -join ' ')"
  $javaCommand | Set-Content "$Folder\start.ps1"
  $FolderCaptured = $Folder
  return {
    Write-Host "$FolderCaptured> $javaCommand"
    $proc = Start-Process `
      -FilePath java `
      -ArgumentList $javaArgs `
      -WorkingDirectory $FolderCaptured `
      -NoNewWindow `
      -PassThru
    $proc.WaitForExit()
    if ($proc.ExitCode) { throw "java exited with code $($proc.ExitCode)" }
  }.GetNewClosure()
}

if ($AcceptEULA) {
  $eulaPath = "$Folder\eula.txt"
  if (-not(Test-Path $eulaPath)) {
    Write-Host "Starting Server Once To generate eula.txt"
    & $serverCommand # should exit automatically
  }
  $eulaContent = Get-Content $eulaPath -Raw
  if ($eulaContent -match "eula=true") {
    Write-Host "EULA was already accepted"
  }
  elseif ($eulaContent -notmatch "eula=false") {
    Write-Error "eula content does not contain valid `"eula=false`" line to replace"
  }
  else {
    $eulaContent = $eulaContent -replace "eula=false", "eula=true"
    $eulaContent | Set-Content $eulaPath
    Write-Host "```````n$eulaContent`n``````"
    Write-Host "EULA has been accepted"
  } 
}

$DuckDNSDomain = & {
  if (-not $DuckDNSSubDomain) { return }
  $DuckDNSDomain = "$DuckDNSSubDomain.duckdns.org"
  $DuckDNSToken = "$env:DuckDNSToken"
  while ($DuckDNSToken -notmatch "^[0-9a-f]{8}\-[0-9a-f]{4}\-4[0-9a-f]{3}\-[89ab][0-9a-f]{3}\-[0-9a-f]{12}$") {
    $DuckDNSToken = Read-Host @"
Environment variable DuckDNSToken is invalid or does not exist.
Get a token from https://duckdns.org and enter it here.
Please enter your token
"@
  }
  if ("$env:DuckDNSToken" -ne $DuckDNSToken) {
    $env:DuckDNSToken = $DuckDNSToken
    [System.Environment]::SetEnvironmentVariable("DuckDNSToken", $env:DuckDNSToken, "User")
    Write-Host "Updated environment variable DuckDNSToken"
  }
  $DuckDNSToken = $null
  Write-Host @"
Updating $DuckDNSDomain
Ensure that https://duckdns.org contains $DuckDNSSubDomain subdomain
"@
  Invoke-RestMethod "https://www.duckdns.org/update?domains=$DuckDNSSubDomain&token=$env:DuckDNSToken&verbose" | Write-Host
  return $DuckDNSDomain
}

if (-not $SkipShowSetting) {
  "Settings Used:" | Write-Host
  @"
Option             , Value
Type               , $Type
Version            , $versionPreResolve
Version (Resolved) , $Version
Name               , $Name
Start              , $Start
AcceptEULA         , $AcceptEULA
SkipShowSetting    , $SkipShowSetting
Folder             , $Folder
JarsFolder         , $JarsFolder
InitialHeapSize    , $InitialHeapSize
MaxHeapSize        , $MaxHeapSize
DuckDNSDomain      , $DuckDNSDomain
"@ -replace '\s+,', ',' | ConvertFrom-Csv | Format-Table -AutoSize
}

if ($Start) { & $serverCommand }