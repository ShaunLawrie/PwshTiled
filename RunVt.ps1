# Run a tiled game rendererer using virtual terminal escape codes
$ErrorActionPreference = "Stop"

# Load c# libs that do a lot of the file parsing work for us
Add-Type -Path "$PSScriptRoot\renderer\packages\SixLabors.ImageSharp\lib\netstandard2.0\SixLabors.ImageSharp.dll"
foreach($module in (Get-ChildItem -Filter "*.psm1" -Path "$PSScriptRoot" -Recurse)) {
    Import-Module -Name $module.FullName -Force
}

# Load characters
$characters = @()
foreach($characterDataFile in (Get-ChildItem -Filter "character.json" -Path "$PSScriptRoot" -Recurse)) {
    $characters += Import-CharacterFromJson -Path $characterDataFile.FullName
}

# Load maps
$maps = @()
foreach($mapDataFile in (Get-ChildItem -Filter "map.json" -Path "$PSScriptRoot" -Recurse)) {
    $maps += Import-MapFromJson -Path $mapDataFile.FullName
}

# Count the frames so we can feed this into animations to select the correct frame e.g. ($global:Frames % 2) equals walking1, then walking2, then walking1, etc.
$global:Frames = 0
# Remember when we started so we can calculate the framerate
$start = Get-Date
# Tile size should be something that is always evenly divisible by 2, 16 is what a lot of old gameboy games used
$tileSize = 16
# Half tile size is frequently required to centre the character and other objects on the tile edge so it's precalculated here
$halfTileSize = [int]($tileSize / 2)
# Standard width because pixels are represented by 1 character horizontally
$terminalWidth = $Host.UI.RawUI.WindowSize.Width
# Double height to account for half-height characters representing pixels vertically, minus 2 for the prompt
$terminalHeight = $Host.UI.RawUI.WindowSize.Height * 2 - 2
# Set the start map
$currentMap = $maps | Where-Object { $_.Name -eq "Pallet" }
# Get the initial character position
$currentPosition = $currentMap `
    | Select-Object -ExpandProperty "Portals" `
    | Where-Object { $_.Name -eq $currentMap.CharacterDefaultEntryPosition } `
    | Select-Object -First 1
# Set the character to the default entrypoint of the map
$mainCharacter = $characters | Where-Object { $_.CameraFocus } | Select-Object -First 1
$mainCharacter.Source = $mainCharacter.Destination = $currentPosition.Exit | Select-Object -Property "X", "Y"
$mainCharacter.Direction = $currentPosition.ExitDirection
$mainCharacter.LastPortal = $currentPosition.Name
# Movement factor is used to increase or decrease the speed of the character
$movementFactor = 2

# Clear the terminal, this is required to remove the prompt. I tried using the alternative buffer but it seemed to not respect a bunch of escape codes I was using.
Clear-Host
while($true) {
    # Update character position
    if($mainCharacter.Source.X -ne $mainCharacter.Destination.X -or $mainCharacter.Source.Y -ne $mainCharacter.Destination.Y) {
        if($mainCharacter.Source.X -ne $mainCharacter.Destination.X) {
            $mainCharacter.Source.X += [Math]::Sign($mainCharacter.Destination.X - $mainCharacter.Source.X) * $movementFactor
        }
        if($mainCharacter.Source.Y -ne $mainCharacter.Destination.Y) {
            $mainCharacter.Source.Y += [Math]::Sign($mainCharacter.Destination.Y - $mainCharacter.Source.Y) * $movementFactor
        }
        $mainCharacter.IsMoving = $true
    } else {
        $mainCharacter.IsMoving = $false
        $movementFactor = 2
    }

    # Get the last input the user provided. The while loop is required because the console buffer can contain multiple keys and you only want the most recent direction.
    $lastKey = $null
    while([Console]::KeyAvailable) {
        $lastKey = [Console]::ReadKey($true)
    }

    # Handle the last key pressed
    if(-not $mainCharacter.IsMoving) {
        $targetDestination = $null
        switch($lastKey.Key) {
            "UpArrow" {
                $mainCharacter.Direction = "Up"
                $targetDestination = @{
                    X = $mainCharacter.Source.X
                    Y = $mainCharacter.Source.Y - $tileSize
                }
            }
            "DownArrow" {
                $mainCharacter.Direction = "Down"
                $targetDestination = @{
                    X = $mainCharacter.Source.X
                    Y = $mainCharacter.Source.Y + $tileSize
                }
            }
            "LeftArrow" {
                $mainCharacter.Direction = "Left"
                $targetDestination = @{
                    X = $mainCharacter.Source.X - $tileSize
                    Y = $mainCharacter.Source.Y
                }
            }
            "RightArrow" {
                $mainCharacter.Direction = "Right"
                $targetDestination = @{
                    X = $mainCharacter.Source.X + $tileSize
                    Y = $mainCharacter.Source.Y
                }
            }
        }
        if($null -ne $targetDestination -and -not (Test-HitmapCollision -Destination $targetDestination -Hitmap $currentMap.Hitmap)) {
            if($lastKey.Modifiers -contains "Shift") {
                $movementFactor = 8
            }
            $mainCharacter.Destination = $targetDestination
            $mainCharacter.IsMoving = $true
        }
    }

    # Render the frame
    Write-TiledFrame -Map $currentMap -Characters $characters -Width $terminalWidth -Height $terminalHeight -HalfTileSize $halfTileSize

    # Check if the character is at a portal
    if($mainCharacter.IsMoving -eq $false) {
        $portal = $currentMap.Portals | Where-Object {
            foreach($entry in $_.Entries) {
                if($entry.X -eq $mainCharacter.Source.X -and $entry.Y -eq $mainCharacter.Source.Y) {
                    return $true
                }
            }
        }
        if($portal -and $mainCharacter.LastPortal -ne $portal.Name) {
            # Get the map the portal leads to
            $currentMap = $maps | Where-Object { $_.Name -eq $portal.EntryDestination }
            # Get the position the portal leads to
            $currentPosition = $currentMap `
                | Select-Object -ExpandProperty "Portals" `
                | Where-Object { $_.Name -eq $portal.EntryDestinationPortal } `
                | Select-Object -First 1
            # Set the character to the default entrypoint of the map
            $mainCharacter.Source = $mainCharacter.Destination = $currentPosition.Exit | Select-Object -Property "X", "Y"
            $mainCharacter.Direction = $currentPosition.ExitDirection
            $mainCharacter.LastPortal = $currentPosition.Name
            Write-FadeOut
            # Wipe all input so the character doesn't keep walking on the new map
            while([Console]::KeyAvailable) {
                $null = [Console]::ReadKey($true)
            }
        } else {
            $mainCharacter.LastPortal = $portal.Name
        }
    }

    # Write debug information at the top of the terminal like framerate
    $frameRate = [int](($global:Frames / ((Get-Date) - $start).TotalSeconds))
    $logLine = "Frames rendered = $global:Frames, Framerate = $frameRate FPS, Char X = $($mainCharacter.Source.X), Char Y = $($mainCharacter.Source.Y)$global:MapOffset"
    [Console]::Write("`e[H$logLine$(" " * [math]::Max(0, ($terminalWidth - $logLine.Length)))")
    $global:Frames++
}

$frameRate = [Math]::Round(($global:Frames / ((Get-Date) - $start).TotalSeconds), 2)
Write-Host "Frames rendered = $global:Frames, Framerate = $frameRate fps"