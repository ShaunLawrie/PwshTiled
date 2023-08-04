$ErrorActionPreference = "Stop"

Add-Type -Path "$PSScriptRoot\renderer\packages\SixLabors.ImageSharp\lib\netstandard2.0\SixLabors.ImageSharp.dll"
$modules = Get-ChildItem -Filter "*.psm1" -Path "$PSScriptRoot" -Recurse
foreach($module in $modules) {
    Import-Module -Name $module.FullName -Force
}

$background = Read-ImageIntoPixelArray -ImagePath "$PSScriptRoot\media\backgrounds\Pallet.bmp"
$character = Import-CharacterFromJson -Path "$PSScriptRoot\media\characters\hero\character.json"

$frames = 0
$start = Get-Date
$tileSize = 12
$backgroundWidth = $background[0].Count
$backgroundHeight = $background.Count
$terminalWidth = $Host.UI.RawUI.WindowSize.Width
$terminalHeight = $Host.UI.RawUI.WindowSize.Height * 2 - 2
$characterPosition = @{
    X = [int]($backgroundWidth / 2) - [int]($terminalWidth / 2) - $tileSize
    Y = [int]($backgroundHeight / 2) - [int]($terminalHeight / 2) - $tileSize
}
$startOffsetX = [int]($backgroundWidth / 2) - [int]($terminalWidth / 2)
$startOffsetY = [int]($backgroundHeight / 2) - [int]($terminalHeight / 2)

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

    $image = New-Frame -Background $background -Character $character -CharacterPosition $characterPosition -TileSize $tileSize -TerminalWidth $terminalWidth -TerminalHeight $terminalHeight

    Write-Image -Image $image -OffsetX $startOffsetX -OffsetY $startOffsetY -Width $terminalWidth -Height $terminalHeight
    $frameRate = [Math]::Round(($frames / ((Get-Date) - $start).TotalSeconds), 2)
    [Console]::Write("`e[HFrames rendered = $frames, Framerate = $frameRate FPS")
    $frames++
}

$frameRate = [Math]::Round(($frames / ((Get-Date) - $start).TotalSeconds), 2)
Write-Host "Frames rendered = $frames, Framerate = $frameRate fps"