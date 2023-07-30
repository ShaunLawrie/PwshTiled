Import-Module "$PSScriptRoot\renderer\Pwshmon.Buffer.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Cursor.psm1" -Force
Import-Module "$PSScriptRoot\renderer\Pwshmon.Main.psm1" -Force

trap {
    Restore-OriginalScreenBuffer
}

$image = Read-Background -ImagePath "$PSScriptRoot\media\backgrounds\Pallet.bmp"
#$image2 = Read-Background -ImagePath "$PSScriptRoot\media\backgrounds\Pallet2.bmp"
#$imageBufferCells = Get-Image -Image $image -Width $Host.UI.RawUI.WindowSize.Width -Height ($Host.UI.RawUI.WindowSize.Height * 2 - 2)
#$imageBufferCells2 = Get-Image -ImagePath $image2 -Width $Host.UI.RawUI.WindowSize.Width -Height ($Host.UI.RawUI.WindowSize.Height * 2 - 2)
#Open-AlternateScreenBuffer

#Set-BufferSize -Width $width -Height $height

$offset = 0
$start = Get-Date
$width = $Host.UI.RawUI.WindowSize.Width
$height = $Host.UI.RawUI.WindowSize.Height * 2

$originalOut = [Console]::Out
$sw = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(), [Console]::Out.Encoding, ($Host.UI.RawUI.BufferSize.Width * $Host.UI.RawUI.BufferSize.Height * 10))
$sw.AutoFlush = $true
[Console]::SetOut($sw)

while($offset -lt 100) {
    $i = Get-Image -Image $image -OffsetX $offset -Width $width -Height $height
    $sw.Write($i)
    $offset += 2
}

$sw.Close()
$sw.Dispose()

[Console]::SetOut($originalOut)
$end = (Get-Date) - $start
$frameRate = [Math]::Round(($offset / $end.TotalSeconds), 2)
Write-Host "Duration in milliseconds = $($end.TotalMilliseconds), Framerate = $($frameRate * 2) fps"
