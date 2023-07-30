Add-Type -Path (Join-Path $PSScriptRoot "packages\SixLabors.ImageSharp\lib\netstandard2.0\SixLabors.ImageSharp.dll")

$script:ConsoleColors = [enum]::GetValues([System.ConsoleColor]) | Foreach-Object { [System.Drawing.Color]::FromName($_) }
$script:CachedColorMappings = @{}

function New-Image {
    param (
        [int] $Width,
        [int] $Height
    )
    $image = @()
    
    for($y = 0; $y -lt $Height; $y++) {
        $row = @()
        for($x = 0; $x -lt $Width; $x++) {
            $row += @{
                R = 0
                G = 0
                B = 0
                A = 0
            }
        }
        $image += ,$row
    }

    return $image
}

function Read-Background {
    param (
        [string] $ImagePath
    )

    $resolvedPath = Resolve-Path $ImagePath
    if(-not (Test-Path $resolvedPath)) {
        throw "Image not found: $ImagePath"
    }

    $image = [SixLabors.ImageSharp.Image]::Load($resolvedPath)
    if($image.Frames.Count -gt 1) {
        Write-Warning "There $($image.Frames.Count) frames in the image. Only the first frame will be used."
    }

    $frame = $image.Frames[0]
    $imageArray = New-Image -Width $image.Width -Height $image.Height
    for($y = 0; $y -lt $image.Height; $y++) {
        for($x = 0; $x -lt $image.Width; $x++) {
            $imageArray[$y][$x] = @{
                PackedValue = $frame[$x,$y].PackedValue
                R = $frame[$x,$y].R
                G = $frame[$x,$y].G
                B = $frame[$x,$y].B
                A = $frame[$x,$y].A
            }
        }
    }

    return $imageArray
}

function Write-Image (
        [object] $Image,
        [int] $OffsetX = 0,
        [int] $OffsetY = 0,
        [int] $Width = 10,
        [int] $Height = 10
    ) {
    $halfBlock = [Char]0x2584
    $imageString = [System.Text.StringBuilder]::new()
    $null = $imageString.Append("`e[?25l`e[2;0H")
    
    for($y = 0; $y -lt $Height; $y += 2) {
        for($x = 0; $x -lt $Width; $x++) {
            # Parse the image 2 vertical pixels at a time and use the lower half block character with varying foreground and background colors to
            # make it appear as two pixels within one character space
            $pixelBelow = $Image[($y + $OffsetY + 1)][$x + $OffsetX]
            if($pixelBelow.A -eq 0) {
                 # Get image from layer below
                 Write-Warning "Not implemented"
            }

            $currentPixel = $Image[$y + $OffsetY][$x + $OffsetX]
            if($currentPixel.A -eq 0) {
                # Get image from layer below
                Write-Warning "Not implemented"
            }

            $null = $imageString.Append(("`e[38;2;{0};{1};{2}m`e[48;2;{3};{4};{5}m$halfBlock`e[0m" -f $pixelBelow.R, $pixelBelow.G, $pixelBelow.B, $currentPixel.R, $currentPixel.G, $currentPixel.B))
        }
    }
    
    [Console]::Write($imageString.ToString())
}

function Get-ClosestConsoleColor {
    param (
        [object] $Pixel
    )
    
    if($script:CachedColorMappings.ContainsKey($Pixel.PackedValue)) {
        return $script:CachedColorMappings[$Pixel.PackedValue]
    }
    
    $ranks = $script:ConsoleColors | ForEach-Object {
        $redRank = [math]::Abs($_.R - $Pixel.R)
        $greenRank = [math]::Abs($_.G - $Pixel.G)
        $blueRank = [math]::Abs($_.B - $Pixel.B)
        $rank = $redRank + $greenRank + $blueRank
        return @{
            Name = $_.Name
            Rank = $rank
        }
    }

    $topRanked = $ranks | Sort-Object -Property Rank | Select-Object -First 1 -ExpandProperty Name

    $script:CachedColorMappings[$Pixel.PackedValue] = $topRanked

    return $topRanked
}

function Get-ImageAsBufferCells {
    param (
        [string] $ImagePath,
        [int] $Width = -1,
        [int] $Height = -1
    )

    $Image = Read-Background -ImagePath $ImagePath

    if($Width -eq -1) {
        $Width = $Image[0].Count
    }
    if($Height -eq -1) {
        $Height = $Image.Count
    }

    $bufferCellArray = [System.Management.Automation.Host.BufferCell[,]]::new($Height, $Width)

    Write-Progress -Id 0 -Activity "Loading Image" -Status "Initializing" -PercentComplete 1
    for($y = 0; $y -lt $Height; $y += 2) {
        for($x = 0; $x -lt $Width; $x++) {
            $currentPixel = $Image[$y][$x]
            if($currentPixel.A -eq 0) {
                # Get image from layer below
                Write-Warning "Not implemented"
            } else {
                $currentPixelColor = Get-ClosestConsoleColor -Pixel $currentPixel
            }

            # Parse the image 2 vertical pixels at a time and use the lower half block character with varying foreground and background colors to
            # make it appear as two pixels within one character space
            $pixelBelow = $Image[($y + 1)][$x]

            if($pixelBelow.A -eq 0) {
                 # Get image from layer below
                 Write-Warning "Not implemented"
            } else {
                $pixelBelowColor = Get-ClosestConsoleColor -Pixel $pixelBelow
            }

            # add to buffercells
            $cell = [System.Management.Automation.Host.BufferCell]::new([Char]0x2584, $pixelBelowColor, $currentPixelColor, [System.Management.Automation.Host.BufferCellType]::Complete)
            $bufferCellArray[($y / 2), $x] = $cell
        }
        Write-Progress -Id 0 -Activity "Loading Image" -Status "Row: $y / $Height" -PercentComplete ([int](($y / $Height) * 100))
    }
    Write-Progress -Id 0 -Activity "Loading Image" -Completed

    return ,$bufferCellArray
}

function Write-FramesWithoutAutoFlush {
    param (
        [int] $FrameLimit = 20,
        [string] $ImageString
    )

    $originalOut = [Console]::Out
    $sw = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), [Console]::Out.Encoding, ($Host.UI.RawUI.BufferSize.Width * $Host.UI.RawUI.BufferSize.Height * 10))
    $sw.AutoFlush = $true
    [Console]::SetOut($sw)

    $timing = Measure-Command {
        for($f = 0; $f -lt $FrameLimit; $f++) {
            $sw.Write($ImageString)
            #$sw.Flush()
        }
    }
    
    $sw.Close()
    $sw.Dispose()
    
    [Console]::SetOut($originalOut)

    # Frame rate
    $frameRate = [Math]::Round(($FrameLimit / $timing.TotalSeconds), 2)
    return "Frames: $FrameLimit, Rate: $frameRate fps"
}

function Write-Frames {
    param (
        [int] $FrameLimit = 20,
        [string] $ImageString
    )

    $timing = Measure-Command {
        for($f = 0; $f -lt $FrameLimit; $f++) {
            [Console]::Write($ImageString)
        }
    }

    # Frame rate
    $frameRate = [Math]::Round(($FrameLimit / $timing.TotalSeconds), 2)
    return "Frames: $FrameLimit, Rate: $frameRate fps"
}