$ErrorActionPreference = 'Stop'

$host.UI.RawUI.WindowTitle = "Pamplona Future AIO"

# Hide cursor globally
try {
    [Console]::CursorVisible = $false
} catch {
    # Ignore if not supported
}

#region Configuration Constants

$script:Config = @{
    DefaultGamePath = "C:\Program Files (x86)\Steam\steamapps\common\Mirrors Edge Catalyst"

    # Docker resource names
    Docker = @{
        Network = "pf-net"
        DatabaseContainer = "pf-db"
        ServerContainer = "pf-srv"
        DatabaseVolume = "pf-db-vol"
        MitmVolume = "/pf-mitm-vol"
        ServerImage = "ghcr.io/iwanmikhajlov/pamplona-future-aio"
        DatabaseImage = "postgres:17"
    }

    # Default configuration values
    Defaults = @{
        PlayerName = "ploxxxy"
        DbUser = "dbuser"
        DbPassword = "dbpasswd"
        DbName = "dbname"
        UserId = "2407107883"
        PersonaId = "1011786733"
    }

    # Port configuration
    Ports = @{
        Gateway = 3000
        Blaze = 25565
        Game = 42230
        PostgreSQL = 5432
    }

    # Timeout configuration (seconds)
    Timeouts = @{
        DatabaseReady = 15
        ServerHealthChecks = 15
        ServerMinRuntime = 7
    }

    # UI dimensions
    UI = @{
        DefaultWidth = 70
        MenuWidth = 50
        LogBoxWidth = 68
        LogTailLines = 15
    }
}

# TUI Color Scheme
$script:ColorScheme = @{
    Primary = "Cyan"
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "White"
    Muted = "DarkGray"
    Highlight = "Black"
    HighlightBg = "Cyan"
    Title = "White"
}

# TUI Box Drawing Characters
$script:Box = @{
    TopLeft = [string][char]0x250C      # ┌
    TopRight = [string][char]0x2510     # ┐
    BottomLeft = [string][char]0x2514   # └
    BottomRight = [string][char]0x2518  # ┘
    Horizontal = [string][char]0x2500   # ─
    Vertical = [string][char]0x2502     # │
    HeavyHorizontal = [string][char]0x2501  # ━
}

#endregion

#region UI Rendering Functions

<#
.SYNOPSIS
    Draws a header with title centered in a box.
.PARAMETER Title
    The title text to display.
.PARAMETER Width
    The width of the header box.
#>
function Draw-Header {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.DefaultWidth
    )

    Clear-Host
    Write-Host ""

    # Top border
    Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.HeavyHorizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Primary

    # Title (centered)
    $padding = [Math]::Max(0, [Math]::Floor(($Width - 2 - $Title.Length) / 2))
    Write-Host "$($Box.Vertical)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host (" " * $padding) -NoNewline
    Write-Host $Title -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host (" " * ($Width - 2 - $padding - $Title.Length)) -NoNewline
    Write-Host "$($Box.Vertical)" -ForegroundColor $ColorScheme.Primary

    # Bottom border
    Write-Host "$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.HeavyHorizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Primary
    Write-Host ""
}

<#
.SYNOPSIS
    Draws a box with optional title and content lines.
.PARAMETER Title
    Optional title displayed in the top border.
.PARAMETER Lines
    Array of text lines to display in the box.
.PARAMETER Width
    The width of the box.
.PARAMETER BorderColor
    Color of the border.
.PARAMETER TextColor
    Color of the text content.
#>
function Draw-Box {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "",

        [Parameter()]
        [string[]]$Lines = @(),

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.DefaultWidth,

        [Parameter()]
        [string]$BorderColor = $ColorScheme.Primary,

        [Parameter()]
        [string]$TextColor = $ColorScheme.Info
    )

    # Top border
    if ($Title) {
        $titleWithPadding = " $Title "
        $leftBorder = [Math]::Floor(($Width - $titleWithPadding.Length - 2) / 2)
        $rightBorder = $Width - $titleWithPadding.Length - $leftBorder - 2

        Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $BorderColor
        Write-Host ($Box.Horizontal * $leftBorder) -NoNewline -ForegroundColor $BorderColor
        Write-Host $titleWithPadding -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host ($Box.Horizontal * $rightBorder) -NoNewline -ForegroundColor $BorderColor
        Write-Host "$($Box.TopRight)" -ForegroundColor $BorderColor
    } else {
        Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $BorderColor
        Write-Host ($Box.Horizontal * ($Width - 2)) -NoNewline -ForegroundColor $BorderColor
        Write-Host "$($Box.TopRight)" -ForegroundColor $BorderColor
    }

    # Content lines
    foreach ($line in $Lines) {
        $actualLength = $line.Length
        $padding = [Math]::Max(0, $Width - $actualLength - 4)

        Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $BorderColor
        Write-Host $line -NoNewline -ForegroundColor $TextColor
        Write-Host (" " * $padding) -NoNewline
        Write-Host " $($Box.Vertical)" -ForegroundColor $BorderColor
    }

    # Bottom border
    Write-Host "$($Box.BottomLeft)" -NoNewline -ForegroundColor $BorderColor
    Write-Host ($Box.Horizontal * ($Width - 2)) -NoNewline -ForegroundColor $BorderColor
    Write-Host "$($Box.BottomRight)" -ForegroundColor $BorderColor
}

<#
.SYNOPSIS
    Displays an interactive menu with selectable items.
.PARAMETER Title
    The menu title.
.PARAMETER Items
    Array of menu item strings.
.PARAMETER SelectedIndex
    Initially selected item index.
.PARAMETER Width
    Width of the menu box.
