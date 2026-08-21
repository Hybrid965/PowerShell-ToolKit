param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Search", "Create", "Check")]
    [string]$Mode,

    # ---- Search mode params ----
    # Do not use ValidateSet here. Exchange Import-PSSession can create/update a
    # variable called SearchType, and a ValidateSet on this script parameter can
    # cause: "The attribute cannot be added because variable SearchType with value
    # would no longer be valid."
    [string]$SearchType,
    [string]$SearchTerm,
    [string]$CheckType,
    [string]$CheckValue,

    # ---- Create mode params ----
    [string]$FirstName,
    [string]$LastName,
    [string]$DisplayName,
    [string]$AccountExpiryDate,
    [string]$UserLogonName,      # UPN prefix
    [string]$SamAccountName,
    [string]$JobTitle,
    [string]$Description,
    [string]$Department,
    [string]$Company,
    [string]$Office,
    [string]$Phone,
    [string]$Email,
    [string]$ManagerDN,          # already resolved by GUI via Search mode
    [string]$TemplateDN,         # already resolved by GUI via Search mode
    [string]$OUPath,
    [string]$DefaultDomain = "portofdover.com",
    [string]$DefaultNetBIOSDomain = "POD",
    [string]$ExchangeServer = "exchange.pod.local",
    [object]$ExchangeEnabled = $true,
    [switch]$MustChangeOnLogin,
    [switch]$SkipMailbox,
    [switch]$WhatIfMode,
    [switch]$ContractorAccount,
    [string]$AdminUsername,
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"

function Convert-ToBooleanSetting {
    param(
        [object]$Value,
        [bool]$Default = $true
    )

    if ($null -eq $Value) {
        return $Default
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    $Text = [string]$Value
    $Text = $Text.Trim().TrimStart('$').ToLowerInvariant()

    switch ($Text) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "y" { return $true }
        "on" { return $true }
        "enabled" { return $true }
        "0" { return $false }
        "false" { return $false }
        "no" { return $false }
        "n" { return $false }
        "off" { return $false }
        "disabled" { return $false }
        default { return $Default }
    }
}

$ExchangeEnabled = Convert-ToBooleanSetting -Value $ExchangeEnabled -Default $true

function Write-Log {
    param([string]$Level, [string]$Message)
    Write-Output "LOG|$Level|$Message"
}

function Write-Result {
    param($Object)
    $json = $Object | ConvertTo-Json -Depth 6 -Compress
    Write-Output "RESULT|$json"
}

try {
    Write-Log "INFO" "Backend started. Loading Active Directory module..."
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Log "SUCCESS" "Active Directory module loaded."
} catch {
    Write-Log "ERROR" "Could not load ActiveDirectory module: $($_.Exception.Message)"
    Write-Result @{ Success = $false; Stage = "ImportModule"; Error = $_.Exception.Message }
    exit 1
}

$AdCredential = $null
$EffectiveAdminUsername = $AdminUsername
if ($AdminUsername -and $AdminPassword) {
    try {
        # If only a bare username is entered, force it to the configured NetBIOS domain so
        # AD and Exchange both authenticate as the supplied admin account,
        # not the currently logged-on Windows user.
        if (($AdminUsername -notmatch '\\') -and ($AdminUsername -notmatch '@')) {
            $EffectiveAdminUsername = "$DefaultNetBIOSDomain\$AdminUsername"
        }

        $SecureAdminPassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
        $AdCredential = New-Object System.Management.Automation.PSCredential ($EffectiveAdminUsername, $SecureAdminPassword)
        Write-Log "INFO" "Using supplied admin credentials for AD and Exchange actions: $EffectiveAdminUsername"
    } catch {
        Write-Log "ERROR" "Could not build admin credential object: $($_.Exception.Message)"
        Write-Result @{ Success = $false; Stage = "Credential"; Error = $_.Exception.Message }
        exit 1
    }
}

function Add-CredentialIfProvided {
    param([hashtable]$Params)
    if ($script:AdCredential) { $Params['Credential'] = $script:AdCredential }
    return $Params
}

# -------------------------------------------------------------
#  PASSWORD GENERATOR
# -------------------------------------------------------------
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


