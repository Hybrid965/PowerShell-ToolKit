# ⚡ PowerShell Toolkit

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![Azure](https://img.shields.io/badge/Microsoft_Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Active Directory](https://img.shields.io/badge/Active_Directory-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![Microsoft Teams](https://img.shields.io/badge/Microsoft_Teams-6264A7?style=for-the-badge&logo=microsoft-teams&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-success?style=for-the-badge)

> A personal collection of PowerShell scripts and tools for Azure cloud automation, Active Directory management, Microsoft Teams administration, and media processing.

Each section below lives in its own folder with its own README covering requirements, usage, and configuration in detail. This page is just the index — click through for the full docs on any script or tool.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [Sections](#-sections)
  - [👤 Active Directory](#-active-directory)
  - [💬 Microsoft Teams](#-microsoft-teams)
  - [🎬 Media Processing](#-media-processing)
- [Folder Structure](#-folder-structure)
- [Notes](#-notes)

---

## ✅ Prerequisites

| Requirement | Details |
|---|---|
| **PowerShell** | Version 7.x recommended (`pwsh`) |
| **RSAT / AD Module** | Required for all Active Directory scripts |
| **MicrosoftTeams Module** | Required for Teams scripts — auto-installed by scripts if missing |
| **Exchange Access** | Required for mailbox provisioning scripts |
| **FFMPEG** | Required for media conversion scripts — see the [Media Processing README](./scripts/media/README.md#ffmpeg-setup) |
| **Domain-joined machine** | Required for AD and Exchange scripts |

Section-specific requirements (modules, permissions, extra software) are covered in each section's own README, linked below.

---

## 🚀 Getting Started

1. **Clone the repository**

```bash
git clone https://github.com/Hybrid965/PowerShell-ToolKit.git
cd PowerShell-ToolKit
```

2. **Open the section you need** and follow its README for setup and usage:

| Section | README |
|---|---|
| 👤 Active Directory | [`scripts/ad/README.md`](./scripts/ad/README.md) |
| 💬 Microsoft Teams | [`scripts/teams/README.md`](./scripts/teams/README.md) |
| 🎬 Media Processing | [`scripts/media/README.md`](./scripts/media/README.md) |

> 💡 All interactive scripts will guide you through prompts — no flags required to get started.

---

## 📁 Sections

### 👤 Active Directory

Scripts and tools for AD user provisioning, group and mailbox management, and reporting.

📄 **[Full documentation →](./scripts/ad/README.md)**

| Tool | Description |
|---|---|
| `Create-User-AddToExchange.ps1` | Creates an AD user and provisions their Exchange mailbox in one flow |
| `Get-User.ps1` | Queries AD users by department |
| `Get-UserGroups.ps1` | Looks up a user and lists their group memberships |
| `Get-DistributionLists.ps1` | Exports all Distribution Lists to CSV |
| `AD Account Creator` | Standalone Python GUI + PowerShell backend for reusable, config-driven AD account creation |

---

### 💬 Microsoft Teams

Scripts for creating teams and managing membership in bulk.

📄 **[Full documentation →](./scripts/teams/README.md)**

| Tool | Description |
|---|---|
| `Create-Team-AddMembers.ps1` | Creates a new Team and optionally bulk-adds members from CSV |
| `Add-PeopleToTeam.ps1` | Bulk-adds users to an existing Team from CSV |

---

### 🎬 Media Processing

Tools for converting and preparing video files.

📄 **[Full documentation →](./scripts/ffmpeg/README.md)**

| Tool | Description |
|---|---|
| `Convert-MP4toFLV.ps1` | Batch converts MP4 files to FLV using FFMPEG |

---

## 📂 Folder Structure

```
PowerShell-Toolkit/
│
├── scripts/
│   ├── ad/
│   │   ├── README.md
│   │   ├── Create-User-AddToExchange.ps1
│   │   ├── Get-User.ps1
│   │   ├── Get-UserGroups.ps1
│   │   └── Get-DistributionLists.ps1
│   │
│   ├── teams/
│   │   ├── README.md
│   │   ├── Create-Team-AddMembers.ps1
│   │   └── Add-PeopleToTeam.ps1
│   │
│   └── media/
│       ├── README.md
│       └── Convert-MP4toFLV.ps1
│
└── README.md
```

---

## 🔒 Notes

- These scripts are for **personal/private use** and come with no warranty.
- Always review a script before running it against production systems.
- Sensitive values (domain names, OUs, server URIs) are configurable at the top of each script — never hardcode credentials.
- Scripts that modify AD or Teams resources will prompt for confirmation before making changes.

---

*Built and maintained by Will · Margate, UK*