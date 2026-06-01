# This script will create a user from the prompts
# Then if copying a user, will copy user details and groups except licencing groups
# Will enable the users mailbox in hybrid exchange 
# Will then display the name, email and password at the end of the script 
# All you will have to do manually is migrate the account in exchange online  

#Requires -Module ActiveDirectory

# ─────────────────────────────────────────────────────────────
#  CONFIGURATION — adjust defaults for your environment
# ─────────────────────────────────────────────────────────────
$DefaultOU         = "OU=Users, DC=local"
$DefaultDomain     = "yourdomain.com"                   
$MustChangeOnLogin = $false

# ─────────────────────────────────────────────────────────────
#  HELPER: Secure password generator
# ─────────────────────────────────────────────────────────────
function New-RandomPassword {
    $Colors = @(
        "Red","Blue","Green","Yellow","Purple","Orange","Pink","Brown","Black","White","Gray",
        "Gold","Silver","Bronze","Titanium","Ruby","Sapphire","Emerald","Jade","Opal","Quartz",
        "Amber","Beige","Brass","Copper","Caramel","Charcoal","Chocolate","Citron","Coal","Coffee",
        "Cyan","Indigo","Khaki","Lime","Magenta","Maroon","Olive","Plum","Desert","Rust","Snow",
        "Violet","Teal","Navy","Steel","Tan","Sienna","Ivory","Ebony","Crimson","Cream","Coral",
        "Cobalt","Chestnut","Champagne","Aqua","Asphalt","Apricot","Amethyst","Azure","Cinnamon",
        "Sand","Denim","Lavender","Lemon","Mustard","Orchid","Peach","Pewter","Pastel","Rose",
        "Saffron","Rainbow","Tangerine","Taupe","Topaz"
    )
    $Animals = @(
        "Dog","Cat","Rabbit","Elephant","Lion","Tiger","Zebra","Giraffe","Monkey","Horse",
        "Cow","Pig","Sheep","Goat","Chicken","Duck","Frog","Turtle","Penguin","Koala",
        "Bear","Deer","Whale","Dolphin","Shark","Octopus","Panda","Hippo","Rhino","Wolf",
        "Fox","Jaguar","Leopard","Cheetah","Crocodile","Vulture","Owl","Parrot","Eagle",
        "Sparrow","Peacock","Snake","Lizard","Spider","Ant","Seal","Orca","Hyena","Pigeon",
        "Donkey","Ferret","Alpaca","Yak","Goldfish","Wolverine","Toucan","Tortoise","Squirrel",
        "Scorpion","Reindeer","Raven","Puffin","Possum","Ostrich","Mouse","Moose","Meerkat",
        "Kangaroo","Kingfisher","Jellyfish","Jackal","Hedgehog","Hamster","Flamingo","Falcon",
        "Dingo","Coyote","Cobra","Chameleon","Camel","Butterfly","Bobcat","Bison","Badger","Anaconda"
    )
    $Objects = @(
        "Car","Bike","Chair","Table","Computer","Phone","Book","Bag","Shoe","Ball",
        "Clock","Flower","Tree","Lamp","Pen","Guitar","Camera","Cup","Knife","Fork",
        "Spoon","Plate","Glass","Key","Door","Window","House","Boat","Plane","Rocket",
        "Moon","Star","Sun","Cloud","Mountain","River","Lake","Ocean","Bridge","Road",
        "Train","Bus","Helmet","Sweater","Jumper","Coat","Scarf","Backpack","Calculator",
        "Bottle","Watch","Umbrella","Pencil","Notebook","Laptop","Mirror","Pillow","Folder"
    )

    $Symbol = '!@#$%&*'.ToCharArray() | Get-Random
    $Number = Get-Random -Minimum 10 -Maximum 99

    return "$(($Colors | Get-Random))$(($Animals | Get-Random))$(($Objects | Get-Random))$Number$Symbol"
}

