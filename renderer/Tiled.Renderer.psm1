$script:HalfBlock = [Char]0x2584

# Test character collision, this needs some kind of space partitioning e.g. character is in top left quadrant of map so only check characters in that quadrant
function Get-CharacterPixels ([array] $Characters, [int] $X, [int] $Y) {
    $characterPixels = @($null, $null)
    foreach($character in $Characters) {
        # Check two pixels at a time for the janky multiple pixels fitting in each vertical character space hack
        for($i = 0; $i -lt 2; $i++) {
            # Check for collision with a character
            if($X -ge $character.Source.X -and $X -lt $character.Source.X + $character.Width -and ($Y + $i) -ge $character.Source.Y -and ($Y + $i) -lt $character.Source.Y + $character.Height) {
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
                $characterPixel = $characterDirectionFrame[($Y + $i) - $character.Source.Y][$X - $character.Source.X]
                if($characterPixel.A -gt 0) {
                    $characterPixels[$i] = $characterPixel
                }
            }   
        }
    }
    return $characterPixels
}

# Trying positional parameters to remove parameter parsing overhead. This probably isn't required.
function Write-TiledFrame ([object] $Map, [array] $Characters, [int] $Width, [int] $Height, [int] $HalfTileSize) {

    # Get position of the main character
    $mainCharacter = $Characters | Where-Object { $_.CameraFocus } | Select-Object -First 1

    # Get the map frame
    $mapFrame = $Map.Frames[(($global:Frames / 2) % $Map.Frames.Count)]

    # Get the offset of the map based on the main character position
    $mapOffsetX = [int][math]::Clamp(($mainCharacter.Source.X + $HalfTileSize - ($Width / 2)), 0, $Map.Width - $Width)
    $mapOffsetY = [int][math]::Clamp(($mainCharacter.Source.Y + $HalfTileSize - ($Height / 2)), 0, $Map.Height - $Height)

    $imageString = [System.Text.StringBuilder]::new()
    $null = $imageString.Append("`e[?25l`e[2;0H")
    
    # Parse the image 2 vertical pixels at a time and use the lower half block character with varying foreground and background colors to make it appear as two pixels within one character space
    for($y = 0; $y -lt $Height; $y += 2) {
        for($x = 0; $x -lt $Width; $x++) {
            # Get character pixels
            $characterPixels = Get-CharacterPixels -Characters $Characters -Y ($y + $mapOffsetY) -X ($x + $mapOffsetX)

            # Check if a character is placed in the lower half of the current character space
            $pixelBelow = $characterPixels[1]
            # Fill with the background if there was no character pixel
            if(-not $pixelBelow) {
                $pixelBelowRow = $mapFrame[($y + $mapOffsetY + 1)]
                if($null -ne $pixelBelowRow) {
                    $pixelBelow = $pixelBelowRow[$x + $mapOffsetX]
                } else {
                    # Sometimes there is no bottom row
                    $pixelBelow = @{
                        R = 0
                        G = 255
                        B = 0
                        A = 255
                    }
                }
                if($pixelBelow.A -eq 0) {
                    # Get image from background layer below this transparent one
                    throw "Transparent background pixels are not implemented"
                }
            }

            # Check if a character is placed in the lower half of the current character space
            $currentPixel = $characterPixels[0]
            # Fill with the background if there was no character pixel
            if(-not $currentPixel) {
                $currentPixelRow = $mapFrame[($y + $mapOffsetY)]
                if($null -ne $currentPixelRow) {
                    $currentPixel = $currentPixelRow[$x + $mapOffsetX]
                } else {
                    # Sometimes there is no bottom row
                    $currentPixel = @{
                        R = 255
                        G = 0
                        B = 0
                        A = 255
                    }
                }
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

function Write-FadeOut {
    $top = 1
    $bottom = $Host.UI.RawUI.BufferSize.Height - 1
    $width = $Host.UI.RawUI.BufferSize.Width
    
    [Console]::CursorVisible = $false

    while($top -le $bottom) {
        [Console]::SetCursorPosition(0, $top)
        Write-Host -ForegroundColor Black -BackgroundColor Black (" " * $width) -NoNewline
        [Console]::SetCursorPosition(0, $bottom)
        Write-Host -ForegroundColor Black -BackgroundColor Black (" " * $width) -NoNewline
        $top++
        $bottom--
        Start-Sleep -Milliseconds 50
    }
    Clear-Host
}