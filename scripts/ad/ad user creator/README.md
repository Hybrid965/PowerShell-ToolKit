# AD Account Creator v4.0

AD Account Creator is a Windows desktop tool for creating Active Directory users through a Python GUI and a PowerShell backend.

The app is designed to be reusable across companies. Most environment-specific settings live in `settings.ini`, so the Python code should not need editing for normal deployment.

---

## What this application does

The application provides a single-page user creation workflow:

1. Enter the new user's identity details.
2. Enter job details such as job title, department, company, office and phone.
3. Optionally search for an existing user to copy group membership from.
4. Optionally search for and select a manager.
5. Select the target OU.
6. Create the account using the PowerShell backend.
7. View and copy the creation summary.
8. Work through the post-creation to-do checklist.

The GUI does not directly create the AD account. It collects the information and passes it to `ADUserBackend.ps1`.

---

## Requirements

Run the app on a Windows machine that has:

- Python 3 installed.
- PowerShell available as `powershell.exe`.
- Network access to Active Directory.
- The right RSAT / Active Directory PowerShell capability for the backend actions.
- Permissions to create users in the target OU.
- Permissions to copy group membership, set manager, and enable mailbox if those options are used.

Install the required Python GUI package with:

```powershell
python -m pip install customtkinter
```

If your machine uses the Python launcher instead of `python`, use:

```powershell
py -m pip install customtkinter
```

---

## Folder layout

Keep these files and folders together:

```text
ADAccountCreator_v4_Final\
├── main.py
├── settings.ini
├── ADUserBackend.ps1
├── VERSION.txt
├── README.md
├── core\
└── ui\
```

Important files:

| File | Purpose |
|---|---|
| `main.py` | Starts the application. |
| `settings.ini` | Environment-specific configuration. |
| `ADUserBackend.ps1` | PowerShell backend that performs AD actions. |
| `README.md` | This guide. |
| `VERSION.txt` | Version label. |
| `logs\` | Created automatically when the app runs. |

---

## How to run the application

1. Extract the ZIP file.
2. Open the extracted folder.
3. Click the address bar, type `powershell`, then press Enter.
4. Run:

```powershell
python .\main.py
```

Or:

```powershell
py .\main.py
```

Example:

```powershell
cd C:\Tools\ADAccountCreator_v4_Final
python .\main.py
```

---

## First-time setup checklist

Before using it in a new company/domain, check these items:

1. Confirm `settings.ini` contains the correct domain values.
2. Confirm the OU distinguished names are correct.
3. Confirm `BackendScript = ADUserBackend.ps1`.
4. Confirm the machine can run PowerShell scripts.
5. Confirm the signed-in/admin account has permission to create users.
6. Test by searching for an existing user.
7. Test with a safe test account before using it for a real starter.

---

# Editing `settings.ini`

Open `settings.ini` in Notepad, VS Code, Notepad++ or another plain text editor.

Do not use Word.

INI files are split into sections like this:

```ini
[SectionName]
SettingName = Value
```

After changing `settings.ini`, close and reopen the app so the new settings are loaded.

---

## `[Company]`

Example:

```ini
[Company]
Name = Port of Dover
DefaultDomain = yourcompany.com
DefaultPhone = +44 (0)1304 240400
```

| Setting | What it does |
|---|---|
| `Name` | Optional company name shown by the app where supported. Leave blank for generic wording. |
| `DefaultDomain` | Default UPN/email suffix used by the form. Example: `company.com`. |
| `DefaultPhone` | Default telephone value inserted into the phone field. Leave blank if not needed. |

For another company, change it to something like:

```ini
[Company]
Name = Example Ltd
DefaultDomain = example.com
DefaultPhone = +44 (0)1234 567890
```

---

## `[ActiveDirectory]`

Example:

```ini
[ActiveDirectory]
NetBIOSDomain = default
DnsDomain = default.local
DefaultOU = User
```

| Setting | What it does |
|---|---|
| `NetBIOSDomain` | Short AD domain name, used for domain-style credentials and backend calls. Example: `yourcompany`, `DEFAULT`, `FRESCA`. |
| `DnsDomain` | Internal AD DNS domain. Example: `yourcompany.local` or `corp.example.com`. |
| `DefaultOU` | The OU option selected by default when the app opens. This must match one of the names under `[OUOptions]`. |

Important: `DefaultOU` is not the full OU path. It is the display name of one of the OU options.

Example:

```ini
[ActiveDirectory]
DefaultOU = Standard Users