# ─────────────────────────────────────────────────────────────
#  HELPER: Prompt wrapper (re-prompts on blank input)
# ─────────────────────────────────────────────────────────────
function Read-RequiredInput {
    param (
        [string]$Prompt,
        [string]$Default = ""
    )
    do {
        $DisplayPrompt = if ($Default) { "$Prompt [$Default]" } else { $Prompt }
        $Value = Read-Host $DisplayPrompt
        if (-not $Value -and $Default) { $Value = $Default }
    } while (-not $Value)
    return $Value.Trim()
}

# ─────────────────────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────────────────────
Clear-Host
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       New-ADUserFromInput  v1.1          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────
#  COLLECT USER DETAILS
# ─────────────────────────────────────────────────────────────
Write-Host "[ Step 1 of 3 ]  Enter user details" -ForegroundColor Yellow
Write-Host "────────────────────────────────────" -ForegroundColor DarkGray

$FirstName = Read-RequiredInput -Prompt "First name"
$LastName  = Read-RequiredInput -Prompt "Last name"

# Display name auto-generated — no prompt needed
$DisplayName = "$FirstName $LastName"

# Auto-generate logon names
# UPN prefix    : first.last  (e.g. john.smith)
# SAMAccountName: First Last  (e.g. Will Burkert)
$SuggestedUPN = ("$FirstName.$LastName") -replace '\s', ''
$SuggestedSAM = "$FirstName $LastName"

Write-Host ""
Write-Host "[ Step 2 of 3 ]  Logon names" -ForegroundColor Yellow
Write-Host "────────────────────────────────────" -ForegroundColor DarkGray

$UserLogonName   = Read-RequiredInput -Prompt "User logon name (UPN prefix)" -Default $SuggestedUPN
$PreWin2000Logon = Read-RequiredInput -Prompt "Pre-Windows 2000 logon (SAMAccountName)" -Default $SuggestedSAM

# Validate SAMAccountName length (AD limit: 20 chars)
if ($PreWin2000Logon.Length -gt 20) {
    Write-Warning "SAMAccountName is longer than 20 characters and will be truncated by AD."
    $PreWin2000Logon = $PreWin2000Logon.Substring(0,20)
    Write-Host "  Truncated to: $PreWin2000Logon" -ForegroundColor DarkYellow
}

$UPN = "$UserLogonName@$DefaultDomain"

# ─────────────────────────────────────────────────────────────
#  STEP 3 — COPY FROM EXISTING USER OR ENTER MANUALLY
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ Step 3 of 3 ]  User details" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

$CopyChoice = Read-Host "Copy details from an existing user? (Y/N)"

$JobTitle    = ""
$Department  = ""
$Company     = ""
$Office      = ""
$Phone       = ""
$Email       = ""
$ManagerDN   = $null
$ManagerName = $null
$OUPath      = $DefaultOU
$GroupsToAdd = $null

