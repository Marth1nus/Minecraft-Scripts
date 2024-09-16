# Create and Run a Minecraft Server on Windows

## Define the `Minecraft-Server` function in your powershell session

```Powershell
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex
Get-Help Minecraft-Server
```

## Use the script file

Download [Minecraft-Server.ps1](https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server.ps1) script (not signed) directly

## Start a default server with no hassle

Download [Minecraft-Server.bat](https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server.bat)

## Start a default server with a one-liner :

```Powershell
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex ; Minecraft-Server -StartServer -AcceptEULA
```

## Example

```PowerShell
# Download and define the Minecraft-Server function
irm "https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server" | iex

# Start latest release version of minecraft Mojang server
Minecraft-Server -StartServer -AcceptEULA

# Start latest snapshot release version of minecraft Mojang server
Minecraft-Server -StartServer -AcceptEULA -Version latestSnapshot

# Start a latest Fabric Modded server
Minecraft-Server -StartServer -AcceptEULA -ServerType Fabric

# Start a latest Paper server
Minecraft-Server -StartServer -AcceptEULA -ServerType PaperMC

# Start specific version
Minecraft-Server -StartServer -AcceptEULA -Version 1.8

# See The options available
Get-Help Minecraft-Server -Full

# Use ./server/start.bat to start the server again in the future
cd .\server
.\start.bat
```