#>
function Show-Menu {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Main Menu",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Items,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$SelectedIndex = 0,

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.MenuWidth
    )

    $windowHeight = $host.UI.RawUI.WindowSize.Height
    $windowWidth = $host.UI.RawUI.WindowSize.Width

    # Calculate menu height: header (3) + items + box borders (2) + help text (2) + spacing (4)
    $menuHeight = 3 + $Items.Count + 2 + 2 + 4
    $verticalOffset = [Math]::Max(0, [Math]::Floor(($windowHeight - $menuHeight) / 2))

    Clear-Host

    # Add vertical spacing
    for ($i = 0; $i -lt $verticalOffset; $i++) {
        Write-Host ""
    }

    # Calculate horizontal centering
    $horizontalPadding = [Math]::Max(0, [Math]::Floor(($windowWidth - $Width) / 2))
    $padding = " " * $horizontalPadding

    # Header
    $titlePadding = [Math]::Max(0, [Math]::Floor(($Width - 2 - $Title.Length) / 2))
    Write-Host "$padding$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.HeavyHorizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Primary

    Write-Host "$padding$($Box.Vertical)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host (" " * $titlePadding) -NoNewline
    Write-Host $Title -NoNewline -ForegroundColor $ColorScheme.Title
    Write-Host (" " * ($Width - 2 - $titlePadding - $Title.Length)) -NoNewline
    Write-Host "$($Box.Vertical)" -ForegroundColor $ColorScheme.Primary

    Write-Host "$padding$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.HeavyHorizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Primary

    Write-Host ""

    # Menu box top
    Write-Host "$padding$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.Horizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Primary

    # Menu items
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $isSelected = ($i -eq $SelectedIndex)

        Write-Host $padding -NoNewline

        if ($isSelected) {
            Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
            Write-Host "$([char]0x25B6) " -NoNewline -ForegroundColor $ColorScheme.Primary  # ▶
            $bgColor = $ColorScheme.HighlightBg
            $fgColor = $ColorScheme.Highlight
            Write-Host "$item" -NoNewline -ForegroundColor $fgColor -BackgroundColor $bgColor
            # Width calculation: total width - borders and spaces (4) - arrow and space (2) - item length
            $itemPadding = $Width - 4 - 2 - $item.Length
            Write-Host (" " * $itemPadding) -NoNewline -BackgroundColor $bgColor
            Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
        } else {
            Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
            Write-Host "  " -NoNewline
            Write-Host "$item" -NoNewline -ForegroundColor $ColorScheme.Info
            # Width calculation: total width - borders and spaces (4) - two spaces (2) - item length
            $itemPadding = $Width - 4 - 2 - $item.Length
            Write-Host (" " * $itemPadding) -NoNewline
            Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
        }
    }

    # Menu box bottom
    Write-Host "$padding$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.Horizontal * ($Width - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Primary

    Write-Host ""
    Write-Host "$padding Use " -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$([char]0x2191)$([char]0x2193)" -NoNewline -ForegroundColor $ColorScheme.Primary  # ↑↓
    Write-Host " to navigate, " -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "ENTER" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host " to select, " -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "ESC" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host " to exit" -ForegroundColor $ColorScheme.Muted
}

function Update-MenuItem {
    param(
        [int]$ItemIndex,
        [string]$ItemText,
        [bool]$IsSelected,
        [int]$LineNumber,
        [int]$Width,
        [int]$HorizontalPadding
    )

    $padding = " " * $HorizontalPadding
    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.X = 0
    $cursorPos.Y = $LineNumber
    $Host.UI.RawUI.CursorPosition = $cursorPos

    Write-Host $padding -NoNewline

    if ($IsSelected) {
        Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
        Write-Host "$([char]0x25B6) " -NoNewline -ForegroundColor $ColorScheme.Primary  # ▶
        $bgColor = $ColorScheme.HighlightBg
        $fgColor = $ColorScheme.Highlight
        Write-Host "$ItemText" -NoNewline -ForegroundColor $fgColor -BackgroundColor $bgColor
        $itemPadding = $Width - 4 - 2 - $ItemText.Length
        Write-Host (" " * $itemPadding) -NoNewline -BackgroundColor $bgColor
        Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
    } else {
        Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
        Write-Host "  " -NoNewline
        Write-Host "$ItemText" -NoNewline -ForegroundColor $ColorScheme.Info
        $itemPadding = $Width - 4 - 2 - $ItemText.Length
        Write-Host (" " * $itemPadding) -NoNewline
        Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
    }
}

<#
.SYNOPSIS
    Handles menu navigation and item selection.
.PARAMETER Items
    Array of menu item strings.
.OUTPUTS
    Integer index of selected item, or -1 if cancelled.
#>
function Read-MenuSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Items
    )

    $selectedIndex = 0
    $previousIndex = -1
    $width = $Config.UI.MenuWidth

    # Draw menu once
    Show-Menu -Title "PAMPLONA FUTURE AIO" -Items $Items -SelectedIndex $selectedIndex

    $windowWidth = $host.UI.RawUI.WindowSize.Width
    $windowHeight = $host.UI.RawUI.WindowSize.Height
    $horizontalPadding = [Math]::Max(0, [Math]::Floor(($windowWidth - $width) / 2))

    # Calculate first item line number
    $menuHeight = 3 + $Items.Count + 2 + 2 + 4
    $verticalOffset = [Math]::Max(0, [Math]::Floor(($windowHeight - $menuHeight) / 2))
    $firstItemLine = $verticalOffset + 5  # header(3) + empty line(1) + box top(1)

    while ($true) {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        $previousIndex = $selectedIndex

        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $selectedIndex = ($selectedIndex - 1)
                if ($selectedIndex -lt 0) { $selectedIndex = $Items.Count - 1 }
            }
            40 { # Down arrow
                $selectedIndex = ($selectedIndex + 1) % $Items.Count
            }
            13 { # Enter
                return $selectedIndex
            }
            27 { # Escape
                return -1
            }
        }

        # Only redraw if selection changed
        if ($previousIndex -ne $selectedIndex) {
            # Redraw previous item (unselected)
            Update-MenuItem -ItemIndex $previousIndex -ItemText $Items[$previousIndex] -IsSelected $false `
                -LineNumber ($firstItemLine + $previousIndex) -Width $width -HorizontalPadding $horizontalPadding

            # Redraw new item (selected)
            Update-MenuItem -ItemIndex $selectedIndex -ItemText $Items[$selectedIndex] -IsSelected $true `
                -LineNumber ($firstItemLine + $selectedIndex) -Width $width -HorizontalPadding $horizontalPadding
        }
    }
}

