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
    $characters += Import-CharacterFromJson -Path "$PSScriptRoot\media\characters\hero\character.json"
}

# Load backgrounds
$background = Read-ImageIntoPixelArray -ImagePath "$PSScriptRoot\media\backgrounds\Pallet.bmp"
$backgroundHitmap = Read-ImageIntoPixelArray -ImagePath "$PSScriptRoot\media\backgrounds\PalletHitmap.bmp"

# Count the frames so we can feed this into animations to select the correct frame e.g. ($global:Frames % 2) equals walking1, then walking2, then walking1, etc.
$global:Frames = 0
# Remember when we started so we can calculate the framerate
$start = Get-Date
# Tile size should be something that is always evenly divisible by 2, 16 is what a lot of old gameboy games used
$tileSize = 16
# Half tile size is frequently required to centre the character and other objects on the tile edge so it's precalculated here
$halfTileSize = [int]($tileSize / 2)
# Background is a 2D array, width can be determined by the length of the first row
$backgroundWidth = $background[0].Count
# Background is a 2D array, height can be determined by the length of the array
$backgroundHeight = $background.Count
# Standard width because pixels are represented by 1 character horizontally
$terminalWidth = $Host.UI.RawUI.WindowSize.Width
# Double height to account for half-height characters representing pixels vertically, minus 2 for the prompt
$terminalHeight = $Host.UI.RawUI.WindowSize.Height * 2 - 2
# Set the initial map position this should be provided by the map in the future
$mapOffsetX = [int]($backgroundWidth / 2) - [int]($terminalWidth / 2)
$mapOffsetY = [int]($backgroundHeight / 2) - [int]($terminalHeight / 2)
# Set the character to the centre of the map position, the initial character position should be provided by the map in the future
$mainCharacter = $characters | Where-Object { $_.CameraFocus } | Select-Object -First 1
$mainCharacter.Source = $mainCharacter.Destination = @{
    X = [int]($mapOffsetX + $halfTileSize + 4)
    Y = [int]($mapOffsetY - $halfTileSize)
}

# Clear the terminal, this is required to remove the prompt. I tried using the alternative buffer but it seemed to not respect a bunch of escape codes I was using.
Clear-Host
while($true) {

    # Update character position
    if($mainCharacter.Source.X -ne $mainCharacter.Destination.X -or $mainCharacter.Source.Y -ne $mainCharacter.Destination.Y) {
        if($mainCharacter.Source.X -ne $mainCharacter.Destination.X) {
            $mainCharacter.Source.X += [Math]::Sign($mainCharacter.Destination.X - $mainCharacter.Source.X)
        }
        if($mainCharacter.Source.Y -ne $mainCharacter.Destination.Y) {
            $mainCharacter.Source.Y += [Math]::Sign($mainCharacter.Destination.Y - $mainCharacter.Source.Y)
        }
        $mainCharacter.IsMoving = $true
    } else {
        $mainCharacter.IsMoving = $false
    }

    # Get the last input the user provided. The while loop is required because the console buffer can contain multiple keys and you only want the most recent direction.
    $lastKey = $null
    while([Console]::KeyAvailable) {
        $lastKey = [Console]::ReadKey($true)
    }

    # Handle the last key pressed
    if(-not $mainCharacter.IsMoving) {
        switch($lastKey.Key) {
            "UpArrow" {
                $mainCharacter.Direction = "Up"
                $mainCharacter.Destination = @{
                    X = $mainCharacter.Source.X
                    Y = $mainCharacter.Source.Y - $tileSize
                }
            }
            "DownArrow" {
                $mainCharacter.Direction = "Down"
                $mainCharacter.Destination = @{
                    X = $mainCharacter.Source.X
                    Y = $mainCharacter.Source.Y + $tileSize
                }
            }
            "LeftArrow" {
                $mainCharacter.Direction = "Left"
                $mainCharacter.Destination = @{
                    X = $mainCharacter.Source.X - $tileSize
                    Y = $mainCharacter.Source.Y
                }
            }
            "RightArrow" {
                $mainCharacter.Direction = "Right"
                $mainCharacter.Destination = @{
                    X = $mainCharacter.Source.X + $tileSize
                    Y = $mainCharacter.Source.Y
                }
            }
        }
        $mainCharacter.IsMoving = $true
    }

    # Render the frame
    Write-TiledFrame -Background $background -BackgroundHitmap $backgroundHitmap -Characters $characters -Width $terminalWidth -Height $terminalHeight -HalfTileSize $halfTileSize

    # Write debug information at the top of the terminal like framerate
    $frameRate = [int](($global:Frames / ((Get-Date) - $start).TotalSeconds))
    [Console]::Write("`e[HFrames rendered = $global:Frames, Framerate = $frameRate FPS, Char X = $($mainCharacter.Source.X), Char Y = $($mainCharacter.Source.Y), Char Direction = $($mainCharacter.Direction), Char Moving = $($mainCharacter.IsMoving)$(" " * [math]::Min(0, ($width - $logLine.Length)))")
    $global:Frames++
}

$frameRate = [Math]::Round(($global:Frames / ((Get-Date) - $start).TotalSeconds), 2)
Write-Host "Frames rendered = $global:Frames, Framerate = $frameRate fps"