# =============================================================
#  MODE: CHECK
# =============================================================
if ($Mode -eq "Check") {
    try {
        if (-not $CheckType -or -not $CheckValue) {
            Write-Result @{ Success = $false; Exists = $false; Count = 0; Error = "CheckType and CheckValue are required." }
            exit 1
        }

        function Escape-LdapValue {
            param([string]$Value)
            if ($null -eq $Value) { return "" }
            return ($Value -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29' -replace "`0", '\00')
        }

        $Escaped = Escape-LdapValue $CheckValue
        $Filter = $null
        switch ($CheckType.ToLower()) {
            "sam" {
                $Filter = "(&(objectCategory=person)(objectClass=user)(samAccountName=$Escaped))"
            }
            "upn" {
                $UpnToCheck = $CheckValue
                if ($UpnToCheck -notmatch '@') { $UpnToCheck = "$UpnToCheck@$DefaultDomain" }
                $EscapedUpn = Escape-LdapValue $UpnToCheck
                $Filter = "(&(objectCategory=person)(objectClass=user)(userPrincipalName=$EscapedUpn))"
            }
            "display" {
                $Filter = "(&(objectCategory=person)(objectClass=user)(displayName=$Escaped))"
            }
            default {
                Write-Result @{ Success = $false; Exists = $false; Count = 0; Error = "Unknown CheckType '$CheckType'. Use sam, upn, or display." }
                exit 1
            }
        }

        $Params = @{ LDAPFilter = $Filter; ResultSetSize = 10; Properties = @('DisplayName','SamAccountName','UserPrincipalName') }
        $Params = Add-CredentialIfProvided $Params
        $Found = @(Get-ADUser @Params)
        $MatchNames = @($Found | ForEach-Object {
            if ($_.DisplayName -and $_.SamAccountName) { "$($_.DisplayName) ($($_.SamAccountName))" }
            elseif ($_.DisplayName) { $_.DisplayName }
            else { $_.SamAccountName }
        })

        Write-Result @{
            Success = $true
            CheckType = $CheckType
            CheckValue = $CheckValue
            Exists = ($Found.Count -gt 0)
            Count = $Found.Count
            Matches = $MatchNames
        }
    }
    catch {
        Write-Result @{ Success = $false; Exists = $false; Count = 0; Error = $_.Exception.Message }
        exit 1
    }
    exit 0
}

# =============================================================
#  MODE: SEARCH
# =============================================================
if ($Mode -eq "Search") {

    if (-not $SearchTerm) {
        Write-Log "ERROR" "No search term supplied."
        Write-Result @{ Success = $false; Matches = @() }
        exit 1
    }

    try {
        Write-Log "INFO" "Searching AD for '$SearchTerm'..."

        # Safer search using LDAPFilter. Handles spaces, apostrophes and partial names better than -Filter ANR strings.
        function Escape-LdapValue {
            param([string]$Value)
            if ($null -eq $Value) { return "" }
            return ($Value -replace '\\', '\5c' -replace '\*', '\2a' -replace '\(', '\28' -replace '\)', '\29' -replace "`0", '\00')
        }

        $Escaped = Escape-LdapValue $SearchTerm
        $LdapFilter = "(&(objectCategory=person)(objectClass=user)(|(anr=$Escaped)(samAccountName=$Escaped*)(userPrincipalName=$Escaped*)(mail=$Escaped*)(displayName=*$Escaped*)))"

        $Matches = Get-ADUser -LDAPFilter $LdapFilter -ResultSetSize 25 -Properties Title, Department, Company, Office, OfficePhone,
                       EmailAddress, Manager, MemberOf, DistinguishedName, DisplayName

        if (-not $Matches) {
            Write-Log "WARN" "No matches found for '$SearchTerm'."
            Write-Result @{ Success = $true; Matches = @() }
            exit 0
        }

        $Results = foreach ($m in @($Matches)) {
            [PSCustomObject]@{
                DisplayName       = $m.DisplayName
                SamAccountName    = $m.SamAccountName
                EmailAddress      = $m.EmailAddress
                Title             = $m.Title
                Department        = $m.Department
                Company           = $m.Company
                Office            = $m.Office
                OfficePhone       = $m.OfficePhone
                DistinguishedName = $m.DistinguishedName
                GroupCount        = if ($SearchType -eq "Template") {
                                        @($m.MemberOf | Where-Object {
                                            ($_ -split ',')[0] -replace '^CN=','' -notmatch '^Licensing'
                                        }).Count
                                     } else { $null }
                GroupNames        = if ($SearchType -eq "Template") {
                                        @($m.MemberOf | Where-Object {
                                            ($_ -split ',')[0] -replace '^CN=','' -notmatch '^Licensing'
                                        } | ForEach-Object {
                                            ($_ -split ',')[0] -replace '^CN=',''
                                        } | Sort-Object)
                                     } else { @() }
            }
        }

        Write-Log "SUCCESS" "Found $($Results.Count) match(es)."
        Write-Result @{ Success = $true; Matches = $Results }
    }
    catch {
        Write-Log "ERROR" "Search failed: $($_.Exception.Message)"
        Write-Result @{ Success = $false; Matches = @(); Error = $_.Exception.Message }
        exit 1
    }

    exit 0
}

# =============================================================
#  MODE: CREATE
# =============================================================

$DefaultOU = "OU=Users,OU=POD (Users and Groups),DC=pod,DC=local"
if (-not $OUPath) { $OUPath = $DefaultOU }
if (-not $Phone)  { $Phone = '+44 (0)1304 240400' }

$BaseDisplayName = "$FirstName $LastName"
if ([string]::IsNullOrWhiteSpace($DisplayName)) {
    $DisplayName = if ($ContractorAccount) { "EXT_$BaseDisplayName" } else { $BaseDisplayName }
}
$UPN         = "$UserLogonName@$DefaultDomain"
$AccountExpiry = $null
if (-not [string]::IsNullOrWhiteSpace($AccountExpiryDate)) {
    try {
        $AccountExpiry = [datetime]::Parse($AccountExpiryDate)
    } catch {
        Write-Result @{ Success = $false; Error = "Invalid AccountExpiryDate. Use YYYY-MM-DD." }
        exit 1
    }
} elseif ($ContractorAccount) {
    $AccountExpiry = (Get-Date).AddMonths(3)
}

Write-Log "INFO" "Preparing to create account for $DisplayName ($UPN)"
if ($ContractorAccount) {
    Write-Log "INFO" "Contractor account selected. Account expiry will be set to $($AccountExpiry.ToString('yyyy-MM-dd'))."
}

# -- Resolve template user's copyable attributes/groups --
$GroupsToAdd = @()
if ($TemplateDN) {
    try {
        Write-Log "INFO" "Pulling attributes and groups from template user..."
        $TemplateParams = @{ Identity = $TemplateDN; Properties = @('Title','Department','Company','Office','OfficePhone','MemberOf') }
        $TemplateParams = Add-CredentialIfProvided $TemplateParams
        $TemplateUser = Get-ADUser @TemplateParams

        if (-not $JobTitle)   { $JobTitle   = $TemplateUser.Title }
        if (-not $Department) { $Department = $TemplateUser.Department }
        if (-not $Company)    { $Company    = $TemplateUser.Company }
        if (-not $Office)     { $Office     = $TemplateUser.Office }
        if (-not $Phone)      { $Phone      = $TemplateUser.OfficePhone }

        $GroupsToAdd = @($TemplateUser.MemberOf | Where-Object {
            ($_ -split ',')[0] -replace '^CN=','' -notmatch '^Licensing'
        })
        Write-Log "SUCCESS" "Template attributes loaded. $($GroupsToAdd.Count) group(s) queued (Licensing groups excluded)."
    }
    catch {
        Write-Log "WARN" "Could not read template user: $($_.Exception.Message)"
    }
}

if ($ManagerDN) {
    try {
        $MgrParams = @{ Identity = $ManagerDN; Properties = 'DisplayName' }
        $MgrParams = Add-CredentialIfProvided $MgrParams
        $MgrUser = Get-ADUser @MgrParams
        Write-Log "INFO" "Manager resolved: $($MgrUser.DisplayName)"
    } catch {
        Write-Log "WARN" "Manager DN could not be resolved: $($_.Exception.Message)"
        $ManagerDN = $null
    }
}

# -- Password --
$PlainPassword  = New-RandomPassword
$SecurePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force

if ($WhatIfMode) {
    Write-Log "WARN" "DRY RUN - no changes will be made to Active Directory or Exchange."
}

# -- Create the AD user --
$NewUser = $null
try {
    $NewUserParams = @{
        GivenName             = $FirstName
        Surname               = $LastName
        Name                  = $DisplayName
        DisplayName           = $DisplayName
        UserPrincipalName     = $UPN
        SamAccountName        = $SamAccountName
        AccountPassword       = $SecurePassword
        Enabled               = $true
        ChangePasswordAtLogon = [bool]$MustChangeOnLogin
        Path                  = $OUPath
        PassThru              = $true
    }
    if ($Phone)      { $NewUserParams['OfficePhone']  = $Phone }
    if ($Email)      { $NewUserParams['EmailAddress'] = $Email }
    if ($JobTitle)   { $NewUserParams['Title']        = $JobTitle }
    if ($Description) { $NewUserParams['Description'] = $Description }
    elseif ($JobTitle) { $NewUserParams['Description'] = $JobTitle }
    if ($Department) { $NewUserParams['Department']   = $Department }
    if ($Company)    { $NewUserParams['Company']      = $Company }
    if ($Office)     { $NewUserParams['Office']       = $Office }
    if ($ManagerDN)  { $NewUserParams['Manager']      = $ManagerDN }
    if ($AccountExpiry) { $NewUserParams['AccountExpirationDate'] = $AccountExpiry }
    if ($AdCredential) { $NewUserParams['Credential'] = $AdCredential }

    if ($WhatIfMode) {
        Write-Log "INFO" "[DRY RUN] Would create user with SamAccountName '$SamAccountName' in '$OUPath'."
        $NewUser = [PSCustomObject]@{ SamAccountName = $SamAccountName }
    } else {
        Write-Log "INFO" "Creating AD account..."
        $NewUser = New-ADUser @NewUserParams
        Write-Log "SUCCESS" "AD account created: $SamAccountName"
    }
}
catch {
    Write-Log "ERROR" "Failed to create AD account: $($_.Exception.Message)"
    Write-Result @{ Success = $false; Stage = "CreateUser"; Error = $_.Exception.Message }
    exit 1
}

# -- Copy group memberships --
$GroupsAdded  = @()
$GroupsFailed = @()
if ($GroupsToAdd.Count -gt 0) {
    Write-Log "INFO" "Adding group memberships..."
    foreach ($GroupDN in $GroupsToAdd) {
        $GroupName = ($GroupDN -split ',')[0] -replace '^CN=',''
        if ($WhatIfMode) {
            Write-Log "INFO" "[DRY RUN] Would add to group: $GroupName"
            $GroupsAdded += $GroupName
            continue
        }
        try {
            $GroupParams = @{ Identity = $GroupDN; Members = $NewUser.SamAccountName; ErrorAction = 'Stop' }
            if ($AdCredential) { $GroupParams['Credential'] = $AdCredential }
            Add-ADGroupMember @GroupParams
            Write-Log "SUCCESS" "Added to group: $GroupName"
            $GroupsAdded += $GroupName
        } catch {
            Write-Log "ERROR" "Could not add to '$GroupName': $($_.Exception.Message)"
            $GroupsFailed += $GroupName
        }
    }
}

# -- Wait for AD replication --
if (-not $WhatIfMode) {
    Write-Log "INFO" "Waiting 60 seconds for AD replication before enabling mailbox..."
    for ($i = 60; $i -gt 0; $i -= 5) {
        Write-Log "INFO" "Replication wait: $i seconds remaining..."
        Start-Sleep -Seconds 5
    }
}

# -- Enable mailbox --
$MailboxStatus = "Skipped"
$PrimaryEmail  = "$UserLogonName@$DefaultDomain"

if ($WhatIfMode) {
    Write-Log "INFO" "[DRY RUN] Would enable mailbox for $PrimaryEmail"
    $MailboxStatus = "DryRun"
}

if ((-not $SkipMailbox) -and (-not $WhatIfMode) -and $ExchangeEnabled) {
    try {
        Write-Log "INFO" "Connecting to Exchange server ($ExchangeServer)..."

        $SessionParams = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri     = "http://$ExchangeServer/PowerShell/"
            Authentication    = 'Kerberos'
        }

        if ($AdCredential) {
            $SessionParams['Credential'] = $AdCredential
            Write-Log "INFO" "Exchange session will use supplied admin credential: $EffectiveAdminUsername"
        } else {
            Write-Log "WARN" "No admin credential supplied. Exchange will use the current Windows session."
        }

        $ExchSession = New-PSSession @SessionParams

        Import-PSSession $ExchSession -DisableNameChecking -AllowClobber | Out-Null
        Write-Log "INFO" "Connected. Enabling mailbox..."

        Enable-Mailbox -Identity $SamAccountName -Alias $UserLogonName
        Set-Mailbox -Identity $SamAccountName -PrimarySmtpAddress $PrimaryEmail -EmailAddressPolicyEnabled $false

        Write-Log "SUCCESS" "Mailbox enabled: $PrimaryEmail"
        $MailboxStatus = "Enabled"
    }
    catch {
        Write-Log "ERROR" "Mailbox creation failed: $($_.Exception.Message)"
        $MailboxStatus = "Failed: $($_.Exception.Message)"
    }
    finally {
        if ($ExchSession) {
            Remove-PSSession $ExchSession
            Write-Log "INFO" "Exchange session closed."
        }
    }
}


if ((-not $SkipMailbox) -and (-not $WhatIfMode) -and (-not $ExchangeEnabled)) {
    Write-Log "INFO" "Exchange is disabled in settings.ini. Mailbox creation skipped."
    $MailboxStatus = "Skipped - Exchange disabled"
}

# -- Final result --
Write-Result @{
    Success        = $true
    DryRun         = [bool]$WhatIfMode
    DisplayName    = $DisplayName
    UPN            = $UPN
    SamAccountName = $SamAccountName
    PrimaryEmail   = $PrimaryEmail
    Password       = $PlainPassword
    JobTitle       = $JobTitle
    Description    = $(if ($Description) { $Description } else { $JobTitle })
    Department     = $Department
    Company        = $Company
    Office         = $Office
    Phone          = $Phone
    OUPath         = $OUPath
    AccountExpiry  = if ($AccountExpiry) { $AccountExpiry.ToString('yyyy-MM-dd') } else { $null }
    IsContractor   = [bool]$ContractorAccount
    GroupsAdded    = $GroupsAdded
    GroupsFailed   = $GroupsFailed
    MailboxStatus  = $MailboxStatus
}