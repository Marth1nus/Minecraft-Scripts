# Create and Run a Minecraft Server on Windows

## Define the `Minecraft-Server` function in your powershell session

```Powershell
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex
Get-Help Minecraft-Server
```

## Use the script file

Download [Minecraft-Server.ps1](https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server.ps1) script (not signed) directly

## Start a default server with a one-liner :

```Powershell
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex ; Minecraft-Server -Start -AcceptEULA
```

## Examples

```PowerShell
# Download and define the Minecraft-Server function
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex

# Start latest release version of minecraft Mojang server
Minecraft-Server -Start -AcceptEULA

# Start latest snapshot release version of minecraft Mojang server
Minecraft-Server -Start -AcceptEULA -Version latestSnapshot

# Start a latest Fabric Modded server
Minecraft-Server -Start -AcceptEULA -Type Fabric

# Start a latest Paper server
Minecraft-Server -Start -AcceptEULA -Type PaperMC

# Start specific version
Minecraft-Server -Start -AcceptEULA -Version 1.8

# Start a server using environment variable root folder
# You can set the environment variables in settings
# For now we set it for the current session only
$env:MinecraftServersRoot = "~/Documents/Minecraft/Servers/"
Minecraft-Server -Start -AcceptEULA -Name AAA
# This starts a server in "~/Documents/Minecraft/Servers/Minecraft-latest-Server-AAA/"

# See The options available
Get-Help Minecraft-Server -Full
```
