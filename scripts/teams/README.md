# 👥 Microsoft Teams

PowerShell scripts and tools for managing Microsoft Teams, including Team creation, bulk membership management, and user removal.

⬅ [Back to main README](../../README.md)

---

## 📋 Contents

- [`New-Team.ps1`](#new-teamps1)
- [`Add-PeopleToTeam.ps1`](#add-peopleto-teamps1)
- [`Remove-PeopleFromTeam.ps1`](#remove-peoplefrom-teamps1)

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| **MicrosoftTeams PowerShell module** | Required for all scripts in this section |
| **Microsoft 365 / Teams access** | Required to access and modify Microsoft Teams |
| **Appropriate Teams permissions** | Required to create Teams and add/remove members |
| **PowerShell** | Windows PowerShell or PowerShell 7 |
| **CSV file** | Required for bulk membership operations |

The scripts automatically install the `MicrosoftTeams` module if it is not already installed.

You can also install the module manually:

```powershell
Install-Module MicrosoftTeams -Force -Scope CurrentUser
```

---

## `New-Team.ps1`

**Creates a new private Microsoft Team and optionally bulk-adds Members or Owners from a CSV file.**

This script provides an interactive workflow for creating a new Microsoft Team. It prompts for the Team name and description, displays a confirmation before creating the Team, waits for Microsoft Teams provisioning to complete, and optionally imports users from a CSV file.

Users can be added as either **Members** or **Owners** using the `Role` column in the CSV.

### **What it does — step by step**

1. Checks that the `MicrosoftTeams` module is available
2. Installs the module automatically if required
3. Connects to Microsoft Teams if not already connected
4. Prompts for the new Team name
5. Prompts for the Team description
6. Displays the Team details for confirmation
7. Creates the Team as **Private**
8. Waits for the Team to finish provisioning
9. Asks whether Members/Owners should be bulk-added
10. Prompts for the CSV path
11. Validates the CSV
12. Validates each user's role
13. Adds each user to the newly created Team
14. Reports successful and failed additions
15. Displays a final summary

### **Requirements**

```powershell
#Requires -Module MicrosoftTeams
```

### **Usage**

```powershell
.\New-Team.ps1
```

### **Configuration**

The default CSV location and provisioning wait time can be configured at the top of the script:

```powershell
$DefaultCsvPath      = "C:\users.csv"
$ProvisioningWaitSec = 15
```

`$DefaultCsvPath` is used when no CSV path is entered at the prompt.

`$ProvisioningWaitSec` controls how long the script waits for the newly created Team to finish provisioning before attempting to add users.

### **CSV format**

The CSV must contain an `Email` and `Role` column:

```csv
Email,Role
john.smith@domain.com,Member
jane.doe@domain.com,Owner
bob.jones@domain.com,Member
```

The `Role` value must be either:

```text
Member
Owner
```

### **Team visibility**

Teams created by this script are automatically created as **Private**:

```powershell
New-Team -DisplayName $TeamName `
         -Description $TeamDescription `
         -Visibility Private
```

### **Example**

```text
╔══════════════════════════════════════════╗
║       Microsoft Team Creator  v1.0       ║
╚══════════════════════════════════════════╝

Enter the name of the team: IT Support

Enter the description: IT Support Team

You are about to create:
  Name        : IT Support
  Description : IT Support Team

Proceed with team creation? (Y/N): Y

✔  Team 'IT Support' created successfully!

Adding 3 user(s) to 'IT Support'...

✔  Added john.smith@domain.com as Member
✔  Added jane.doe@domain.com as Owner
✔  Added bob.jones@domain.com as Member

─────────────────────────────────────────
Team          : IT Support
Added         : 3
Failed        : 0
─────────────────────────────────────────
```

### **Skipping bulk membership**

Bulk membership can be skipped when creating the Team:

```text
Add Members/Owners from CSV? (Y/N): N
```

The Team will still be created:

```text
Done! Team 'IT Support' created with no bulk-added members.
```

### **Failed users**

If an individual user cannot be added, the script continues processing the remaining users.

Failed users are displayed in the final summary:

```text
─────────────────────────────────────────
Team          : IT Support
Added         : 2
Failed        : 1
Failed users  : user1@domain.com
─────────────────────────────────────────
```

---

## `Add-PeopleToTeam.ps1`

**Adds multiple users to an existing Microsoft Team as Members or Owners using a CSV file.**

This script provides an interactive way to bulk-add users to an existing Microsoft Team.

It connects to Microsoft Teams, searches for the requested Team, handles situations where multiple Teams have the same name, and requires confirmation before making changes.

Users and their roles are read from a CSV file.

### **What it does — step by step**

1. Checks that the `MicrosoftTeams` module is available
2. Installs the module automatically if required
3. Connects to Microsoft Teams if not already connected
4. Prompts for the name of the Team
5. Searches for matching Teams
6. Allows the administrator to select the correct Team if multiple matches are found
7. Displays the Team name and Group ID for confirmation
8. Requires confirmation before making changes
9. Prompts for the CSV file path
10. Validates that the CSV contains `Email` and `Role` columns
11. Validates that each role is either `Member` or `Owner`
12. Adds each user to the selected Team
13. Reports successful and failed additions
14. Displays a final summary

### **Requirements**

```powershell
#Requires -Module MicrosoftTeams
```

### **Usage**

```powershell
.\Add-PeopleToTeam.ps1
```

### **Configuration**

The default CSV location can be changed at the top of the script:

```powershell
$DefaultCsvPath = "C:\users.csv"
```

If you press **Enter** when prompted for the CSV path, this default location will be used.

### **CSV format**

```csv
Email,Role
john.smith@domain.com,Member
jane.doe@domain.com,Owner
bob.jones@domain.com,Member
```

### **Example**

```text
╔══════════════════════════════════════════╗
║        Add People To Team  v1.0          ║
╚══════════════════════════════════════════╝

Enter the name of the team: IT Support

Found team:
  Name    : IT Support
  GroupId : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Is this the correct team? (Y/N): Y

Enter CSV path (press Enter for default: C:\users.csv):

Adding 2 user(s) to 'IT Support'...

✔  Added john.smith@domain.com as Member
✔  Added jane.doe@domain.com as Owner

─────────────────────────────────────────
Team          : IT Support
Added         : 2
Failed        : 0
─────────────────────────────────────────
```

### **Failed users**

If a user cannot be added, the script continues processing the remaining users rather than stopping completely.

Failed users are displayed at the end:

```text
─────────────────────────────────────────
Team          : IT Support
Added         : 8
Failed        : 2
Failed users  : user1@domain.com, user2@domain.com
─────────────────────────────────────────
```

---

## `Remove-PeopleFromTeam.ps1`

**Removes users from an existing Microsoft Team using either a CSV file or a single email address.**

This script is designed for both bulk and individual user removal.

It connects to Microsoft Teams, identifies the requested Team, and requires confirmation before making any changes.

Users can be supplied through a CSV file or entered individually.

### **What it does — step by step**

1. Checks that the `MicrosoftTeams` module is available
2. Installs the module automatically if required
3. Connects to Microsoft Teams if not already connected
4. Prompts for the name of the Team
5. Searches for matching Teams
6. Allows the administrator to select the correct Team if multiple matches are found
7. Displays the Team name and Group ID for confirmation
8. Requires confirmation before making changes
9. Allows either bulk CSV removal or single-user removal
10. Validates the CSV if bulk removal is selected
11. Displays the complete list of users that will be removed
12. Requires a final confirmation
13. Checks whether each user is actually a member of the Team
14. Removes users from the Team
15. Handles Team Owners explicitly when required
16. Reports successful and failed removals
17. Displays a final summary

### **Requirements**

```powershell
#Requires -Module MicrosoftTeams
```

### **Usage**

```powershell
.\Remove-PeopleFromTeam.ps1
```

### **Configuration**

The default CSV location can be changed at the top of the script:

```powershell
$DefaultCsvPath = "C:\users.csv"
```

### **CSV format**

Only an `Email` column is required:

```csv
Email
john.smith@domain.com
jane.doe@domain.com
bob.jones@domain.com
```

A `Role` column is optional and will be ignored if present.

This means a CSV created for `Add-PeopleToTeam.ps1` can also be reused:

```csv
Email,Role
john.smith@domain.com,Member
jane.doe@domain.com,Owner
```

### **Bulk removal**

When prompted:

```text
Remove users from a CSV file? (Y/N — 'N' lets you remove a single user by email)
```

Enter:

```text
Y
```

The script will then request the CSV path:

```text
Enter CSV path (press Enter for default: C:\users.csv):
```

### **Single-user removal**

To remove one user without creating a CSV, enter:

```text
N
```

The script will then prompt for the user's email address:

```text
Enter the email address to remove: john.smith@domain.com
```

### **Safety confirmations**

The script confirms the selected Team before making changes:

```text
Found team:
  Name    : IT Support
  GroupId : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Is this the correct team? (Y/N)
```

It then displays the exact users that will be removed:

```text
The following 3 user(s) will be removed from 'IT Support':

  - john.smith@domain.com
  - jane.doe@domain.com
  - bob.jones@domain.com

Proceed with removal? (Y/N)
```

### **Example**

```text
╔══════════════════════════════════════════╗
║      Remove People From Team  v1.0       ║
╚══════════════════════════════════════════╝

Enter the name of the team: IT Support

Found team:
  Name    : IT Support
  GroupId : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Is this the correct team? (Y/N): Y

Remove users from a CSV file? (Y/N — 'N' lets you remove a single user by email): Y

The following 2 user(s) will be removed from 'IT Support':

  - john.smith@domain.com
  - jane.doe@domain.com

Proceed with removal? (Y/N): Y

Removing users from 'IT Support'...

✔  Removed john.smith@domain.com
✔  Removed jane.doe@domain.com

─────────────────────────────────────────
Team          : IT Support
Removed       : 2
Failed        : 0
─────────────────────────────────────────
```

### **Owner handling**

The script checks the user's current Team role before removing them.

If the user is an **Owner**, the script explicitly removes them using the Owner role:

```powershell
Remove-TeamUser -GroupId $team.GroupId -User $email -Role Owner
```

This allows Team Owners to be handled correctly during removal.

---

## 🔄 Typical Workflows

These scripts are designed to work together as a Microsoft Teams administration toolkit.

### **1. Create a Team with users**

Create a CSV:

```csv
Email,Role
john.smith@domain.com,Member
jane.doe@domain.com,Member
bob.jones@domain.com,Owner
```

Run:

```powershell
.\New-Team.ps1
```

Enter the Team name and description, confirm creation, then provide the CSV when prompted.

---

### **2. Create an empty Team**

Run:

```powershell
.\New-Team.ps1
```

When asked:

```text
Add Members/Owners from CSV? (Y/N): N
```

The Team will be created without any bulk-added users.

Users can then be added later using:

```powershell
.\Add-PeopleToTeam.ps1
```

---

### **3. Add users to an existing Team**

Create a CSV:

```csv
Email,Role
john.smith@domain.com,Member
jane.doe@domain.com,Member
bob.jones@domain.com,Owner
```

Run:

```powershell
.\Add-PeopleToTeam.ps1
```

---

### **4. Remove users from a Team**

Use either a CSV:

```csv
Email
john.smith@domain.com
jane.doe@domain.com
```

Then run:

```powershell
.\Remove-PeopleFromTeam.ps1
```

Or remove a single user directly by selecting the individual-user option.

---

## 📁 Files

| File | Purpose |
|---|---|
| `New-Team.ps1` | Creates a new private Microsoft Team and optionally bulk-adds Members or Owners |
| `Add-PeopleToTeam.ps1` | Bulk-adds users to an existing Team as Members or Owners |
| `Remove-PeopleFromTeam.ps1` | Removes users from an existing Team using CSV or individual email |

---

## ⚠️ Notes

- `New-Team.ps1` creates Teams as **Private**.
- The scripts operate on Microsoft Teams using the `MicrosoftTeams` PowerShell module.
- `New-Team.ps1` can create the Team and populate it in a single workflow.
- `Add-PeopleToTeam.ps1` is intended for adding users to existing Teams.
- `Remove-PeopleFromTeam.ps1` supports both bulk CSV removal and individual user removal.
- Adding or removing users requires appropriate Microsoft Teams permissions.
- Removing a user from a Team does **not** delete their Microsoft 365 account.
- Always verify the Team before confirming changes.
- For bulk operations, review the CSV before running the script.
- Failed users are reported without stopping the entire operation.
- The same `Email,Role` CSV can be used with both `New-Team.ps1` and `Add-PeopleToTeam.ps1`.
- The `Role` column is not required when using `Remove-PeopleFromTeam.ps1`.