if ($CopyChoice -match '^[Yy]$') {

    # ── Look up the template user ──
    $TemplateTerm = (Read-Host "Enter username, full name, or email of the user to copy from").Trim()
    try {
        $TemplateUser = Get-ADUser -Filter {
            SamAccountName    -eq $TemplateTerm -or
            UserPrincipalName -eq $TemplateTerm -or
            EmailAddress      -eq $TemplateTerm -or
            DisplayName       -eq $TemplateTerm
        } -Properties Title, Department, Company, Office, OfficePhone,
                       Manager, MemberOf, DistinguishedName, DisplayName

        if (-not $TemplateUser) {
            Write-Warning "No user found matching '$TemplateTerm' — falling back to manual entry."
            $CopyChoice = "N"
        } else {
            Write-Host "  Copying from   : $($TemplateUser.DisplayName)" -ForegroundColor DarkGray

            # Pull attributes from template user
            $JobTitle   = $TemplateUser.Title
            $Department = $TemplateUser.Department
            $Company    = $TemplateUser.Company
            $Office     = $TemplateUser.Office
            $Phone      = if ($TemplateUser.OfficePhone) { $TemplateUser.OfficePhone } else { '+44 (0)1304 240400' }

            # Resolve manager DN to display name
            if ($TemplateUser.Manager) {
                $MgrUser     = Get-ADUser $TemplateUser.Manager -Properties DisplayName
                $ManagerDN   = $TemplateUser.Manager
                $ManagerName = $MgrUser.DisplayName
            }

            # Place new user in same OU as template user
            $OUPath = $TemplateUser.DistinguishedName -replace '^CN=[^,]+,',''

            # Copy group memberships, excluding any group whose name starts with 'Licensing'
            $GroupsToAdd = $TemplateUser.MemberOf | Where-Object {
                ($_ -split ',')[0] -replace '^CN=','' -notmatch '^Licensing'
            }

            Write-Host "  Job title      : $JobTitle" -ForegroundColor DarkGray
            Write-Host "  Department     : $Department" -ForegroundColor DarkGray
            Write-Host "  Company        : $Company" -ForegroundColor DarkGray
            Write-Host "  Office         : $Office" -ForegroundColor DarkGray
            Write-Host "  Telephone      : $Phone" -ForegroundColor DarkGray
            Write-Host "  Groups to copy : $($GroupsToAdd.Count) (Licensing groups excluded)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Template user lookup failed: $($_.Exception.Message) — falling back to manual entry."
        $CopyChoice = "N"
    }
}

if ($CopyChoice -notmatch '^[Yy]$') {
    # ── Manual entry ──
    $JobTitle   = (Read-Host "Job title       ").Trim()
    $Department = (Read-Host "Department      ").Trim()
    $Company    = (Read-Host "Company         ").Trim()
    $Office     = (Read-Host "Office          ").Trim()
    $Phone      = (Read-Host "Telephone       [+44 (0)1304 240400]").Trim()
    if (-not $Phone) { $Phone = '+44 (0)1304 240400' }

    $ManagerEmail = (Read-Host "Manager email   (leave blank for none)").Trim()
    if ($ManagerEmail) {
        try {
            $ManagerUser = Get-ADUser -Filter { EmailAddress -eq $ManagerEmail } -Properties EmailAddress, DisplayName
            if ($ManagerUser) {
                $ManagerDN   = $ManagerUser.DistinguishedName
                $ManagerName = $ManagerUser.DisplayName
                Write-Host "  Manager found  : $ManagerName" -ForegroundColor DarkGray
            } else {
                Write-Warning "No AD account found with email '$ManagerEmail' — manager will not be set."
            }
        } catch {
            Write-Warning "Manager lookup failed: $($_.Exception.Message) — manager will not be set."
        }
    }

    $OUInput = (Read-Host "Target OU DN    (leave blank for default: $DefaultOU)").Trim()
    if ($OUInput) { $OUPath = $OUInput }
}

# Manager prompt always asked regardless of copy or manual
$ManagerDN     = $null
$ManagerName   = $null
$ManagerSearch = (Read-Host "Manager        (name, username or email — leave blank for none)").Trim()
if ($ManagerSearch) {
    try {
        $ManagerResults = Get-ADUser -Filter {
            SamAccountName    -eq $ManagerSearch -or
            UserPrincipalName -eq $ManagerSearch -or
            EmailAddress      -eq $ManagerSearch -or
            DisplayName       -eq $ManagerSearch -or
            Name              -eq $ManagerSearch
        } -Properties DisplayName, EmailAddress

        if (-not $ManagerResults) {
            Write-Warning "No user found matching '$ManagerSearch' — manager will not be set."
        } elseif ($ManagerResults.Count -gt 1) {
            Write-Host "  Multiple matches found — select manager:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $ManagerResults.Count; $i++) {
                Write-Host "    [$i] $($ManagerResults[$i].DisplayName)  ($($ManagerResults[$i].SamAccountName))"
            }
            $Sel         = Read-Host "  Enter number"
            $ManagerDN   = $ManagerResults[$Sel].DistinguishedName
            $ManagerName = $ManagerResults[$Sel].DisplayName
            Write-Host "  Manager set    : $ManagerName" -ForegroundColor DarkGray
        } else {
            $ManagerDN   = $ManagerResults.DistinguishedName
            $ManagerName = $ManagerResults.DisplayName
            Write-Host "  Manager found  : $ManagerName" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Manager lookup failed: $($_.Exception.Message) — manager will not be set."
    }
}

# ─────────────────────────────────────────────────────────────
#  GENERATE PASSWORD
# ─────────────────────────────────────────────────────────────
$PlainPassword  = New-RandomPassword
$SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

# ─────────────────────────────────────────────────────────────
#  CONFIRMATION SUMMARY
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Review — account to be created          " -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  First name        : $FirstName"
Write-Host "  Last name         : $LastName"
Write-Host "  Display name      : $DisplayName"
Write-Host "  UPN               : $UPN"
Write-Host "  SAMAccountName    : $PreWin2000Logon"
Write-Host "  Telephone         : $Phone"
if ($Email)       { Write-Host "  Email             : $Email" }
if ($JobTitle)    { Write-Host "  Job title         : $JobTitle" }
if ($Department)  { Write-Host "  Department        : $Department" }
if ($Company)     { Write-Host "  Company           : $Company" }
if ($Office)      { Write-Host "  Office            : $Office" }
if ($ManagerName) { Write-Host "  Manager           : $ManagerName" }
if ($GroupsToAdd) {
    Write-Host "  Groups to copy    : $($GroupsToAdd.Count) (Licensing groups excluded)"
    $GroupsToAdd | ForEach-Object {
        Write-Host "    · $(($_ -split ',')[0] -replace '^CN=','')" -ForegroundColor DarkGray
    }
}
Write-Host "  Target OU         : $OUPath"
Write-Host "  Password          : $PlainPassword" -ForegroundColor Green
Write-Host "  Force pwd change  : $MustChangeOnLogin"
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$Confirm = Read-Host "Create this account? (Y/N)"
if ($Confirm -notmatch '^[Yy]$') {
    Write-Host "Aborted. No account was created." -ForegroundColor Red
    exit 0
}

# ─────────────────────────────────────────────────────────────
#  CREATE THE AD USER
# ─────────────────────────────────────────────────────────────
try {
    $NewUserParams = @{
        GivenName             = $FirstName
        Surname               = $LastName
        Name                  = $DisplayName
        DisplayName           = $DisplayName
        UserPrincipalName     = $UPN
        SamAccountName        = $PreWin2000Logon
        AccountPassword       = $SecurePassword
        Enabled               = $true
        ChangePasswordAtLogon = $MustChangeOnLogin
        Path                  = $OUPath
        PassThru              = $true
    }

    if ($Phone)      { $NewUserParams['OfficePhone']  = $Phone }
    if ($Email)      { $NewUserParams['EmailAddress'] = $Email }
    if ($JobTitle)   { $NewUserParams['Title']        = $JobTitle
                       $NewUserParams['Description']  = $JobTitle }
    if ($Department) { $NewUserParams['Department']   = $Department }
    if ($Company)    { $NewUserParams['Company']      = $Company }
    if ($Office)     { $NewUserParams['Office']       = $Office }
    if ($ManagerDN)  { $NewUserParams['Manager']      = $ManagerDN }

    $NewUser = New-ADUser @NewUserParams

    Write-Host ""
    Write-Host "✔  AD account created successfully!" -ForegroundColor Green

    # ── Copy group memberships from template user (exclude Licensing* groups) ──
    if ($GroupsToAdd) {
        Write-Host ""
        Write-Host "Adding group memberships..." -ForegroundColor Yellow
        $GroupsAdded  = [System.Collections.Generic.List[string]]::new()
        $GroupsFailed = [System.Collections.Generic.List[string]]::new()

        foreach ($GroupDN in $GroupsToAdd) {
            $GroupDisplayName = ($GroupDN -split ',')[0] -replace '^CN=',''
            try {
                Add-ADGroupMember -Identity $GroupDN -Members $NewUser.SamAccountName -ErrorAction Stop
                $GroupsAdded.Add($GroupDisplayName)
            } catch {
                $GroupsFailed.Add($GroupDisplayName)
                Write-Warning "  Could not add to '$GroupDisplayName': $($_.Exception.Message)"
            }
        }

        if ($GroupsAdded.Count -gt 0) {
            Write-Host "  ✔  Added to $($GroupsAdded.Count) group(s):" -ForegroundColor Green
            $GroupsAdded | ForEach-Object { Write-Host "       · $_" -ForegroundColor DarkGray }
        }
        if ($GroupsFailed.Count -gt 0) {
            Write-Host "  ✘  Failed to add to $($GroupsFailed.Count) group(s):" -ForegroundColor Red
            $GroupsFailed | ForEach-Object { Write-Host "       · $_" -ForegroundColor DarkRed }
        }
    }

}
catch {
    Write-Host ""
    Write-Host "✘  Failed to create AD account:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────────────────────
#  WAIT FOR AD REPLICATION
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Waiting 60 seconds for AD replication before enabling mailbox..." -ForegroundColor Yellow

$WaitSeconds = 60
for ($i = $WaitSeconds; $i -gt 0; $i--) {
    Write-Progress -Activity "AD Replication Wait" `
                   -Status "$i seconds remaining..." `
                   -PercentComplete (($WaitSeconds - $i) / $WaitSeconds * 100)
    Start-Sleep -Seconds 1
}
Write-Progress -Activity "AD Replication Wait" -Completed
Write-Host "Wait complete. Proceeding to mailbox creation." -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────
#  ENABLE MAILBOX ON EXCHANGE SERVER
# ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Connecting to Exchange server..." -ForegroundColor Yellow
Write-Host "Enter credentials with Exchange admin rights:" -ForegroundColor DarkGray

try {
    $ExchCred    = Get-Credential -Message "Enter Exchange admin credentials" -UserName ""
    $ExchSession = New-PSSession -ConfigurationName Microsoft.Exchange `
                                 -ConnectionUri "ENTER EXCHANGE DOMAIN HERE" `
                                 -Authentication Kerberos `
                                 -Credential $ExchCred

    Import-PSSession $ExchSession -DisableNameChecking | Out-Null

    Write-Host "Connected. Enabling mailbox..." -ForegroundColor DarkGray

    # Build the primary SMTP address from the UPN prefix + domain
    $MailboxAlias = $UserLogonName  # e.g. john.smith
    $PrimaryEmail = "$MailboxAlias@yourdomain.com"

    Enable-Mailbox -Identity $PreWin2000Logon `
                   -Alias $MailboxAlias

    # Set the primary SMTP address explicitly
    Set-Mailbox -Identity $PreWin2000Logon `
                -PrimarySmtpAddress $PrimaryEmail `
                -EmailAddressPolicyEnabled $false

    Write-Host ""
    Write-Host "✔  Mailbox enabled successfully!" -ForegroundColor Green
    Write-Host "  Email address : $PrimaryEmail" -ForegroundColor Cyan

}
catch {
    Write-Host ""
    Write-Host "✘  Mailbox creation failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    if ($ExchSession) {
        Remove-PSSession $ExchSession
        Write-Host "Exchange session closed." -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────────────────────
#  CREDENTIAL SUMMARY
# ─────────────────────────────────────────────────────────────
Write-Host ""
$Summary = @"
─────────────────────────────────────────
$DisplayName
$PrimaryEmail
$PlainPassword

Done:
Groups

To Do:
Licences
Migrate to Exchange Online
  
─────────────────────────────────────────
"@
Write-Host $Summary -ForegroundColor Cyan