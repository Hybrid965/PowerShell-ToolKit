# Pulls all Distribution Lists from AD with Name and Email Address 
# Requires: ActiveDirectory module (RSAT) 
# Run on a domain-joined machine or DC with AD module installed

# Requires Import-Module ActiveDirectory

# Output file path (change as needed)
$OutputPath = "C:\Reports\DistributionLists.csv"

# Ensure output directory exists
$OutputDir = Split-Path $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "Querying Active Directory for Distribution Lists..." -ForegroundColor Cyan

# Get all Distribution Groups (excludes Security Groups)
# GroupCategory -eq 'Distribution' filters out security groups
$DistributionLists = Get-ADGroup -Filter {
    GroupCategory -eq 'Distribution'
} -Properties Name, Mail, DisplayName, Description, GroupScope, ManagedBy, WhenCreated | 
    Select-Object `
        @{Name='Name';         Expression={ $_.Name }},
        @{Name='DisplayName';  Expression={ $_.DisplayName }},
        @{Name='EmailAddress'; Expression={ $_.Mail }},
        @{Name='Scope';        Expression={ $_.GroupScope }},
        @{Name='Description';  Expression={ $_.Description }},
        @{Name='ManagedBy';    Expression={ $_.ManagedBy }},
        @{Name='Created';      Expression={ $_.WhenCreated }} |
    Sort-Object Name

# Summary
$Total      = $DistributionLists.Count
$WithEmail  = ($DistributionLists | Where-Object { $_.EmailAddress }).Count
$NoEmail    = $Total - $WithEmail

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  Total DLs found : $Total"
Write-Host "  With email      : $WithEmail"
Write-Host "  Without email   : $NoEmail"

# Export to CSV
$DistributionLists | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "`nExported to: $OutputPath" -ForegroundColor Yellow

# Also display in console
$DistributionLists | Format-Table Name, EmailAddress, Scope -AutoSize