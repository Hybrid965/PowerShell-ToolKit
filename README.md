# ⚡ PowerShell Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Azure](https://img.shields.io/badge/Microsoft_Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active_Directory-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Microsoft Teams](https://img.shields.io/badge/Microsoft_Teams-6264A7?style=for-the-badge&logo=microsoft-teams&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

> A personal collection of PowerShell scripts for Azure cloud automation, Active Directory management, Microsoft Teams administration, and media processing.



## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Scripts](#-scripts)
  - [👤 Active Directory](#-active-directory)
  - [💬 Microsoft Teams](#-microsoft-teams)
  - [🎬 Media Processing](#-media-processing)
- [Folder Structure](#-folder-structure)
- [Notes](#-notes)



## ✅ Prerequisites

| Requirement | Details |
|---|---|
| **PowerShell** | Version 7.x recommended (`pwsh`) |
| **RSAT / AD Module** | Required for all Active Directory scripts |
| **MicrosoftTeams Module** | Required for Teams scripts — auto-installed by scripts if missing |
| **Exchange Access** | Required for mailbox provisioning (`Create-User-AddToExchange.ps1`) |
| **FFMPEG** | Required for media conversion scripts — see [FFMPEG Setup](#ffmpeg-setup) |
| **Domain-joined machine** | Required for AD and Exchange scripts |



## 🚀 Getting Started

1. **Clone the repository**

```bash
git clone https://github.com/<your-username>/PowerShell-Toolkit.git
cd PowerShell-Toolkit
```

2. **Install the Active Directory module** (if not already installed)

```powershell
# Install RSAT on Windows 10/11
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

3. **Install the Teams module** (scripts will do this automatically, but you can pre-install)

```powershell
Install-Module MicrosoftTeams -Force
```

4. **Run any script**

```powershell
.\scripts\<ScriptName>.ps1
```

> 💡 All interactive scripts will guide you through prompts — no flags required to get started.



## 📁 Scripts



### 👤 Active Directory



#### `Create-User-AddToExchange.ps1`

**Creates a new AD user account and provisions their Exchange mailbox in one flow.**

This is a full end-to-end onboarding script. It collects user details interactively, optionally copies attributes and group memberships from an existing user (excluding licensing groups), generates a secure random password, creates the AD account, waits for replication, then connects to the on-prem Exchange server to enable the mailbox and set the primary SMTP address.

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
.\scripts\Create-User-AddToExchange.ps1
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



#### `Get-User.ps1`

**Queries Active Directory for users by department and returns key details.**

A quick one-liner style script that filters AD users by department (supports wildcards) and outputs their name, department, description, and UPN in a clean table.

**Requirements:** `ActiveDirectory` module.

**Usage:**
```powershell
.\scripts\Get-User.ps1
```

**Script:**
```powershell
# Filter by department, Select Name, Department and User Email.
Get-ADUser -Filter {Department -like "Cargo*"} -Properties Department, Description |
Select-Object Name, Department, Description, UserPrincipalName
```

> 💡 Modify the `-Filter` value to target any department. Supports wildcards (`*`).



#### `Get-UserGroups.ps1`

**Interactively looks up a user in AD and displays all their group memberships, split by Security and Distribution groups.**

Accepts a username, full name, or email address. Handles multiple matches with a selection prompt. Outputs a colour-coded summary of the user's details and group memberships.

**Requirements:** `ActiveDirectory` module.

**Modules required:**
```powershell
#Requires -Module ActiveDirectory
```

**Usage:**
```powershell
.\scripts\Get-UserGroups.ps1
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



#### `Get-DistributionLists.ps1`

**Pulls all Distribution Lists from Active Directory and exports them to CSV.**

Queries AD for all distribution groups (security groups excluded), returns name, display name, email address, scope, description, managed by, and creation date. Exports to `C:\Reports\DistributionLists.csv` and displays a summary with counts.

**Requirements:** `ActiveDirectory` module, RSAT installed, domain-joined machine or DC.

**Usage:**
```powershell
.\scripts\Get-DistributionLists.ps1
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



### 💬 Microsoft Teams



#### `Create-Team-AddMembers.ps1`

**Creates a new Microsoft Teams team interactively, then optionally bulk-adds members from a CSV.**

Prompts for team name and description, creates the team, shows a provisioning progress bar while waiting for the team to be ready, then optionally imports members and owners from a CSV file.

**Requirements:** `MicrosoftTeams` module (auto-installed if missing), Microsoft 365 admin or Teams admin account.

**Usage:**
```powershell
.\scripts\Create-Team-AddMembers.ps1
```

**CSV format** — place at `C:\users.csv`:

| Email | Role |
|||
| john.smith@domain.com | Member |
| jane.doe@domain.com | Owner |
| bob.jones@domain.com | Member |

**Example output:**
```
╔══════════════════════════════════════════╗
║       Microsoft Team Creator  v1.0       ║
╚══════════════════════════════════════════╝

Enter the name of the team...: Project Phoenix
Enter the description: Cross-functional delivery team

[Provisioning Team... ██████████ 15/15 seconds]

Add Members? (Y/N): Y
Added john.smith@domain.com
Added jane.doe@domain.com
Done! Team 'Project Phoenix' created.
```



#### `Add-PeopleToTeam.ps1`

**Bulk-adds users to an existing Teams group from a CSV file.**

Prompts for the team name, confirms the correct team is selected before making any changes, then imports users from a CSV and adds them with the specified role.

**Requirements:** `MicrosoftTeams` module (auto-installed if missing), Microsoft 365 admin or Teams admin account.

**Usage:**
```powershell
.\scripts\Add-PeopleToTeam.ps1
```

**CSV format** — place at `C:\users.csv`:

| Email | Role |
|---|---|
| john.smith@domain.com | Member |
| jane.doe@domain.com | Owner |

> 💡 The script confirms the team name before adding anyone — it won't proceed until you confirm it has found the right team.



### 🎬 Media Processing



#### `Convert-MP4toFLV.ps1`

**Batch converts MP4 files to FLV format using FFMPEG, then removes the originals.**

Useful for making CCTV footage or video files viewable directly in SharePoint (which supports FLV playback). Converts all `.mp4` files in the target directory, creates a subfolder per file in a `Converted CCTV` output folder, then deletes the source MP4s.

**Requirements:** FFMPEG installed and added to PATH — see [FFMPEG Setup](#ffmpeg-setup) below.

**Usage:**
```powershell
.\scripts\Convert-MP4toFLV.ps1
```

> ⚠️ **Update the paths** at the top of the script to match your environment before running:
```powershell
# Source folder containing MP4 files
cd "C:\Users\YourName\CCTV"

# Output folder for converted files
$outputfolder = "C:\Users\YourName\CCTV\Converted CCTV\$base"
```

**What it does:**
1. Gets all `.mp4` files in the working directory
2. Creates a subfolder per video in the `Converted CCTV` output folder
3. Converts each file using `ffmpeg -c:v h264`
4. Removes all original `.mp4` files from the source folder



#### FFMPEG Setup

FFMPEG is required for the media conversion script. Install it once and it will be available to all scripts.

1. Download FFMPEG from [ffmpeg.org](https://ffmpeg.org/download.html)
2. Extract and move the folder to `C:\ffmpeg`
3. Add `C:\ffmpeg\bin` to your system **PATH** environment variable:
   - Open **System Properties** → **Environment Variables**
   - Under **System variables**, select `Path` → **Edit**
   - Add `C:\ffmpeg\bin`
4. Verify the install:

```powershell
ffmpeg -version
```



## 📂 Folder Structure

```
PowerShell-Toolkit/
│
├── scripts/
│   ├── ad/
│   │   ├── Create-User-AddToExchange.ps1
│   │   ├── Get-User.ps1
│   │   ├── Get-UserGroups.ps1
│   │   └── Get-DistributionLists.ps1
│   │
│   ├── teams/
│   │   ├── Create-Team-AddMembers.ps1
│   │   └── Add-PeopleToTeam.ps1
│   │
│   └── media/
│       └── Convert-MP4toFLV.ps1
│
└── README.md
```



## 🔒 Notes

- These scripts are for **personal/private use** and come with no warranty.
- Always review a script before running it against production systems.
- Sensitive values (domain names, OUs, server URIs) are configurable at the top of each script — never hardcode credentials.
- Scripts that modify AD or Teams resources will prompt for confirmation before making changes.



*Built and maintained by Will · Margate, UK*