function Set-CursorPosition {
    param (
        [int] $X = 0,
        [int] $Y = 0
    )
    Write-Host "`e[${Y};${X}H"
}

function Write-BufferToScreen {
    param (
        $Buffer
    )
    $hideCursor = "`e[?25l"
    $resetCursorPosition = "`e[H"
    Write-Host -NoNewline -Message ($hideCursor + $resetCursorPosition + $Buffer)
}