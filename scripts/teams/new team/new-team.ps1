#Requires -Module MicrosoftTeams
<#
.SYNOPSIS
    Creates a new Microsoft Team and optionally bulk-adds members/owners from a CSV file.

.DESCRIPTION
    Prompts for a team name and description, creates the team, waits for provisioning
    to complete, then optionally imports a CSV of users and adds them as Members or
    Owners based on a Role column.

.NOTES
    CSV format expected (place at C:\users.csv by default, or provide your own path):

    Email                   | Role
    ------------------------|--------
    john.smith@domain.com   | Member
    jane.doe@domain.com     | Owner
    bob.jones@domain.com    | Member
#>

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$DefaultCsvPath      = "C:\users.csv"
$ProvisioningWaitSec = 15   # Seconds to wait for the team to finish provisioning

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       Microsoft Team Creator  v1.0       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Connect-TeamsIfNeeded {
    if (-not (Get-Module -ListAvailable -Name MicrosoftTeams)) {
        Write-Host "MicrosoftTeams module not found. Installing..." -ForegroundColor Yellow
        Install-Module MicrosoftTeams -Force -Scope CurrentUser
    }

    try {
        Get-CsTeamsClientConfiguration -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Yellow
        Connect-MicrosoftTeams | Out-Null
    }
}

function Show-ProvisioningProgress {
    param([int]$Seconds)

    for ($i = 1; $i -le $Seconds; $i++) {
        $percent = [int](($i / $Seconds) * 100)
        Write-Progress -Activity "Provisioning Team" -Status "$i / $Seconds seconds" -PercentComplete $percent
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity "Provisioning Team" -Completed
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Banner
Connect-TeamsIfNeeded

# --- Team details ---
$TeamName = Read-Host "Enter the name of the team"
if ([string]::IsNullOrWhiteSpace($TeamName)) {
    Write-Host "Team name cannot be empty. Exiting." -ForegroundColor Red
    return
}

$TeamDescription = Read-Host "Enter the description"

Write-Host ""
Write-Host "You are about to create:" -ForegroundColor Yellow
Write-Host "  Name        : $TeamName"
Write-Host "  Description : $TeamDescription"
Write-Host ""
$confirm = Read-Host "Proceed with team creation? (Y/N)"
if ($confirm -notmatch '^(Y|y)') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    return
}

# --- Create the team ---
try {
    $team = New-Team -DisplayName $TeamName -Description $TeamDescription -Visibility Private -ErrorAction Stop
    Write-Host "✔  Team '$TeamName' created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "✖  Failed to create team: $($_.Exception.Message)" -ForegroundColor Red
    return
}

Show-ProvisioningProgress -Seconds $ProvisioningWaitSec

# --- Bulk add members/owners ---
$bulkAdd = Read-Host "Add Members/Owners from CSV? (Y/N)"

if ($bulkAdd -match '^(Y|y)') {

    $csvPath = Read-Host "Enter CSV path (press Enter for default: $DefaultCsvPath)"
    if ([string]::IsNullOrWhiteSpace($csvPath)) {
        $csvPath = $DefaultCsvPath
    }

    if (-not (Test-Path $csvPath)) {
        Write-Host "✖  CSV file not found at: $csvPath" -ForegroundColor Red
        Write-Host "Team was created, but no users were added." -ForegroundColor Yellow
        return
    }

    $users = Import-Csv -Path $csvPath

    if (-not $users -or $users.Count -eq 0) {
        Write-Host "✖  CSV file is empty or could not be read." -ForegroundColor Red
        return
    }

    if (-not ($users[0].PSObject.Properties.Name -contains 'Email') -or
        -not ($users[0].PSObject.Properties.Name -contains 'Role')) {
        Write-Host "✖  CSV must contain 'Email' and 'Role' columns." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Adding $($users.Count) user(s) to '$TeamName'..." -ForegroundColor Yellow
    Write-Host ""

    $added   = 0
    $failed  = 0
    $failedList = @()

    foreach ($user in $users) {

        $email = $user.Email.Trim()
        $role  = $user.Role.Trim()

        if ($role -notin @('Member', 'Owner')) {
            Write-Host "✖  Skipped $email — invalid role '$role' (must be Member or Owner)" -ForegroundColor Red
            $failed++
            $failedList += $email
            continue
        }

        try {
            Add-TeamUser -GroupId $team.GroupId -User $email -Role $role -ErrorAction Stop
            Write-Host "✔  Added $email as $role" -ForegroundColor Green
            $added++
        }
        catch {
            Write-Host "✖  Failed to add $email — $($_.Exception.Message)" -ForegroundColor Red
            $failed++
            $failedList += $email
        }
    }

    Write-Host ""
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "Team          : $TeamName"
    Write-Host "Added         : $added"
    Write-Host "Failed        : $failed"
    if ($failedList.Count -gt 0) {
        Write-Host "Failed users  : $($failedList -join ', ')"
    }
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
}
else {
    Write-Host ""
    Write-Host "Done! Team '$TeamName' created with no bulk-added members." -ForegroundColor Green
}