[OUOptions]
Standard Users = OU=Users,OU=Company,DC=example,DC=local
```

---

## `[UserNaming]`

This section controls how the app auto-generates names and usernames.

Current example:

```ini
[UserNaming]
SamAccountName = {first} {last}
UPN = {first}.{last}
Email = {upn}@{domain}
DisplayName = {first} {last}
Description = {job_title}
```

Available tokens:

| Token | Example value |
|---|---|
| `{first}` | `Will` |
| `{last}` | `Burkert` |
| `{first_initial}` | `W` |
| `{last_initial}` | `B` |
| `{first[0]}` | `W` |
| `{last[0]}` | `B` |
| `{display}` | `Will Burkert` |
| `{upn}` | `will.burkert` |
| `{sam}` | `Will Burkert` |
| `{domain}` | `yourcompany.com` |
| `{job_title}` | `IT Analyst` |

Common naming examples:

### First name dot last name

```ini
SamAccountName = {first}.{last}
UPN = {first}.{last}
Email = {upn}@{domain}
DisplayName = {first} {last}
```

Result:

```text
SamAccountName: will.burkert
UPN: will.burkert@yourcompany.com
Email: will.burkert@yourcompany.com
Display name: Will Burkert
```

### First initial plus surname

```ini
SamAccountName = {first_initial}{last}
UPN = {first_initial}{last}
Email = {upn}@{domain}
DisplayName = {first} {last}
```

Result:

```text
SamAccountName: wburkert
UPN: wburkert@yourcompany.com
Email: wburkert@yourcompany.com
Display name: Will Burkert
```

### Last name comma first name display format

```ini
SamAccountName = {first}.{last}
UPN = {first}.{last}
Email = {upn}@{domain}
DisplayName = {last}, {first}
```

Result:

```text
Display name: Burkert, Will
```

Note: `SamAccountName` in Active Directory has a 20-character limit. The app validates this before account creation.

## `[Exchange]`

Example:

```ini
[Exchange]
Enabled = true
Server = exchange.yourcompany.local
```

| Setting | What it does |
|---|---|
| `Enabled` | Enables or disables Exchange mailbox steps in the backend. Use `true` or `false`. |
| `Server` | Exchange server name/FQDN passed to the backend. |

If the company does not use on-prem Exchange mailbox creation, set:

```ini
[Exchange]
Enabled = false
Server = 
```

The GUI also has a `Skip mailbox creation` checkbox for individual accounts.

---

## `[Paths]`

Example:

```ini
[Paths]
BackendScript = ADUserBackend.ps1
```

Usually, leave this as:

```ini
BackendScript = ADUserBackend.ps1
```

The backend script should be in the same folder as `main.py`.

You can use a full path if required:

```ini
BackendScript = C:\Tools\ADAccountCreator\ADUserBackend.ps1
```

But the recommended setup is to keep it simple and keep the backend inside the app folder.

---

## `[OUOptions]`

This section controls the OU radio buttons shown in the GUI.

Example:

```ini
[OUOptions]
User = OU=Users,OU=DEFAULT (Users and Groups),DC=COMPANY,DC=local
Cargo = OU=Users,OU=CARGO,DC=COMPANY,DC=local
IT = OU=Users - Standard,OU=DEFAULT IT,DC=COMPANY,DC=local
```

The left side is the friendly name shown in the app.

The right side is the full OU distinguished name.

Format:

```ini
Friendly Name = OU path
```

Example for another company:

```ini
[OUOptions]
Standard Users = OU=Standard Users,OU=Users,DC=example,DC=local
IT Users = OU=IT,OU=Users,DC=example,DC=local
External Users = OU=External Users,OU=Users,DC=example,DC=local
```

The `DefaultOU` value under `[ActiveDirectory]` must match one of these friendly names.

Correct:

```ini
[ActiveDirectory]
DefaultOU = Standard Users

