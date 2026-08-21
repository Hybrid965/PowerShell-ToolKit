# 👤 Active Directory

Scripts and tools for AD user provisioning, group and mailbox management, and reporting.

⬅ [Back to main README](../../README.md)

---

## 📋 Contents

- [`Create-User-AddToExchange.ps1`](#create-user-addtoexchangeps1)
- [`Get-User.ps1`](#get-userps1)
- [`Get-UserGroups.ps1`](#get-usergroupsps1)
- [`Get-DistributionLists.ps1`](#get-distributionlistsps1)
- [AD Account Creator](#ad-account-creator)

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| **ActiveDirectory module** | Required for all scripts in this section |
| **RSAT** | Install via `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` |
| **Domain-joined machine** | Required for AD and Exchange operations |
| **Exchange admin credentials** | Required for `Create-User-AddToExchange.ps1` only |

---

## `Create-User-AddToExchange.ps1`

**Creates a new AD user account and provisions their Exchange mailbox in one flow.**

This is a full end-to-end onboarding script. It collects user details interactively, optionally copies attributes and group memberships from an existing user (excluding licensing groups), generates a secure random password, creates the AD account, waits for replication, then connects to the on-prem Exchange server to enable the mailbox and set the primary SMTP address.

If you want to edit which groups it excludes or to remove the exclusion, edit this code block:
```powershell
# Copy group memberships, excluding any group whose name starts with 'Licensing'
            $GroupsToAdd = $TemplateUser.MemberOf | Where-Object {
                ($_ -split ',')[0] -replace '^CN=','' -notmatch '^Licensing'
```

**Requirements:** `ActiveDirectory` module, Exchange admin credentials, domain-joined machine.

**Modules required:**
```powershell
#Requires -Module ActiveDirectory
```

**What it does — step by step:**
1. Prompts for first name, last name, logon name and SAMAccountName (auto-suggested)
2. Optionally copies job title, department, company, office, phone, manager and group memberships from an existing user
3. Generates a memorable random password (`ColourAnimalObject##!`)
4. Shows a full confirmation summary before creating anything
5. Creates the AD user account in the correct OU
6. Adds the user to copied group memberships (Licensing groups excluded)
7. Waits 60 seconds for AD replication
8. Connects to Exchange via remote PowerShell and enables the mailbox
9. Sets the primary SMTP address and prints a handover summary

**Usage:**
```powershell
.\Create-User-AddToExchange.ps1
```

**Configuration block** (edit details in the script for your environment):
```powershell
$DefaultOU         = "OU=Users, DC=local"
$DefaultDomain     = "yourdomain.com"
$MustChangeOnLogin = $false

-ConnectionUri "ENTER EXCHANGE DOMAIN HERE"
$PrimaryEmail = "$MailboxAlias@yourdomain.com"
```

**Example output:**
```
╔══════════════════════════════════════════╗
║       New-ADUserFromInput  v1.1          ║
╚══════════════════════════════════════════╝

[ Step 1 of 3 ]  Enter user details
First name: Jane
Last name: Smith
...
✔  AD account created successfully!
✔  Mailbox enabled successfully!
  Email address : jane.smith@yourdomain.com
```

**Handover summary printed at the end:**
```
─────────────────────────────────────────
Jane Smith
jane.smith@yourdomain.com
TealPenguinRocket47!

Done:  Groups
To Do: Licences / Migrate to Exchange Online
─────────────────────────────────────────
```

---

## `Get-User.ps1`

**Queries Active Directory for users by department and returns key details.**

A quick one-liner style script that filters AD users by department (supports wildcards) and outputs their name, department, description, and UPN in a clean table.

**Requirements:** `ActiveDirectory` module.

**Usage:**
```powershell
.\Get-User.ps1
```

**Script:**
```powershell
# Filter by department, Select Name, Department and User Email.
Get-ADUser -Filter {Department -like "Cargo*"} -Properties Department, Description |
Select-Object Name, Department, Description, UserPrincipalName
```

> 💡 Modify the `-Filter` value to target any department. Supports wildcards (`*`).

---

## `Get-UserGroups.ps1`

**Interactively looks up a user in AD and displays all their group memberships, split by Security and Distribution groups.**

Accepts a username, full name, or email address. Handles multiple matches with a selection prompt. Outputs a colour-coded summary of the user's details and group memberships.

**Requirements:** `ActiveDirectory` module.

**Modules required:**
```powershell
#Requires -Module ActiveDirectory
```

**Usage:**
```powershell
.\Get-UserGroups.ps1
```

**Example output:**
```
╔══════════════════════════════════════════╗
║         Get-UserGroups  v1.0             ║
╚══════════════════════════════════════════╝

Enter username, full name, or email address: jane.smith

══════════════════════════════════════════
  User Details
══════════════════════════════════════════
  Name           : Jane Smith
  SAMAccountName : Jane Smith
  Email          : jane.smith@yourdomain.com
  Account status : Enabled
══════════════════════════════════════════

  Group Memberships (5 total)

  [ Security Groups ]
    IT-Staff;
    VPN-Users;

  [ Distribution Groups ]
    All-Staff;
    Cargo-Team;
```

---

## `Get-DistributionLists.ps1`

**Pulls all Distribution Lists from Active Directory and exports them to CSV.**

Queries AD for all distribution groups (security groups excluded), returns name, display name, email address, scope, description, managed by, and creation date. Exports to `C:\Reports\DistributionLists.csv` and displays a summary with counts.

**Requirements:** `ActiveDirectory` module, RSAT installed, domain-joined machine or DC.

**Usage:**
```powershell
.\Get-DistributionLists.ps1
```

**Output path** (configurable at the top of the script):
```powershell
$OutputPath = "C:\Reports\DistributionLists.csv"
```

**Example console output:**
```
Querying Active Directory for Distribution Lists...

Results:
  Total DLs found : 42
  With email      : 39
  Without email   : 3

Exported to: C:\Reports\DistributionLists.csv
```

---

## AD Account Creator

A standalone desktop tool for creating Active Directory user accounts — pairs a Python GUI with a PowerShell backend that performs the actual AD work.

**What it does**
- Single-page workflow: enter identity + job details, optionally copy group membership from an existing user, select a manager, pick a target OU, then create the account.
- PowerShell backend (`ADUserBackend.ps1`) handles the actual AD creation — the GUI only collects and passes data.
- Fully reusable across environments: domain, OU list, naming conventions, contractor rules, and Exchange settings are all driven by `settings.ini`, so no code changes are needed to redeploy at another company.
- Optional on-prem Exchange mailbox enablement.
- Configurable post-creation to-do checklist shown after account creation.
- Logs every run (with password redaction) to `logs/`.

**Requirements**
- Windows with Python 3 and PowerShell available
- `customtkinter` (`python -m pip install customtkinter`)
- RSAT / Active Directory PowerShell module
- Permissions to create users (and optionally set manager, copy groups, enable mailbox) in the target OU

Full setup instructions, `settings.ini` reference, and troubleshooting are in the [project's README](./ad%20user%20creator/README.md).

---

⬅ [Back to main README](../../README.md)