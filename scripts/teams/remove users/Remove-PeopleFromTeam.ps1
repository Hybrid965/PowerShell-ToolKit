#Requires -Module MicrosoftTeams
<#
.SYNOPSIS
    Bulk-removes users from an existing Microsoft Team, either from a CSV file
    or a single email entered manually.

.DESCRIPTION
    Prompts for the target team name, confirms the correct team is selected before
    making any changes, then removes users either from a CSV file (Email column,
    Role column optional/ignored) or a single email typed in directly.

.NOTES
    CSV format expected (place at C:\users.csv by default, or provide your own path):

    Email
    ------------------------
    john.smith@domain.com
    jane.doe@domain.com

    A Role column is not required for removal — if your CSV already has one
    (e.g. reused from the add script) it will simply be ignored.
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
    Write-Host "║      Remove People From Team  v1.0       ║" -ForegroundColor Cyan
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

# --- Choose removal method ---
Write-Host ""
$bulkRemove = Read-Host "Remove users from a CSV file? (Y/N — 'N' lets you remove a single user by email)"

$emailsToRemove = @()

if ($bulkRemove -match '^(Y|y)') {

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

    if (-not ($users[0].PSObject.Properties.Name -contains 'Email')) {
        Write-Host "✖  CSV must contain an 'Email' column." -ForegroundColor Red
        return
    }

    $emailsToRemove = $users | ForEach-Object { $_.Email.Trim() } | Where-Object { $_ -ne '' }
}
else {
    $singleEmail = Read-Host "Enter the email address to remove"
    if ([string]::IsNullOrWhiteSpace($singleEmail)) {
        Write-Host "No email entered. Exiting." -ForegroundColor Red
        return
    }
    $emailsToRemove = @($singleEmail.Trim())
}

if ($emailsToRemove.Count -eq 0) {
    Write-Host "✖  No valid email addresses to remove." -ForegroundColor Red
    return
}

# --- Final confirmation showing exactly who will be removed ---
Write-Host ""
Write-Host "The following $($emailsToRemove.Count) user(s) will be removed from '$($team.DisplayName)':" -ForegroundColor Yellow
$emailsToRemove | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
$finalConfirm = Read-Host "Proceed with removal? (Y/N)"
if ($finalConfirm -notmatch '^(Y|y)') {
    Write-Host "Cancelled — no changes made." -ForegroundColor Yellow
    return
}

# --- Remove users ---
Write-Host ""
Write-Host "Removing users from '$($team.DisplayName)'..." -ForegroundColor Yellow
Write-Host ""

$removed     = 0
$failed      = 0
$failedList  = @()

foreach ($email in $emailsToRemove) {

    try {
        # Owners must be removed as Owner explicitly, otherwise Remove-TeamUser
        # will fail to fully remove someone who holds the Owner role.
        $existingUser = Get-TeamUser -GroupId $team.GroupId | Where-Object { $_.User -eq $email }

        if (-not $existingUser) {
            Write-Host "✖  Skipped $email — not a member of this team" -ForegroundColor Red
            $failed++
            $failedList += $email
            continue
        }

        if ($existingUser.Role -eq 'Owner') {
            Remove-TeamUser -GroupId $team.GroupId -User $email -Role Owner -ErrorAction Stop
        }
        else {
            Remove-TeamUser -GroupId $team.GroupId -User $email -ErrorAction Stop
        }

        Write-Host "✔  Removed $email" -ForegroundColor Green
        $removed++
    }
    catch {
        Write-Host "✖  Failed to remove $email — $($_.Exception.Message)" -ForegroundColor Red
        $failed++
        $failedList += $email
    }
}

Write-Host ""
Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Team          : $($team.DisplayName)"
Write-Host "Removed       : $removed"
Write-Host "Failed        : $failed"
if ($failedList.Count -gt 0) {
    Write-Host "Failed users  : $($failedList -join ', ')"
}
Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