<#
.SYNOPSIS
    Displays a message box with title and content.
.PARAMETER Title
    The title of the message box.
.PARAMETER Message
    Array of message lines to display.
.PARAMETER Type
    Type of message (Info, Success, Error, Warning).
.PARAMETER Width
    Width of the message box.
#>
function Show-MessageBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [string[]]$Message,

        [Parameter()]
        [ValidateSet("Info", "Success", "Error", "Warning")]
        [string]$Type = "Info",

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.DefaultWidth
    )

    Clear-Host
    Write-Host ""
    Write-Host ""

    $icon = switch ($Type) {
        "Success" { [char]0x2713 }  # $([char]0x2713)
        "Error" { [char]0x2717 }    # $([char]0x2717)
        "Warning" { [char]0x26A0 }  # ⚠
        default { [char]0x2139 }    # ℹ
    }

    Draw-Box -Title "$icon $Title" -Lines $Message -Width $Width -BorderColor $ColorScheme.Primary -TextColor $ColorScheme.Info

    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Displays container logs in a formatted box.
.PARAMETER ContainerName
    Name of the container to get logs from.
.PARAMETER Width
    Width of the log box.
#>
function Show-ContainerLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter()]
        [int]$Width = $Config.UI.LogBoxWidth
    )

    Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host ($Box.Horizontal * $Width) -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Muted

    $logs = docker logs --tail $($Config.UI.LogTailLines) $ContainerName 2>&1
    $logLines = $logs -split "`n"

    foreach ($line in $logLines) {
        $trimmed = $line.Trim()
        $maxLength = $Width - 2
        if ($trimmed.Length -gt $maxLength) {
            $trimmed = $trimmed.Substring(0, $maxLength)
        }
        $padding = [Math]::Max(0, $maxLength - $trimmed.Length)

        Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Muted
        Write-Host $trimmed -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host (" " * $padding) -NoNewline
        Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Muted
    }

    Write-Host "$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host ($Box.Horizontal * $Width) -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Muted
}

<#
.SYNOPSIS
    Shows deployment error with logs and performs cleanup.
.PARAMETER ErrorTitle
    The error title (e.g., "Database", "Server").
.PARAMETER ErrorMessage
    Descriptive error message.
.PARAMETER ContainerName
    Name of the container to get logs from.
.PARAMETER CleanupContainers
    Array of container names to remove during cleanup.
#>
function Show-DeploymentError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ErrorTitle,

        [Parameter(Mandatory)]
        [string]$ErrorMessage,

        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter()]
        [string[]]$CleanupContainers = @()
    )

    Write-Host ""
    Write-Host ""

    Draw-Header -Title "Deployment Failed - $ErrorTitle" -Width $Config.UI.DefaultWidth
    Write-Host ""
    Write-Host " $ErrorMessage" -ForegroundColor $ColorScheme.Error
    Write-Host ""

    # Show container logs
    Show-ContainerLogs -ContainerName $ContainerName

    # Cleanup resources
    Write-Host ""
    Write-Host " Cleaning up resources..." -ForegroundColor $ColorScheme.Warning

    foreach ($container in $CleanupContainers) {
        docker rm -f $container 2>&1 | Out-Null
    }
    docker volume rm $($Config.Docker.DatabaseVolume) 2>&1 | Out-Null
    docker network rm $($Config.Docker.Network) 2>&1 | Out-Null

    Write-Host " $([char]0x2713) Cleanup complete" -ForegroundColor $ColorScheme.Success

    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Shows error when docker run command fails, displaying error output.
.PARAMETER ErrorTitle
    The error title (e.g., "Database", "Server").
.PARAMETER ErrorOutput
    The error output from docker run command.
.PARAMETER CleanupContainers
    Array of container names to remove during cleanup.
#>
function Show-DockerRunError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ErrorTitle,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ErrorOutput,

        [Parameter()]
        [string[]]$CleanupContainers = @()
    )

    Write-Host ""
    Write-Host ""

    Draw-Header -Title "Deployment Failed - $ErrorTitle" -Width $Config.UI.DefaultWidth
    Write-Host ""
    Write-Host " Error output:" -ForegroundColor $ColorScheme.Error
    Write-Host ""

    # Show error output in formatted box
    $errorLines = $ErrorOutput -split "`n" | Select-Object -Last $Config.UI.LogTailLines

    Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host ($Box.Horizontal * $Config.UI.LogBoxWidth) -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Muted

    foreach ($line in $errorLines) {
        $trimmed = $line.Trim()
        $maxLength = $Config.UI.LogBoxWidth - 2
        if ($trimmed.Length -gt $maxLength) {
            $trimmed = $trimmed.Substring(0, $maxLength)
        }
        $padding = [Math]::Max(0, $maxLength - $trimmed.Length)

        Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Muted
        Write-Host $trimmed -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host (" " * $padding) -NoNewline
        Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Muted
    }

    Write-Host "$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host ($Box.Horizontal * $Config.UI.LogBoxWidth) -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Muted

    # Cleanup resources
    Write-Host ""
    Write-Host " Cleaning up resources..." -ForegroundColor $ColorScheme.Warning

    foreach ($container in $CleanupContainers) {
        docker rm -f $container 2>&1 | Out-Null
    }
    docker volume rm $($Config.Docker.DatabaseVolume) 2>&1 | Out-Null
    docker network rm $($Config.Docker.Network) 2>&1 | Out-Null

    Write-Host " $([char]0x2713) Cleanup complete" -ForegroundColor $ColorScheme.Success

    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Updates a single line in the deployment progress box.
.PARAMETER LineOffset
    Line offset (0 for Database, 1 for Server).
.PARAMETER Task
    Task name to display.
.PARAMETER Status
    Status text to display.
.PARAMETER StatusType
    Type of status (Info, Success, Error, Waiting).
.PARAMETER Width
    Width of the progress box.
.PARAMETER BaseCursorPos
    Base cursor position for calculating line position.
