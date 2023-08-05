# Attempt using buffer cells for high framerate rendering on windows. This is 1000x faster then virtual terminal escape codes on windows terminal but it's restricted to the old terminal color scheme.

Import-Module "$PSScriptRoot\renderer\Pwshmon.Buffer.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Cursor.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Main.psm1" -Force

trap {
    Restore-OriginalScreenBuffer
}

$imageBufferCells = Get-ImageAsBufferCells -ImagePath "$PSScriptRoot\media\backgrounds\Pallet.bmp" -Width $Host.UI.RawUI.WindowSize.Width -Height ($Host.UI.RawUI.WindowSize.Height * 2)
$imageBufferCells2 = Get-ImageAsBufferCells -ImagePath "$PSScriptRoot\media\backgrounds\Pallet2.bmp" -Width $Host.UI.RawUI.WindowSize.Width -Height ($Host.UI.RawUI.WindowSize.Height * 2)
$height = $imageBufferCells.GetLength(0)
$width = $imageBufferCells.GetLength(1)
#Open-AlternateScreenBuffer

Set-BufferSize -Width $width -Height $height

$offset = 0
$start = Get-Date
while($offset -lt 50) {
    Set-Buffer -BufferCells $imageBufferCells
    Set-Buffer -BufferCells $imageBufferCells2
    $offset++
}
$end = (Get-Date) - $start
$frameRate = [Math]::Round(($offset / $end.TotalSeconds), 2)
Write-Host "Duration in milliseconds = $($end.TotalMilliseconds), Framerate = $($frameRate * 2) fps"

#$stats = Write-Frames -Frames 10 -ImageString $imageString
#$stats = Write-Frames -ImageString $imageString
#Restore-OriginalScreenBuffer

#Write-Host $stats