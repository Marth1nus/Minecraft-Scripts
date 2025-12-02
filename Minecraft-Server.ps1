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
    Auto-complete is available based on -Type using their respective APIs.

.PARAMETER Start
    Automatically start the server after creating it

.PARAMETER Name
    Specifies the Name that may be used to set the server folder 
    Default: null

.PARAMETER Folder
    Specifies the folder where the server will be started, used only when -StartServer is provided.
    Default: "Minecraft-$Version-Server-$Name"

.PARAMETER JarsFolder
    Specifies the location where server jar files will be downloaded.
    Default: -Folder or "env:MinecraftServersRoot\Jars\"

.PARAMETER AcceptEULA
    Automatically accept the EULA.
    May have to start the server to generate eula.txt

.PARAMETER IgnoreEnvMinecraftServersRoot
    Tells program to ignore $env:MinecraftServersRoot if it exists

.EXAMPLE
    Minecraft-Server -Start -AcceptEULA
    Starts a default Minecraft server with the latest version and automatically accepts the EULA.
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
  [switch]$Start,
  [string]$Name = $null,
  [string]$Folder = $null,
  [string]$JarsFolder = $null,
  [string]$HeapSize = $null,
  [string]$MaxHeapSize = $null,
  [switch]$AcceptEULA,
  [switch]$IgnoreEnvMinecraftServersRoot
)

$UseEnvMinecraftServersRoot = (
  -not $IgnoreEnvMinecraftServersRoot -and
  (Test-Path $env:MinecraftServersRoot) -and
  ([System.IO.Path]::IsPathRooted($env:MinecraftServersRoot))
)

$Folder = & {
  if (-not $Folder) {
    $Folder = "Minecraft-$Version-Server"
  }
  if ($UseEnvMinecraftServersRoot) {
    $Folder = Join-Path $env:MinecraftServersRoot ($Folder ?? "")
  }
  if ($Name) {
    $Folder = "$Folder-$Name"
  }
  if (-not (Test-Path $Folder)) {
    New-Item -Path $Folder -ItemType Directory -Force -ErrorAction Stop
  }
  return Resolve-Path $Folder
}

$JarsFolder = & {
  if (-not $JarsFolder -and $UseEnvMinecraftServersRoot) {
    $JarsFolder = Join-Path $env:MinecraftServersRoot "Jars"
  }
  if (-not $JarsFolder) {
    $JarsFolder = $Folder
  }
  if (-not (Test-Path $JarsFolder)) {
    New-Item -Path $JarsFolder -ItemType Directory -Force -ErrorAction Stop
  }
  return Resolve-Path $JarsFolder
}

$url, $jarName = & { # ServerType and Version resolved here
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
  return $url, $jarName
}

$jarPath = & {
  $jarPath = Join-Path $JarsFolder $jarName
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
    if ($HeapSize <#    #> -and $HeapSize <#    #> -match '\S+') { "-Xms$HeapSize" }
    if ($MaxHeapSize <# #> -and $MaxHeapSize <# #> -match '\S+') { "-Xmx$MaxHeapSize" }
    "-jar"
    "$jarPath"
    "nogui"
  )
  $javaCommand = "java $($javaArgs -join ' ')"
  $javaCommand | Write-Host
  $javaCommand | Set-Content (Join-Path $Folder "start.ps1")
  $FolderCaptured = $Folder
  return { 
    (Start-Process -FilePath java -ArgumentList $javaArgs -WorkingDirectory $FolderCaptured -NoNewWindow -PassThru).WaitForExit()
  }.GetNewClosure()
}

if ($AcceptEULA) {
  Write-Host "Accepting EULA"
  if (Test-Path "$Folder/eula.txt") {
    Write-Host "eula.txt exists"
  }
  else {
    Write-Host "Starting Server Once To generate eula.txt"
    & $serverCommand # should exit automatically
  }
  $eulaPath = Join-Path $Folder "eula.txt"
  $eulaContent = Get-Content $eulaPath -Raw
  if ($eulaContent -match "eula=true") {
    Write-Host "EULA was already accepted"
  }
  else {
    $eulaContent = $eulaContent -replace "eula=false", "eula=true"
    $eulaContent | Set-Content $eulaPath -ErrorAction Stop
    $eulaContent | Write-Host
    Write-Host "EULA has been accepted"
  }
}

if ($Start) {
  & $serverCommand
}