#>
function Update-ProgressLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 10)]
        [int]$LineOffset,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Task,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Status,

        [Parameter()]
        [ValidateSet("Info", "Success", "Error", "Waiting")]
        [string]$StatusType = "Info",

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.DefaultWidth,

        [Parameter(Mandatory)]
        $BaseCursorPos
    )

    $statusColor = switch ($StatusType) {
        "Success" { $ColorScheme.Success }
        "Error" { $ColorScheme.Error }
        "Waiting" { $ColorScheme.Muted }
        default { $ColorScheme.Info }
    }

    $statusIcon = switch ($StatusType) {
        "Success" { [char]0x2713 }  # $([char]0x2713)
        "Error" { [char]0x2717 }    # $([char]0x2717)
        "Waiting" { " " }
        default { [char]0x25CF }    # $([char]0x25CF)
    }

    # Move cursor to the specific line
    $targetPos = $BaseCursorPos
    $targetPos.Y = $BaseCursorPos.Y - 3 + $LineOffset
    $targetPos.X = 0
    $Host.UI.RawUI.CursorPosition = $targetPos

    # Redraw the entire line
    $taskLine = "  $Task"
    $statusLine = "$statusIcon $Status"
    # Width calculation: 70 total - 2 (borders) - 2 (padding left) - 2 (padding right) = 64 for content
    $contentWidth = $Width - 4
    $padding = [Math]::Max(0, $contentWidth - $taskLine.Length - $statusLine.Length)

    Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host $taskLine -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host (" " * $padding) -NoNewline
    Write-Host $statusLine -NoNewline -ForegroundColor $statusColor
    Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
}

function Update-ConfirmButtons {
    param(
        [int]$SelectedButton,
        [int]$ButtonLineNumber,
        [int]$Width
    )

    $buttonWidth = 12
    $spacing = 4
    $totalButtonWidth = ($buttonWidth * 2) + $spacing
    $leftPadding = [Math]::Floor(($Width - $totalButtonWidth) / 2)

    $cursorPos = $Host.UI.RawUI.CursorPosition
    $cursorPos.X = 0
    $cursorPos.Y = $ButtonLineNumber
    $Host.UI.RawUI.CursorPosition = $cursorPos

    Write-Host (" " * $leftPadding) -NoNewline

    # Yes button
    if ($SelectedButton -eq 0) {
        Write-Host "    Yes     " -ForegroundColor $ColorScheme.Highlight -BackgroundColor $ColorScheme.Primary -NoNewline
    } else {
        Write-Host "    Yes     " -ForegroundColor $ColorScheme.Primary -NoNewline
    }

    Write-Host (" " * $spacing) -NoNewline

    # No button
    if ($SelectedButton -eq 1) {
        Write-Host "     No     " -ForegroundColor $ColorScheme.Highlight -BackgroundColor $ColorScheme.Primary -NoNewline
    } else {
        Write-Host "     No     " -ForegroundColor $ColorScheme.Primary -NoNewline
    }

    # Clear rest of line
    Write-Host (" " * ($Width - $leftPadding - $totalButtonWidth))
}

<#
.SYNOPSIS
    Shows a confirmation dialog with Yes/No buttons.
.PARAMETER Title
    Dialog title.
.PARAMETER Message
    Confirmation message.
.PARAMETER Width
    Width of the dialog box.
.OUTPUTS
    Boolean - true if Yes selected, false otherwise.
#>
function Show-Confirm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateRange(20, 200)]
        [int]$Width = $Config.UI.DefaultWidth
    )

    $selectedButton = 1  # 0 = Yes, 1 = No (default to No for safety)
    $previousButton = -1

    Clear-Host
    Write-Host ""
    Write-Host ""

    Draw-Box -Title $Title -Lines @($Message, "", "Are you sure?") -Width $Width -BorderColor $ColorScheme.Primary -TextColor $ColorScheme.Info

    Write-Host ""

    # Initial button draw
    $buttonLineNumber = $Host.UI.RawUI.CursorPosition.Y
    Update-ConfirmButtons -SelectedButton $selectedButton -ButtonLineNumber $buttonLineNumber -Width $Width

    Write-Host ""
    Write-Host " Use " -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "$([char]0x2190) $([char]0x2192)" -NoNewline -ForegroundColor $ColorScheme.Primary  # ← →
    Write-Host " to select, " -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host "ENTER" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host " to confirm" -ForegroundColor $ColorScheme.Muted

    while ($true) {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        $previousButton = $selectedButton

        switch ($key.VirtualKeyCode) {
            37 { # Left arrow
                $selectedButton = 0
            }
            39 { # Right arrow
                $selectedButton = 1
            }
            13 { # Enter
                return $selectedButton -eq 0
            }
            27 { # Escape
                return $false
            }
        }

        # Only redraw if selection changed
        if ($previousButton -ne $selectedButton) {
            Update-ConfirmButtons -SelectedButton $selectedButton -ButtonLineNumber $buttonLineNumber -Width $Width
        }
    }
}

#endregion

#region Input and Interaction Functions

<#
.SYNOPSIS
    Waits for user to press ENTER key.
.PARAMETER Prompt
    The prompt message to display.
#>
function Wait-Enter {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Prompt = "Press ENTER to continue"
    )

    Write-Host " $Prompt..." -NoNewline -ForegroundColor $ColorScheme.Muted
    $cursorPos = $Host.UI.RawUI.CursorPosition

    do {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ""
            break
        }
        $Host.UI.RawUI.CursorPosition = $cursorPos
    } while ($true)
}

<#
.SYNOPSIS
    Reads user input with optional default value.
.PARAMETER Prompt
    The prompt message to display.
.PARAMETER Default
    Default value if user presses ENTER without input.
.OUTPUTS
    String containing user input or default value.
