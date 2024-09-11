function Test-HitmapCollision {
    param (
        [object] $Destination,
        [array] $Hitmap
    )

    if($Destination.X -ge 0 -and $Destination.Y -ge 0 -and $Destination.X -lt $Hitmap[0].Count -and $Destination.Y -lt $Hitmap.Count) {
        $hitmapPosition = $Hitmap[$Destination.Y][$Destination.X]
        if(($hitmapPosition.R + $hitmapPosition.G + $hitmapPosition.B) -gt 0) {
            return $false
        }
    }

    return $true
}

function Import-MapFromJson {
    param (
        [string] $Path
    )

    if(-not (Test-Path -Path $Path)) {
        throw "The map json file at '$Path' does not exist."
    }

    $mapJson = Get-Content -Path $Path -Raw | ConvertFrom-Json

    # Initialise character
    $map = @{
        # The name of the map
        Name = $mapJson.Name
        # The width of the map
        Width = $mapJson.Width
        # The height of the map
        Height = $mapJson.Height
        # Where should the character be positioned if this map is loaded?
        CharacterDefaultEntryPosition = $mapJson.CharacterDefaultPortal
        # Character map transition portals
        Portals = @($mapJson.Portals)
        # The background layer frames
        Frames = @()
        # Hitmap layer
        Hitmap = $null
    }

    # Load frames
    foreach($frame in $mapJson.Frames) {
        $framePath = Join-Path -Path (Split-Path -Path $Path) -ChildPath $frame
        if(-not (Test-Path -Path $framePath)) {
            throw "The map json file at '$Path' contains a '$frame' map with an invalid image path '$mapPath'."
        }
        $map.Frames += ,@(Read-ImageIntoPixelArray -ImagePath $framePath)
    }

    # Load hitmap
    $hitmapPath = Join-Path -Path (Split-Path -Path $Path) -ChildPath $mapJson.Hitmap
    if(-not (Test-Path -Path $hitmapPath)) {
        throw "The map json file at '$Path' contains a '$($mapJson.Hitmap)' hitmap with an invalid image path '$hitmapPath'."
    }
    $map.Hitmap = @(Read-ImageIntoPixelArray -ImagePath $hitmapPath)

    return $map
}