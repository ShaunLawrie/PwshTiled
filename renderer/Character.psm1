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
        Source = @{
            X = 0
            Y = 0
        }
        Destination = @{
            X = 0
            Y = 0
        }
        Direction = "Down"
        Sprites = @{
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
            $character.Sprites.Directional.$direction += ,@(Read-ImageIntoPixelArray -ImagePath $imagePath -Width $characterJson.Width -Height $characterJson.Height)
        }
    }

    return $character
}