[OUOptions]
Standard Users = OU=Standard Users,OU=Users,DC=example,DC=local
```

Incorrect:

```ini
[ActiveDirectory]
DefaultOU = OU=Standard Users,OU=Users,DC=example,DC=local
```

---

## `[TodoItems]`

This controls the post-account-creation checklist shown in the summary panel.

Example:

```ini
[TodoItems]
01 = Groups
02 = Migrate to Exchange Online
03 = Licences
04 = Update Mobile Number in AD
05 = Update Phone in Fresh
06 = Update Daisy / O2
```

You can rename, remove or add items.

Example:

```ini
[TodoItems]
01 = Add Microsoft 365 licence
02 = Add to required groups
03 = Send welcome email
04 = Create hardware request
05 = Update HR system
```

Use numbers to control the order.

---

# Example full `settings.ini` for another company

```ini
[Company]
Name = Example Ltd
DefaultDomain = example.com
DefaultPhone = +44 (0)1234 567890

[ActiveDirectory]
NetBIOSDomain = EXAMPLE
DnsDomain = example.local
DefaultOU = Standard Users

[UserNaming]
SamAccountName = {first_initial}{last}
UPN = {first_initial}{last}
Email = {upn}@{domain}
DisplayName = {first} {last}
Description = {job_title}

[Exchange]
Enabled = false
Server = 

[Paths]
BackendScript = ADUserBackend.ps1

[OUOptions]
Standard Users = OU=Standard Users,OU=Users,DC=example,DC=local
IT Users = OU=IT,OU=Users,DC=example,DC=local
External Users = OU=External Users,OU=Users,DC=example,DC=local

[TodoItems]
01 = Add Microsoft 365 licence
02 = Add required groups
03 = Send starter details
04 = Update HR system
```

---

# Troubleshooting

## Python is not recognised

Try:

```powershell
py .\main.py
```

If that also fails, install Python from your company software portal or from the official Python installer.

---

## `customtkinter` is missing

Run:

```powershell
python -m pip install customtkinter
```

Or:

```powershell
py -m pip install customtkinter
```

---

## PowerShell blocks the script

From inside the app folder, run:

```powershell
Unblock-File .\ADUserBackend.ps1
Unblock-File .\main.py
```

Then run the app again.

---

## Backend script missing

Confirm this file exists in the same folder as `main.py`:

```text
ADUserBackend.ps1
```

Then confirm `settings.ini` says:

```ini
[Paths]
BackendScript = ADUserBackend.ps1
```

---

## Default OU warning

If the app says the default OU is invalid, check this:

```ini
[ActiveDirectory]
DefaultOU = User
```

The value must exactly match one of the names under `[OUOptions]`:

```ini
[OUOptions]
User = OU=Users,OU=DEFAULT (Users and Groups),DC=COMPANY,DC=local
```

Spelling, spacing and case should be kept consistent.

---

## Searches return no results

Check:

- The PC is domain joined.
- The account running the search can read AD.
- `NetBIOSDomain` and `DnsDomain` are correct.
- The backend can run without being blocked.
- You are searching for a real display name, username or email address.

---

## Account creation fails

Check the GUI log folder:

```text
logs\app_YYYYMMDD.log
```

Also check the visible log panel in the application.

Common causes:

- Admin credentials were entered incorrectly.
- The admin account does not have permission to create users in the selected OU.
- The OU distinguished name is wrong.
- The username already exists.
- Exchange is enabled but the Exchange server is not reachable.
- Required AD/Exchange PowerShell modules are missing on the machine.

---

# Release notes

## v4.0 Final

- Modular Python project layout.
- Cleaner UI structure.
- Improved UI polish.
- Startup checks for required files and settings.
- GUI-side log file creation.
- Better form validation.
- Safer backend command logging with password redaction.
- Backend path standardised to `ADUserBackend.ps1`.
- Clean `settings.ini` with detailed instructions moved into this README.

No new account-creation workflow features were added in v4.0.


## v4.0.1 Hotfix

Fixed the GUI-to-PowerShell argument passed for `-ExchangeEnabled`. It is now passed as `1` or `0` so PowerShell can bind it correctly to the backend `[bool]` parameter.


## v4.0.2 Hotfix

Fixed `ExchangeEnabled` parameter binding when launched from Python using `subprocess` argument lists. The backend now accepts the value as an object/string and normalises `1`, `0`, `true`, `false`, `$true`, and `$false` into a real Boolean before mailbox logic runs.
