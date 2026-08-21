#Requires -Module MicrosoftTeams
<#
.SYNOPSIS
    Bulk-adds users to an existing Microsoft Team as Members or Owners from a CSV file.

.DESCRIPTION
    Prompts for the target team name, confirms the correct team is selected before
    making any changes, then imports users from a CSV and adds them with the role
    specified in the Role column.

.NOTES
    CSV format expected (place at C:\users.csv by default, or provide your own path):

    Email                   | Role
    ------------------------|--------
    john.smith@domain.com   | Member
    jane.doe@domain.com     | Owner
#>

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
$DefaultCsvPath = "C:\users.csv"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        Add People To Team  v1.0          ║" -ForegroundColor Cyan
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

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
Write-Banner
Connect-TeamsIfNeeded

# --- Find the team ---
$TeamName = Read-Host "Enter the name of the team"
if ([string]::IsNullOrWhiteSpace($TeamName)) {
    Write-Host "Team name cannot be empty. Exiting." -ForegroundColor Red
    return
}

$matches = Get-Team -DisplayName $TeamName

if (-not $matches -or $matches.Count -eq 0) {
    Write-Host "✖  No team found matching '$TeamName'." -ForegroundColor Red
    return
}

if ($matches.Count -gt 1) {
    Write-Host ""
    Write-Host "Multiple teams matched '$TeamName':" -ForegroundColor Yellow
    for ($i = 0; $i -lt $matches.Count; $i++) {
        Write-Host "  [$($i + 1)] $($matches[$i].DisplayName)  (GroupId: $($matches[$i].GroupId))"
    }
    $selection = Read-Host "Enter the number of the correct team"
    $index = [int]$selection - 1

    if ($index -lt 0 -or $index -ge $matches.Count) {
        Write-Host "✖  Invalid selection. Exiting." -ForegroundColor Red
        return
    }
    $team = $matches[$index]
}
else {
    $team = $matches[0]
}

# --- Confirm before making changes ---
Write-Host ""
Write-Host "Found team:" -ForegroundColor Yellow
Write-Host "  Name    : $($team.DisplayName)"
Write-Host "  GroupId : $($team.GroupId)"
Write-Host ""
$confirm = Read-Host "Is this the correct team? (Y/N)"
if ($confirm -notmatch '^(Y|y)') {
    Write-Host "Cancelled — no changes made." -ForegroundColor Yellow
    return
}

# --- CSV import ---
$csvPath = Read-Host "Enter CSV path (press Enter for default: $DefaultCsvPath)"
if ([string]::IsNullOrWhiteSpace($csvPath)) {
    $csvPath = $DefaultCsvPath
}

if (-not (Test-Path $csvPath)) {
    Write-Host "✖  CSV file not found at: $csvPath" -ForegroundColor Red
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

# --- Add users ---
Write-Host ""
Write-Host "Adding $($users.Count) user(s) to '$($team.DisplayName)'..." -ForegroundColor Yellow
Write-Host ""

$added      = 0
$failed     = 0
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
Write-Host "Team          : $($team.DisplayName)"
Write-Host "Added         : $added"
Write-Host "Failed        : $failed"
if ($failedList.Count -gt 0) {
    Write-Host "Failed users  : $($failedList -join ', ')"
}
Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
