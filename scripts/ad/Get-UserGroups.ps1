#Requires -Module ActiveDirectory


# ─────────────────────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────────────────────
Clear-Host
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Get-UserGroups  v1.0             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
#  PROMPT FOR USER
# ─────────────────────────────────────────────────────────────
$SearchTerm = (Read-Host "Enter username, full name, or email address").Trim()

if (-not $SearchTerm) {
    Write-Host "No input provided. Exiting." -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────────────────────
#  FIND THE USER IN AD
# ─────────────────────────────────────────────────────────────
try {
    $User = Get-ADUser -Filter {
        SamAccountName    -eq $SearchTerm -or
        UserPrincipalName -eq $SearchTerm -or
        EmailAddress      -eq $SearchTerm -or
        DisplayName       -eq $SearchTerm
    } -Properties DisplayName, EmailAddress, MemberOf, Enabled

    if (-not $User) {
        Write-Host ""
        Write-Host "✘  No user found matching '$SearchTerm'." -ForegroundColor Red
        exit 1
    }

    # Handle multiple matches
    if ($User.Count -gt 1) {
        Write-Host ""
        Write-Host "Multiple users found — please select one:" -ForegroundColor Yellow
        Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $User.Count; $i++) {
            Write-Host "  [$i] $($User[$i].DisplayName)  ($($User[$i].SamAccountName))"
        }
        Write-Host ""
        $Selection = Read-Host "Enter number"
        $User = $User[$Selection]
    }
}
catch {
    Write-Host "✘  AD lookup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────────────────────
#  RETRIEVE GROUP MEMBERSHIPS
# ─────────────────────────────────────────────────────────────
try {
    $Groups = Get-ADPrincipalGroupMembership -Identity $User.SamAccountName |
              Select-Object Name, GroupCategory, GroupScope |
              Sort-Object Name

    $AccountStatus = if ($User.Enabled) { "Enabled" } else { "Disabled" }

    # ── Display user info ──
    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  User Details" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Name           : $($User.DisplayName)"
    Write-Host "  SAMAccountName : $($User.SamAccountName)"
    Write-Host "  Email          : $($User.EmailAddress)"
    Write-Host "  Account status : $AccountStatus"
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan

    # ── Display groups ──
    Write-Host ""
    Write-Host "  Group Memberships ($($Groups.Count) total)" -ForegroundColor Yellow
    Write-Host "──────────────────────────────────────────" -ForegroundColor DarkGray

    if ($Groups.Count -eq 0) {
        Write-Host "  No group memberships found." -ForegroundColor DarkGray
    } else {
        # Separate Security and Distribution groups
        $SecurityGroups      = $Groups | Where-Object { $_.GroupCategory -eq "Security" }
        $DistributionGroups  = $Groups | Where-Object { $_.GroupCategory -eq "Distribution" }

        if ($SecurityGroups.Count -gt 0) {
            Write-Host ""
            Write-Host "  [ Security Groups ]" -ForegroundColor Green
            foreach ($Group in $SecurityGroups) {
                Write-Host "    $($Group.Name);"
            }
        }

        if ($DistributionGroups.Count -gt 0) {
            Write-Host ""
            Write-Host "  [ Distribution Groups ]" -ForegroundColor Magenta
            foreach ($Group in $DistributionGroups) {
                Write-Host "    $($Group.Name);"
            }
        }
    }

    Write-Host ""
    Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan


}
catch {
    Write-Host "✘  Failed to retrieve groups: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}