Import-Module "$PSScriptRoot\renderer\Pwshmon.Buffer.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Cursor.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Main.psm1" -Force

trap {
    Restore-OriginalScreenBuffer
}

$image = Read-Background -ImagePath "$PSScriptRoot\media\backgrounds\Pallet.bmp"

$frames = 0
$start = Get-Date
$imageWidth = $image[0].Count
$imageHeight = $image.Count
$width = $Host.UI.RawUI.WindowSize.Width
$height = $Host.UI.RawUI.WindowSize.Height * 2 - 2
$startOffsetX = [int]($imageWidth / 2) - [int]($width / 2)
$startOffsetY = [int]($imageHeight / 2) - [int]($height / 2)

Clear-Host
while($true) {
    $lastKey = $null
    while([Console]::KeyAvailable) {
        $lastKey = [Console]::ReadKey($true)
    }

    switch($lastKey.Key) {
        "UpArrow" {
            $startOffsetY--
        }
        "DownArrow" {
            $startOffsetY++
        }
        "LeftArrow" {
            $startOffsetX--
        }
        "RightArrow" {
            $startOffsetX++
        }
    }

    Write-Image -Image $image -OffsetX $startOffsetX -OffsetY $startOffsetY -Width $width -Height $height
    $frameRate = [Math]::Round(($frames / ((Get-Date) - $start).TotalSeconds), 2)
    [Console]::Write("`e[HFrames rendered = $frames, Framerate = $frameRate FPS")
    $frames++
}

$frameRate = [Math]::Round(($frames / ((Get-Date) - $start).TotalSeconds), 2)
Write-Host "Frames rendered = $frames, Framerate = $frameRate fps"