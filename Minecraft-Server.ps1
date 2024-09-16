<#
.SYNOPSIS
    Download and optionally start a Minecraft server.

.DESCRIPTION
    This script allows you to download and optionally start a Minecraft server. 
    You can choose the server type (Mojang, Fabric, or PaperMC), specify the version, 
    and manage the server folder. You also have the option to automatically accept 
    the EULA and restart the server if needed.

.PARAMETER ServerType
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
    Example values: 1.21.1, 24w37a
    Auto-complete is available based on ServerType using their respective APIs.

.PARAMETER Folder
    Specifies the location where server jar files will be downloaded.
    Default: -ServerFolder

.PARAMETER StartServer
    When specified, the script will not only download the server jar but also create and start a Minecraft server in the specified -ServerFolder.

.PARAMETER ServerFolder
    Specifies the folder where the server will be started, used only when -StartServer is provided.
    Default: server

.PARAMETER AcceptEULA
    When -StartServer is specified, this parameter will automatically accept the EULA after the server starts, if needed, and restart the server.

.EXAMPLE
    Minecraft-Server -StartServer -AcceptEULA
    Starts a default Minecraft server with the latest version and automatically accepts the EULA.
#>

param(
  [ValidateSet("Mojang", "PaperMC", "Fabric")]
  [string]$ServerType = "Mojang",
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
  [string]$Folder = $null,
  [string]$ServerFolder = "server",
  [switch]$StartServer,
  [switch]$AcceptEULA
)

if (-not $Folder) {
  $Folder = $ServerFolder
}

if (-not (Test-Path $Folder)) {
  New-Item -Path $Folder -ItemType Directory
}

$url, $filename = "", ""

try {
  switch ($ServerType) {
    "Mojang" {
      $versionManifest = Invoke-RestMethod "https://launchermeta.mojang.com/mc/game/version_manifest.json"
      switch ($Version) {
        "latest" <#   #> { $Version = $versionManifest.latest.release }
        "latestSnapshot" { $Version = $versionManifest.latest.snapshot }
      }
      $versionInfo = $versionManifest.versions | Where-Object { $_.id -eq $Version } | Select-Object -First 1
      $versionInfo = Invoke-RestMethod $versionInfo.url
      $url = $versionInfo.downloads.server.url
      $filename = "minecraft-$Version-server.jar"
    }
    "PaperMC" {
      switch ($Version) {
        "latest" <#   #> { $Version = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper").versions[-1] }
        "latestSnapshot" { $Version = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper").versions[-1] }
      }
      $build = (Invoke-RestMethod "https://api.papermc.io/v2/projects/paper/versions/$Version").builds[-1]
      $url = "https://api.papermc.io/v2/projects/paper/versions/$Version/builds/$build/downloads/paper-$Version-$build.jar"
      $filename = "paper-$Version-$build.jar"
    }
    "Fabric" {
      $fabricVersions = Invoke-RestMethod "https://meta.fabricmc.net/v2/versions"
      switch ($Version) {
        "latest" <#   #> { $Version = $fabricVersions.game.version | Where-Object { $_ -match "\d+\.\d+.*" } | Select-Object -First 1 }
        "latestSnapshot" { $Version = $fabricVersions.game.version | Where-Object { $_ -match "\d+w.*" } | Select-Object -First 1 }
      }
      $loader, $launcher = $fabricVersions.loader.version[0], $fabricVersions.installer.version[0]
      $url = "https://meta.fabricmc.net/v2/versions/loader/$Version/$loader/$launcher/server/jar"
      $filename = "fabric-server-mc.$Version-loader.$loader-launcher.$launcher.jar"
    }
  }
}
catch {
  Write-Error "Failed to retrieve server details: $_"
  return $_
}

$filepath = Join-Path $Folder $filename

if (-not (Test-Path $filepath)) {
  try {
    Write-Output "Starting download of $filepath"
    Invoke-WebRequest -Uri $url -OutFile $filepath
  }
  catch {
    Write-Error "Failed to download file from $url : $_"
    return $_
  }
}

if ($StartServer) {
  Write-Output "Starting Server in $ServerFolder"
  if (-not (Test-Path $ServerFolder)) {
    New-Item -Path $ServerFolder -ItemType Directory
  }
  $jarpath = Resolve-Path -Path $filepath
  Push-Location $ServerFolder
  $jarpath = Resolve-Path -Path $jarpath -Relative
  $jarpath = $jarpath -replace "\\", "/"
  $javaCommand = "java -jar $jarpath nogui"
  $javaCommand | Write-Output
  $javaCommand | Set-Content "start.bat"
  $javaCommand | Set-Content "start.sh"
  $javaCommand | Invoke-Expression
  if ($AcceptEULA -and (Test-Path "eula.txt")) {
    Write-Output "Accepting EULA"
    $eula = Get-Content "eula.txt" -Raw
    if ($eula -match "eula=true") {
      Write-Warning "Eula Already Accepted"
    }
    else { 
      $eula = $eula -replace "eula=false", "eula=true"
      $eula | Write-Output
      $eula | Set-Content "eula.txt"
      $javaCommand | Invoke-Expression
    }
  }
  Pop-Location
}

return $filepath