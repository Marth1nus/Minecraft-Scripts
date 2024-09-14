# Create and Run a Minecraft Server on Windows

Download [Minecraft-Server.ps1](https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server.ps1) script (not signed)

Single line Powershell:

```Powershell
irm "https://marth1nus.github.io/Minecraft-Scripts/Define-Minecraft-Server.ps1" | iex ; Minecraft-Server -StartServer -AcceptEULA
```

or run in `Powershell.exe`

```PowerShell
# Download and define the Minecraft-Server function
irm "https://marth1nus.github.io/Minecraft-Scripts/Define-Minecraft-Server.ps1" | iex

# Use the function to start a default Minecraft server on the latest release version
Minecraft-Server -StartServer -AcceptEULA

# See The options available
Get-Help Minecraft-Server

# Use ./server/start.bat to start the server again in the future
cd .\server
.\start.bat
```

For Newbies who just want a server to run: [Minecraft-Server.bat](https://marth1nus.github.io/Minecraft-Scripts/Minecraft-Server.bat) \
It just bypasses execution policy issues