#>
function Read-Input {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Prompt,

        [Parameter()]
        [string]$Default = ""
    )

    Write-Host " $Prompt" -ForegroundColor $ColorScheme.Info

    if ($Default) {
        Write-Host " [" -NoNewline -ForegroundColor $ColorScheme.Muted
        Write-Host "Press ENTER for default (" -NoNewline -ForegroundColor $ColorScheme.Muted
        Write-Host $Default -NoNewline -ForegroundColor $ColorScheme.Primary
        Write-Host ")" -NoNewline -ForegroundColor $ColorScheme.Muted
        Write-Host "] > " -NoNewline -ForegroundColor $ColorScheme.Muted
    } else {
        Write-Host " > " -NoNewline -ForegroundColor $ColorScheme.Primary
    }

    # Show cursor during input
    try { [Console]::CursorVisible = $true } catch { }

    $userInput = Read-Host

    # Hide cursor after input
    try { [Console]::CursorVisible = $false } catch { }

    if ([string]::IsNullOrWhiteSpace($userInput)) {
        return $Default
    }
    return $userInput
}

#endregion

#region Docker Utility Functions

<#
.SYNOPSIS
    Checks if a Docker container exists (running or stopped).
.PARAMETER ContainerName
    Name of the container to check.
.OUTPUTS
    Boolean indicating if container exists.
#>
function Test-ContainerExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName
    )

    $exists = docker ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    return $exists -eq $ContainerName
}

<#
.SYNOPSIS
    Checks if a Docker container is currently running.
.PARAMETER ContainerName
    Name of the container to check.
.OUTPUTS
    Boolean indicating if container is running.
#>
function Test-ContainerRunning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName
    )

    $status = docker ps --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    return $status -eq $ContainerName
}

<#
.SYNOPSIS
    Checks if Docker is installed and running.
.OUTPUTS
    Boolean indicating if Docker is available.
#>
function Test-DockerAvailable {
    [CmdletBinding()]
    param()

    # Check if Docker is installed
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $dockerInstalled) {
        Show-MessageBox -Title "Docker Not Found" -Message @(
            "Docker is not installed on this system.",
            "Please install Docker Desktop from:",
            "https://www.docker.com/products/docker-desktop"
        ) -Type "Error"
        return $false
    }

    # Check if Docker daemon is running
    try {
        docker ps 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw
        }
    } catch {
        Show-MessageBox -Title "Docker Not Running" -Message @(
            "Docker is installed but not running.",
            "Please start Docker Desktop and try again."
        ) -Type "Error"
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Checks if a TCP port is available.
.PARAMETER Port
    The port number to check.
.OUTPUTS
    Hashtable with availability status and process information.
#>
function Test-PortAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    try {
        $tcpConnections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                          Where-Object { $_.LocalPort -eq $Port }

        if ($tcpConnections) {
            $processId = $tcpConnections[0].OwningProcess
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue

            return @{
                Available = $false
                ProcessId = $processId
                ProcessName = if ($process) { $process.ProcessName } else { "Unknown" }
                ProcessPath = if ($process) { $process.Path } else { "Unknown" }
            }
        }

        return @{
            Available = $true
        }
    }
    catch {
        # If Get-NetTCPConnection fails, assume port is available
        return @{
            Available = $true
        }
    }
}

<#
.SYNOPSIS
    Checks if all required ports are available.
.OUTPUTS
    Boolean indicating if all ports are available.
#>
function Test-RequiredPorts {
    [CmdletBinding()]
    param()

    $requiredPorts = @(
        @{ Port = $Config.Ports.Gateway; Description = "Gateway" }
        @{ Port = $Config.Ports.Blaze; Description = "Blaze" }
        @{ Port = $Config.Ports.Game; Description = "Game" }
        @{ Port = $Config.Ports.PostgreSQL; Description = "PostgreSQL" }
    )

    $portsInUse = @()

    foreach ($portInfo in $requiredPorts) {
        $result = Test-PortAvailable -Port $portInfo.Port
        if (-not $result.Available) {
            $portsInUse += @{
                Port = $portInfo.Port
                Description = $portInfo.Description
                ProcessId = $result.ProcessId
                ProcessName = $result.ProcessName
                ProcessPath = $result.ProcessPath
            }
        }
    }

    if ($portsInUse.Count -gt 0) {
        $messages = @("The following ports are already in use:", " ")

        foreach ($portInfo in $portsInUse) {
            $messages += "Port $($portInfo.Port) ($($portInfo.Description)):"
            $messages += "  Process: $($portInfo.ProcessName) (PID: $($portInfo.ProcessId))"

            if ($portInfo.ProcessPath -ne "Unknown") {
                $pathDisplay = $portInfo.ProcessPath
                if ($pathDisplay.Length -gt 60) {
                    $pathDisplay = "..." + $pathDisplay.Substring($pathDisplay.Length - 57)
                }
                $messages += "  Path: $pathDisplay"
            }
            $messages += " "
        }

        $messages += "Please close these applications before continuing."
        Show-MessageBox -Title "Port Conflict" -Message $messages -Type "Error"
        return $false
    }

    return $true
}

#endregion

#region Server Management Functions

<#
.SYNOPSIS
    Installs and starts the Pamplona Future server.
.DESCRIPTION
    Handles full server deployment including Docker container creation,
    configuration input, health checks, and error handling.
