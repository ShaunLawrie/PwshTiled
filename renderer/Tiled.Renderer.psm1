$script:HalfBlock = [Char]0x2584

# Test character collision, this needs some kind of space partitioning e.g. character is in top left quadrant of map so only check characters in that quadrant
function Get-CharacterPixel ([array] $Characters, [int] $X, [int] $Y) {
    foreach($character in $Characters) {
        # Check for collision with a character
        if($X -ge $character.Source.X -and $X -lt $character.Source.X + $character.Width -and $Y -ge $character.Source.Y -and $Y -lt $character.Source.Y + $character.Height) {
            # Get the current frame for the character
            $characterDirection = $character.Direction
            $characterDirectionFrameCount = $character.Sprites.Directional.$characterDirection.Count
            # Check if character is moving
            $characterDirectionFrame = $character.Sprites.Directional.$characterDirection[0]
            if($character.Source.X -ne $character.Destination.X -or $character.Source.Y -ne $character.Destination.Y) {
                # Get the frame for the direction the character is moving in
                $characterDirectionFrame = $character.Sprites.Directional.$characterDirection[($global:Frames % $characterDirectionFrameCount)]
            }
            # Check if character pixel is opaque
            $characterPixel = $characterDirectionFrame[$Y - $character.Source.Y][$X - $character.Source.X]
            if($characterPixel.A -gt 0) {
                return $characterPixel
            }
        }
    }
    return $null
}

# Trying positional parameters to remove parameter parsing overhead. This probably isn't required.
function Write-TiledFrame ([object] $Background, [object] $BackgroundHitmap, [array] $Characters, [int] $Width, [int] $Height, [int] $HalfTileSize) {

    # Get position of the main character
    $mainCharacter = $Characters | Where-Object { $_.CameraFocus } | Select-Object -First 1

    # Get the offset of the map based on the main character position
    $mapOffsetX = [int]($mainCharacter.Source.X + $HalfTileSize - ($Width / 2))
    $mapOffsetY = [int]($mainCharacter.Source.Y + $HalfTileSize - ($Height / 2))

    $imageString = [System.Text.StringBuilder]::new()
    $null = $imageString.Append("`e[?25l`e[2;0H")
    
    # Parse the image 2 vertical pixels at a time and use the lower half block character with varying foreground and background colors to make it appear as two pixels within one character space
    for($y = 0; $y -lt $Height; $y += 2) {
        for($x = 0; $x -lt $Width; $x++) {
            # Check if a character is placed in the lower half of the current character space
            $pixelBelow = Get-CharacterPixel -Characters $Characters -Y ($y + $mapOffsetY + 1) -X ($x + $mapOffsetX)
            # Fill with the background if there was no character pixel
            if(-not $pixelBelow) {
                $pixelBelow = $Background[($y + $mapOffsetY + 1)][$x + $mapOffsetX]
                if($pixelBelow.A -eq 0) {
                    # Get image from background layer below this transparent one
                    throw "Transparent background pixels are not implemented"
                }
            }

            # Check if a character is placed in the lower half of the current character space
            $currentPixel = Get-CharacterPixel -Characters $Characters -Y ($y + $mapOffsetY) -X ($x + $mapOffsetX)
            # Fill with the background if there was no character pixel
            if(-not $currentPixel) {
                $currentPixel = $Background[$y + $mapOffsetY][$x + $mapOffsetX]
                if($currentPixel.A -eq 0) {
                    # Get image from background layer below this transparent one
                    throw "Transparent background pixels are not implemented"
                }
            }

            $null = $imageString.Append(("`e[38;2;{0};{1};{2}m`e[48;2;{3};{4};{5}m$script:HalfBlock`e[0m" -f $pixelBelow.R, $pixelBelow.G, $pixelBelow.B, $currentPixel.R, $currentPixel.G, $currentPixel.B))
        }
    }
    
    [Console]::Write($imageString.ToString())
}