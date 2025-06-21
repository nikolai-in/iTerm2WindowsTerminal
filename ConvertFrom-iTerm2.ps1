param(
    [Parameter(Mandatory = $true, Position = 0,
        ParameterSetName = "Internet",
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "The URL with iTerm colours.")]
    [ValidateScript({ $_ -match '^http.*itermcolors$' })]
    [string]$colorFileURL,

    [Parameter(Mandatory = $true, Position = 0,
        ParameterSetName = "Local",
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "A file iTerm colours.")]
    [ValidateScript({ ([xml](Get-Content $_) -is [xml]) })]
    [string]$colorFile
)

# example URL for testing
# $colorFileURL = "https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Ubuntu.itermcolors"

# function that takes as input a string with the iTerm color and outputs the Windows Terminal Color
function ConvertTerm2Terminals {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$iTermColor
    )

    $colorMappings = @{
        "Ansi 0 Color"        = "black"
        "Ansi 1 Color"        = "red"
        "Ansi 2 Color"        = "green"
        "Ansi 3 Color"        = "yellow"
        "Ansi 4 Color"        = "blue"
        "Ansi 5 Color"        = "purple" # I can't find magenta in the VSCode colors, so I go with purple
        "Ansi 6 Color"        = "cyan"
        "Ansi 7 Color"        = "white"
        "Ansi 8 Color"        = "brightBlack"
        "Ansi 9 Color"        = "brightRed"
        "Ansi 10 Color"       = "brightGreen"
        "Ansi 11 Color"       = "brightYellow"
        "Ansi 12 Color"       = "brightBlue"
        "Ansi 13 Color"       = "brightPurple"
        "Ansi 14 Color"       = "brightCyan"
        "Ansi 15 Color"       = "brightWhite"
        "Cursor Color"        = "cursorColor"
        "Cursor Text Color"   = "!cursorTextColor" # I made this up. Ignore it. 
        "Bold Color"          = "!boldColor" # I made this up. Ignore it. 
        "Selected Text Color" = "!selectionForeground" # I made this up. Ignore it. 
        "Selection Color"     = "selectionBackground"
        "Background Color"    = "background"
        "Foreground Color"    = "foreground"
    }

    $colorMappings.$iTermColor
}

# function that takes as input a dict containing color components
# and outputs a Windows Terminal compatible hex color
function ConvertReal2Hex {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.Xml.XmlElement]$ColorDict
    )

    try {
        # Extract individual color components from the XML dict
        # iTerm stores colors as floating point values between 0 and 1
        $blueComponent = [float]($ColorDict.SelectSingleNode("real[preceding-sibling::key[1][text()='Blue Component']]").InnerText)
        $greenComponent = [float]($ColorDict.SelectSingleNode("real[preceding-sibling::key[1][text()='Green Component']]").InnerText)
        $redComponent = [float]($ColorDict.SelectSingleNode("real[preceding-sibling::key[1][text()='Red Component']]").InnerText)

        # Convert from 0-1 range to 0-255 range and ensure we have integers
        # Clamp values to valid range in case of any parsing issues
        [int]$red = [Math]::Max(0, [Math]::Min(255, [Math]::Round($redComponent * 255)))
        [int]$green = [Math]::Max(0, [Math]::Min(255, [Math]::Round($greenComponent * 255)))
        [int]$blue = [Math]::Max(0, [Math]::Min(255, [Math]::Round($blueComponent * 255)))

        # Format as hex color (#RRGGBB)
        "#{0:X2}{1:X2}{2:X2}" -f $red, $green, $blue
    }
    catch {
        Write-Warning "Failed to parse color components: $($_.Exception.Message)"
        return "#000000"  # Default to black on error
    }
}

$finalOutput = @{}

if ($colorFileURL) {
    try {
        [xml]$xmlObj = $(Invoke-WebRequest $colorFileURL).Content
    }
    catch {
        throw $_.Exception.Message
    }
    $finalOutput["name"] = $(Split-Path $colorFileURL -LeafBase)

}
else {
    [xml]$xmlObj = [xml](Get-Content $colorFile)
    $finalOutput["name"] = $(Split-Path $colorFile -LeafBase)
}

$keysArray = @($xmlObj.plist.dict.key)
$valuesArray = @($xmlObj.plist.dict.dict)

$hexColorsArray = foreach ($value in $valuesArray) { ConvertReal2Hex $value }
$winColorNamesArray = foreach ($key in $keysArray) { ConvertTerm2Terminals $key }


for ($i = 0; $i -lt $winColorNamesArray.Length; $i++) {
    $colorName = $winColorNamesArray[$i]
    if ($colorName -and $colorName -notmatch "^!" -and $hexColorsArray[$i]) { 
        $finalOutput[$colorName] = $hexColorsArray[$i] 
    }
}

$finalOutput | ConvertTo-Json