function Import-CharacterFromJson {
    param (
        [string] $Path
    )

    if(-not (Test-Path -Path $Path)) {
        throw "The character json file at '$Path' does not exist."
    }

    $characterJson = Get-Content -Path $Path -Raw | ConvertFrom-Json

    # Initialise character
    $character = @{
        # Should the camera follow the character?
        CameraFocus = $characterJson.CameraFocus
        # The width of the character sprite used for collisions
        Width = $characterJson.Width
        # The height of the character sprite used for collisions
        Height = $characterJson.Height
        # Mark the character as moving to lock new inputs, the character can only receive a new direction once it meets its destination
        IsMoving = $false
        # Where is the character currently on the map?
        Source = @{
            X = 0
            Y = 0
        }
        # Where is the character moving to on the map?
        Destination = @{
            X = 0
            Y = 0
        }
        # Which direction is the character facing?
        Direction = "Down"
        # The images that make up the character
        Sprites = @{
            # What sprites are available for each direction the character can face?
            Directional = @{
                Up = @()
                Down = @()
                Left = @()
                Right = @()
            }
        }
    }

    # Load directional sprites
    foreach($direction in @("Up", "Down", "Left", "Right")) {
        if($characterJson.Sprites.Directional.PSObject.Properties.Name -notcontains $direction) {
            throw "The character json file at '$Path' does not contain a '$direction' directional sprite."
        }
        foreach($imagePath in $characterJson.Sprites.Directional.$direction) {
            $imagePath = Join-Path -Path (Split-Path -Path $Path) -ChildPath $imagePath
            if(-not (Test-Path -Path $imagePath)) {
                throw "The character json file at '$Path' contains a '$direction' directional sprite with an invalid image path '$imagePath'."
            }
            $character.Sprites.Directional.$direction += ,@(Read-ImageIntoPixelArray -ImagePath $imagePath)
        }
    }

    return $character
}