#>
function Start-Server {
    [CmdletBinding()]
    param()

    Draw-Header -Title "Install and Start Server"

    if (-not (Test-DockerAvailable)) {
        return
    }

    Write-Host " $([char]0x2713) Docker is available" -ForegroundColor $ColorScheme.Success
    Write-Host ""

    # Check if server already exists
    if (Test-ContainerExists $Config.Docker.ServerContainer) {
        if (Test-ContainerRunning $Config.Docker.ServerContainer) {
            Show-MessageBox -Title "Already Running" -Message @(
                "Server is already installed and running."
            ) -Type "Info"
            return
        } else {
            Draw-Box -Title "Server Found" -Lines @(
                "Server is installed but not running.",
                "",
                "Starting containers..."
            ) -BorderColor $ColorScheme.Primary -TextColor $ColorScheme.Info

            docker start $($Config.Docker.DatabaseContainer) 2>$null
            docker start $($Config.Docker.ServerContainer) 2>$null
            Start-Sleep -Seconds 2

            Write-Host ""
            Write-Host " $([char]0x2713) Server started successfully!" -ForegroundColor $ColorScheme.Success
            Wait-Enter
            return
        }
    }

    if (-not (Test-RequiredPorts)) {
        return
    }

    Write-Host " $([char]0x2713) All required ports are available" -ForegroundColor $ColorScheme.Success
    Write-Host ""

    # Get game path
    $gamePath = Read-Input -Prompt "Mirror's Edge Catalyst installation path:" -Default $Config.DefaultGamePath

    if (-not (Test-Path $gamePath)) {
        Show-MessageBox -Title "Invalid Path" -Message @(
            "The specified path does not exist:",
            "",
            $gamePath,
            "",
            "Please check the path and try again."
        ) -Type "Error"
        return
    }

    Write-Host ""
    $personaUsername = Read-Input -Prompt "Player name:" -Default $Config.Defaults.PlayerName

    Write-Host ""
    Write-Host " Advanced Settings " -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host "(optional, press ENTER to skip):" -ForegroundColor $ColorScheme.Muted

    Write-Host ""
    Write-Host " Database Settings:" -ForegroundColor $ColorScheme.Info
    $dbUser = Read-Input -Prompt "  Username:" -Default $Config.Defaults.DbUser
    $dbPassword = Read-Input -Prompt "  Password:" -Default $Config.Defaults.DbPassword
    $dbName = Read-Input -Prompt "  Database:" -Default $Config.Defaults.DbName

    Write-Host ""
    Write-Host " Player IDs:" -ForegroundColor $ColorScheme.Info
    $userId = Read-Input -Prompt "  User ID:" -Default $Config.Defaults.UserId
    $personaId = Read-Input -Prompt "  Persona ID:" -Default $Config.Defaults.PersonaId

    Write-Host ""
    Write-Host " $([char]0x2713) Configuration complete" -ForegroundColor $ColorScheme.Success
    Start-Sleep -Seconds 1

    # Start deployment
    Draw-Header -Title "Deployment Progress" -Width $Config.UI.DefaultWidth

    # Create network if it doesn't exist
    $networkExists = docker network ls --filter "name=^$($Config.Docker.Network)$" --format "{{.Name}}" 2>$null
    if ($networkExists -ne $Config.Docker.Network) {
        docker network create $($Config.Docker.Network) 2>&1 | Out-Null
    }

    $boxWidth = $Config.UI.DefaultWidth

    # Draw complete progress box
    Write-Host "$($Box.TopLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.Horizontal * ($boxWidth - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.TopRight)" -ForegroundColor $ColorScheme.Primary

    # Database line
    $taskLine = "  Database"
    $statusLine = "$([char]0x25CF) Starting..."
    $contentWidth = $boxWidth - 4
    $padding = [Math]::Max(0, $contentWidth - $taskLine.Length - $statusLine.Length)

    Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host $taskLine -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host (" " * $padding) -NoNewline
    Write-Host $statusLine -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary

    # Server line
    $taskLine = "  Server"
    $statusLine = "  Waiting..."
    $padding = [Math]::Max(0, $contentWidth - $taskLine.Length - $statusLine.Length)

    Write-Host "$($Box.Vertical) " -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host $taskLine -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host (" " * $padding) -NoNewline
    Write-Host $statusLine -NoNewline -ForegroundColor $ColorScheme.Muted
    Write-Host " $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary

    Write-Host "$($Box.BottomLeft)" -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host ($Box.Horizontal * ($boxWidth - 2)) -NoNewline -ForegroundColor $ColorScheme.Primary
    Write-Host "$($Box.BottomRight)" -ForegroundColor $ColorScheme.Primary

    # Store initial cursor position
    $initialCursorPos = $Host.UI.RawUI.CursorPosition

    # Start database container
    $dbResult = docker run -d `
      --name $($Config.Docker.DatabaseContainer) `
      --restart unless-stopped `
      --network $($Config.Docker.Network) `
      -e POSTGRES_USER=$dbUser `
      -e POSTGRES_PASSWORD=$dbPassword `
      -e POSTGRES_DB=$dbName `
      -v "$($Config.Docker.DatabaseVolume):/var/lib/postgresql/data" `
      $($Config.Docker.DatabaseImage) 2>&1

    if ($LASTEXITCODE -ne 0) {
        Update-ProgressLine -LineOffset 0 -Task "Database" -Status "Failed" -StatusType "Error" -BaseCursorPos $initialCursorPos
        $Host.UI.RawUI.CursorPosition = $initialCursorPos

        Show-DockerRunError -ErrorTitle "Database" -ErrorOutput $dbResult `
            -CleanupContainers @($Config.Docker.DatabaseContainer)
        return
    }

    # Check DB health
    $waitInterval = 1
    $elapsed = 0
    $dbReady = $false

    while ($elapsed -lt $Config.Timeouts.DatabaseReady) {
        Start-Sleep -Seconds $waitInterval
        $elapsed += $waitInterval

        if (-not (Test-ContainerRunning $Config.Docker.DatabaseContainer)) {
            Update-ProgressLine -LineOffset 0 -Task "Database" -Status "Stopped" -StatusType "Error" -BaseCursorPos $initialCursorPos
            $Host.UI.RawUI.CursorPosition = $initialCursorPos

            Show-DeploymentError -ErrorTitle "Database" `
                -ErrorMessage "Container stopped unexpectedly. Last $($Config.UI.LogTailLines) log lines:" `
                -ContainerName $Config.Docker.DatabaseContainer `
                -CleanupContainers @($Config.Docker.DatabaseContainer)
            return
        }

        $null = docker exec $($Config.Docker.DatabaseContainer) pg_isready -U $dbUser -d $dbName 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dbReady = $true
            break
        }
    }

    if (-not $dbReady) {
        Update-ProgressLine -LineOffset 0 -Task "Database" -Status "Timeout" -StatusType "Error" -BaseCursorPos $initialCursorPos
        $Host.UI.RawUI.CursorPosition = $initialCursorPos

        Show-DeploymentError -ErrorTitle "Database" `
            -ErrorMessage "Database failed to become ready in time. Last $($Config.UI.LogTailLines) log lines:" `
            -ContainerName $Config.Docker.DatabaseContainer `
            -CleanupContainers @($Config.Docker.DatabaseContainer)
        return
    }

    # Update database status to Ready
    Update-ProgressLine -LineOffset 0 -Task "Database" -Status "Ready" -StatusType "Success" -BaseCursorPos $initialCursorPos

    # Update server status to Starting
    Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Starting..." -StatusType "Info" -BaseCursorPos $initialCursorPos

    # Start server container
    $serverResult = docker run -d `
      --name $($Config.Docker.ServerContainer) `
      --restart unless-stopped `
      --network $($Config.Docker.Network) `
      -p "$($Config.Ports.Gateway):$($Config.Ports.Gateway)" `
      -p "$($Config.Ports.Blaze):$($Config.Ports.Blaze)" `
      -p "$($Config.Ports.Game):$($Config.Ports.Game)" `
      -e GATEWAY_PORT=$($Config.Ports.Gateway) `
      -e BLAZE_PORT=$($Config.Ports.Blaze) `
      -e POSTGRES_USER=$dbUser `
      -e POSTGRES_PASSWORD=$dbPassword `
      -e POSTGRES_DB=$dbName `
      -e POSTGRES_HOSTNAME=$($Config.Docker.DatabaseContainer) `
      -e POSTGRES_PORT=$($Config.Ports.PostgreSQL) `
      -e HOSTNAME=localhost `
      -e GAME_PATH=$($Config.Docker.MitmVolume) `
      -e USER_ID=$userId `
      -e PERSONA_ID=$personaId `
      -e PERSONA_USERNAME=$personaUsername `
      -v "${gamePath}:$($Config.Docker.MitmVolume)" `
      $($Config.Docker.ServerImage) 2>&1

    if ($LASTEXITCODE -ne 0) {
        Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Failed" -StatusType "Error" -BaseCursorPos $initialCursorPos
        $Host.UI.RawUI.CursorPosition = $initialCursorPos

        Show-DockerRunError -ErrorTitle "Server" -ErrorOutput $serverResult `
            -CleanupContainers @($Config.Docker.ServerContainer, $Config.Docker.DatabaseContainer)
        return
    }

    # Check server health
    $checkInterval = 1
    $serverHealthy = $false

    for ($i = 0; $i -lt $Config.Timeouts.ServerHealthChecks; $i++) {
        Start-Sleep -Seconds $checkInterval

        $serverStatus = docker inspect --format='{{.State.Status}}' $($Config.Docker.ServerContainer) 2>$null
        $currentRestartCount = docker inspect --format='{{.RestartCount}}' $($Config.Docker.ServerContainer) 2>$null

        # Check if server is restarting
        if ($serverStatus -match "restarting" -or ($currentRestartCount -and $currentRestartCount -match '^\d+$' -and [int]$currentRestartCount -gt 0)) {
            Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Restarting" -StatusType "Error" -BaseCursorPos $initialCursorPos
            $Host.UI.RawUI.CursorPosition = $initialCursorPos

            Show-DeploymentError -ErrorTitle "Server" `
                -ErrorMessage "Server is constantly restarting. Last $($Config.UI.LogTailLines) log lines:" `
                -ContainerName $Config.Docker.ServerContainer `
                -CleanupContainers @($Config.Docker.ServerContainer, $Config.Docker.DatabaseContainer)
            return
        }

        # Check if server exited
        if ($serverStatus -match "exited") {
            Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Exited" -StatusType "Error" -BaseCursorPos $initialCursorPos
            $Host.UI.RawUI.CursorPosition = $initialCursorPos

            Show-DeploymentError -ErrorTitle "Server" `
                -ErrorMessage "Server exited unexpectedly. Last $($Config.UI.LogTailLines) log lines:" `
                -ContainerName $Config.Docker.ServerContainer `
                -CleanupContainers @($Config.Docker.ServerContainer, $Config.Docker.DatabaseContainer)
            return
        }

        # Check if server is running and has been running long enough
        if ($serverStatus -match "running" -and $i -ge $Config.Timeouts.ServerMinRuntime) {
            $serverHealthy = $true
            break
        }
    }

    if (-not $serverHealthy) {
        Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Timeout" -StatusType "Error" -BaseCursorPos $initialCursorPos
        $Host.UI.RawUI.CursorPosition = $initialCursorPos

        Show-DeploymentError -ErrorTitle "Server" `
            -ErrorMessage "Server failed to start in time. Last $($Config.UI.LogTailLines) log lines:" `
            -ContainerName $Config.Docker.ServerContainer `
            -CleanupContainers @($Config.Docker.ServerContainer, $Config.Docker.DatabaseContainer)
        return
    }

    # Update server status to Running
    Update-ProgressLine -LineOffset 1 -Task "Server" -Status "Running" -StatusType "Success" -BaseCursorPos $initialCursorPos

    # Move cursor to end
    $Host.UI.RawUI.CursorPosition = $initialCursorPos

    Write-Host ""
    Write-Host ""
    Write-Host " $([char]0x2713) " -NoNewline -ForegroundColor $ColorScheme.Success
    Write-Host "Deployment complete! " -NoNewline -ForegroundColor $ColorScheme.Success
    Write-Host "You can now connect to the server." -ForegroundColor $ColorScheme.Info
    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Displays the current status of server containers.
#>
function Get-ServerStatus {
    [CmdletBinding()]
    param()

    Draw-Header -Title "Server Status"

    if (-not (Test-DockerAvailable)) {
        return
    }

    $serverRunning = Test-ContainerRunning $Config.Docker.ServerContainer
    $dbRunning = Test-ContainerRunning $Config.Docker.DatabaseContainer

    Write-Host ""
    Write-Host "  Container Status:" -ForegroundColor $ColorScheme.Info
    Write-Host ""

    if ($serverRunning) {
        Write-Host "    Server      : " -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host "Running $([char]0x2713)" -ForegroundColor $ColorScheme.Success
    } else {
        Write-Host "    Server      : " -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host "Not running $([char]0x2717)" -ForegroundColor $ColorScheme.Muted
    }

    if ($dbRunning) {
        Write-Host "    Database    : " -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host "Running $([char]0x2713)" -ForegroundColor $ColorScheme.Success
    } else {
        Write-Host "    Database    : " -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host "Not running $([char]0x2717)" -ForegroundColor $ColorScheme.Muted
    }

    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Displays server logs.
#>
function Show-Logs {
    [CmdletBinding()]
    param()

    Draw-Header -Title "Server Logs (last 100 lines)"

    if (-not (Test-DockerAvailable)) {
        return
    }

    Write-Host ""

    if (Test-ContainerRunning $Config.Docker.ServerContainer) {
        docker logs --tail 100 $($Config.Docker.ServerContainer)
        Write-Host ""
        Wait-Enter "Press ENTER to return to menu"
    } else {
        Show-MessageBox -Title "Server Not Running" -Message @(
            "Server is not running. No logs available."
        ) -Type "Warning"
    }
}

<#
.SYNOPSIS
    Stops and removes all server resources.
.DESCRIPTION
    Removes Docker containers, volumes, and network after confirmation.
#>
function Stop-And-Remove-Server {
    [CmdletBinding()]
    param()

    Draw-Header -Title "Stop and Remove Server"

    if (-not (Test-DockerAvailable)) {
        return
    }

    if (-not (Test-ContainerExists $Config.Docker.ServerContainer)) {
        Show-MessageBox -Title "Server Not Found" -Message @(
            "Server is not installed."
        ) -Type "Warning"
        return
    }

    if (-not (Show-Confirm -Title "Confirm Removal" -Message "This will stop and remove all server artifacts and depencencies.")) {
        Show-MessageBox -Title "Cancelled" -Message @(
            "Operation cancelled."
        ) -Type "Info"
        return
    }

    Clear-Host
    Draw-Header -Title "Removing Server"

    Write-Host ""
    Write-Host " Stopping containers..." -ForegroundColor $ColorScheme.Info
    docker stop $($Config.Docker.ServerContainer) 2>&1 | Out-Null
    docker stop $($Config.Docker.DatabaseContainer) 2>&1 | Out-Null
    Write-Host " $([char]0x2713) Containers stopped" -ForegroundColor $ColorScheme.Success
    Start-Sleep -Seconds 1

    Write-Host ""
    Write-Host " Removing resources..." -ForegroundColor $ColorScheme.Info
    docker rm -f $($Config.Docker.ServerContainer) 2>&1 | Out-Null
    docker rm -f $($Config.Docker.DatabaseContainer) 2>&1 | Out-Null
    docker volume rm $($Config.Docker.DatabaseVolume) 2>&1 | Out-Null
    docker network rm $($Config.Docker.Network) 2>&1 | Out-Null
    Write-Host " $([char]0x2713) Resources removed" -ForegroundColor $ColorScheme.Success

    Write-Host ""
    Write-Host ""
    Write-Host " $([char]0x2713) " -NoNewline -ForegroundColor $ColorScheme.Success
    Write-Host "Server has been removed successfully." -ForegroundColor $ColorScheme.Success
    Write-Host ""
    Wait-Enter
}

<#
.SYNOPSIS
    Displays credits and acknowledgements.
#>
function Show-Credits {
    [CmdletBinding()]
    param()

    Draw-Header -Title "Credits"

    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "PAMPLONA FUTURE AIO" -ForegroundColor $ColorScheme.Success
    Write-Host ""
    Write-Host "  Thanks to:" -ForegroundColor $ColorScheme.Info
    Write-Host ""
    Write-Host "    $([char]0x2022) " -NoNewline -ForegroundColor $ColorScheme.Primary  # •
    Write-Host "ploxxxy " -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host "(core development)" -ForegroundColor $ColorScheme.Muted
    Write-Host ""
    Write-Host "    $([char]0x2022) " -NoNewline -ForegroundColor $ColorScheme.Primary  # •
    Write-Host "iwanmikhajlov " -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host "(dockerization & scripting)" -ForegroundColor $ColorScheme.Muted
    Write-Host ""
    Write-Host "    $([char]0x2022) " -NoNewline -ForegroundColor $ColorScheme.Primary  # •
    Write-Host "DICE & EA " -NoNewline -ForegroundColor $ColorScheme.Info
    Write-Host "(for shutting down servers, bruh)" -ForegroundColor $ColorScheme.Muted
    Write-Host ""

    Wait-Enter "Press ENTER to return to menu"
}

#endregion

#region Main Application Loop

# Main loop
$menuItems = @(
    "Install and start server",
    "Check server status",
    "View server logs",
    "Stop and remove server",
    "Credits",
    "Exit"
)

while ($true) {
    $selection = Read-MenuSelection -Items $menuItems

    if ($selection -eq -1 -or $selection -eq 5) {
        Clear-Host
        Write-Host ""
        Write-Host ""
        Write-Host "  $($Box.TopLeft)$($Box.Horizontal * 40)$($Box.TopRight)" -ForegroundColor $ColorScheme.Primary
        Write-Host "  $($Box.Vertical)$(' ' * 40)$($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
        Write-Host "  $($Box.Vertical)            " -NoNewline -ForegroundColor $ColorScheme.Primary
        Write-Host "   Goodbye!" -NoNewline -ForegroundColor $ColorScheme.Info
        Write-Host "                 $($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
        Write-Host "  $($Box.Vertical)$(' ' * 40)$($Box.Vertical)" -ForegroundColor $ColorScheme.Primary
        Write-Host "  $($Box.BottomLeft)$($Box.Horizontal * 40)$($Box.BottomRight)" -ForegroundColor $ColorScheme.Primary
        Write-Host ""
        Write-Host ""

        # Restore cursor visibility
        try {
            [Console]::CursorVisible = $true
        } catch {
            # Ignore if not supported
        }

        Start-Sleep -Seconds 1
        exit
    }

    switch ($selection) {
        0 { Start-Server }
        1 { Get-ServerStatus }
        2 { Show-Logs }
        3 { Stop-And-Remove-Server }
        4 { Show-Credits }
    }
}
