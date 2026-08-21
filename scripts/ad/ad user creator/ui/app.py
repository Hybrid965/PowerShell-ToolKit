"""
AD Account Creator v4.0 Final
Modern CustomTkinter front end for ADUserBackend.ps1.

What this version adds:
- Single-page user creation workflow
- Fixed, safer PowerShell search call handling
- Inline search result panels, no pop-up picker
- Copyable summary fields + Copy Entire Summary
- Interactive Still To Do checklist including Add Groups
- Better progress/status/log handling
- Final v4.0 release build with reliability checks, stronger validation, persistent logs, and polished UI

Run main.py from the project folder. Keep ADUserBackend.ps1 and settings.ini beside it.
"""

import ctypes
import getpass
import json
import os
import configparser
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
from datetime import datetime, timedelta
from dataclasses import dataclass
from tkinter import messagebox


def _ensure_package(package_name, import_name=None):
    import_name = import_name or package_name
    try:
        return __import__(import_name)
    except ImportError:
        print(f"{package_name} missing. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", package_name])
        return __import__(import_name)


_ensure_package("customtkinter")
import customtkinter as ctk


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
CONFIG_PATH = os.path.join(PROJECT_ROOT, "settings.ini")
LOG_DIR = os.path.join(PROJECT_ROOT, "logs")
APP_VERSION = "v4.0 Final"


def _write_app_log(level, message):
    """Write GUI-side events to logs/app_YYYYMMDD.log. Never raises."""
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        path = os.path.join(LOG_DIR, f"app_{datetime.now().strftime('%Y%m%d')}.log")
        stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(f"[{stamp}] [{str(level).upper()}] {message}\n")
    except Exception:
        pass


def _install_exception_logger():
    old_hook = sys.excepthook
    def hook(exc_type, exc, tb):
        _write_app_log("ERROR", "Unhandled exception:\n" + "".join(traceback.format_exception(exc_type, exc, tb)))
        old_hook(exc_type, exc, tb)
    sys.excepthook = hook


def _normalise_script_path(path):
    path = (path or "").strip().strip('"')
    if not path:
        return DEFAULT_BACKEND if "DEFAULT_BACKEND" in globals() else ""
    return path if os.path.isabs(path) else os.path.abspath(os.path.join(PROJECT_ROOT, path))


def _looks_like_dns_domain(value):
    return bool(re.fullmatch(r"(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}", value or ""))


def _looks_like_email(value):
    return bool(re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value or ""))


def _looks_like_dn(value):
    v = (value or "").strip()
    return bool(v and "DC=" in v.upper() and (v.upper().startswith("OU=") or v.upper().startswith("CN=")))


_install_exception_logger()


def _parse_bool(value, default=True):
    if value is None:
        return default
    return str(value).strip().lower() in ("1", "yes", "true", "on", "enabled")


def _load_settings():
    cfg = configparser.ConfigParser()
    cfg.optionxform = str  # preserve OU display names exactly as written
    if os.path.isfile(CONFIG_PATH):
        cfg.read(CONFIG_PATH, encoding="utf-8")

    company_name = cfg.get("Company", "Name", fallback="")
    default_phone = cfg.get("Company", "DefaultPhone", fallback="")
    default_domain = cfg.get("Company", "DefaultDomain", fallback="company.local")

    ad_netbios = cfg.get("ActiveDirectory", "NetBIOSDomain", fallback="")
    ad_dns = cfg.get("ActiveDirectory", "DnsDomain", fallback="")
    default_ou_name = cfg.get("ActiveDirectory", "DefaultOU", fallback="")

    exchange_enabled = _parse_bool(cfg.get("Exchange", "Enabled", fallback="true"), True)
    exchange_server = cfg.get("Exchange", "Server", fallback="")

    naming = {
        "sam": cfg.get("UserNaming", "SamAccountName", fallback="{first} {last}"),
        "upn": cfg.get("UserNaming", "UPN", fallback="{first}.{last}"),
        "email": cfg.get("UserNaming", "Email", fallback="{upn}@{domain}"),
        "display": cfg.get("UserNaming", "DisplayName", fallback="{first} {last}"),
        "description": cfg.get("UserNaming", "Description", fallback="{job_title}"),
    }

    contractor = {
        "ou_label": cfg.get("Contractor", "OULabel", fallback="Contractor"),
        "display_name": cfg.get("Contractor", "DisplayName", fallback="EXT_{display}"),
        "expiry_days": cfg.getint("Contractor", "ExpiryDays", fallback=90),
    }

    ou_options = dict(cfg.items("OUOptions")) if cfg.has_section("OUOptions") else {
        "POD User": "OU=Users,OU=POD (Users and Groups),DC=pod,DC=local",
        "Cargo": "OU=Users,OU=CARGO,DC=pod,DC=local",
        "Coast": "OU=Coast,OU=Users,OU=POD (Users and Groups),DC=pod,DC=local",
        "Contractor": "OU=Contractors - Synced,OU=Users,OU=POD (Users and Groups),DC=pod,DC=local",
        "POD IT": "OU=Users - Standard,OU=POD IT,DC=pod,DC=local",
    }

    todo_items = []
    if cfg.has_section("TodoItems"):
        todo_items = [v.strip() for _, v in sorted(cfg.items("TodoItems")) if v.strip()]
    if not todo_items:
        todo_items = [
            "Groups",
            "Migrate to Exchange Online",
            "Licences",
            "Update Mobile Number in AD",
            "Update Phone in Fresh",
            "Update Daisy / O2",
        ]

    backend = cfg.get("Paths", "BackendScript", fallback="ADUserBackend.ps1")
    backend_path = backend if os.path.isabs(backend) else os.path.join(PROJECT_ROOT, backend)
    if not os.path.isfile(backend_path):
        fallback_backend = os.path.join(PROJECT_ROOT, "ADUserBackend.ps1")
        backend_path = fallback_backend if os.path.isfile(fallback_backend) else backend_path

    return {
        "company_name": company_name,
        "default_phone": default_phone,
        "default_domain": default_domain,
        "ad_netbios": ad_netbios,
        "ad_dns": ad_dns,
        "default_ou_name": default_ou_name,
        "exchange_enabled": exchange_enabled,
        "exchange_server": exchange_server,
        "naming": naming,
        "contractor": contractor,
        "ou_options": ou_options,
        "todo_items": todo_items,
        "backend_path": backend_path,
    }


SETTINGS = _load_settings()
COMPANY_NAME = SETTINGS["company_name"]
DEFAULT_BACKEND = SETTINGS["backend_path"]
OU_OPTIONS = SETTINGS["ou_options"]
DEFAULT_OU_NAME = SETTINGS["default_ou_name"]
DEFAULT_OU = OU_OPTIONS.get(DEFAULT_OU_NAME, next(iter(OU_OPTIONS.values()), ""))
DEFAULT_DOMAIN = SETTINGS["default_domain"]
DEFAULT_PHONE = SETTINGS["default_phone"]
EXCHANGE_ENABLED = SETTINGS["exchange_enabled"]
EXCHANGE_SERVER = SETTINGS["exchange_server"]
NAMING = SETTINGS["naming"]
CONTRACTOR = SETTINGS["contractor"]

# Set to None to allow all signed-in Windows users.
AUTHORIZED_GROUP = None
AUTH_DOMAIN_NETBIOS = SETTINGS["ad_netbios"]
AUTH_DOMAIN_DNS = SETTINGS["ad_dns"]
AUTH_UPN_SUFFIX = SETTINGS["default_domain"]

TODO_ITEMS = SETTINGS["todo_items"]

COLORS = {
    "bg": "#0B1120",
    "surface": "#101827",
    "surface_alt": "#162033",
    "card": "#172033",
    "card2": "#223047",
    "card_hover": "#2B3D59",
    "border": "#2E3B52",
    "border_soft": "#243247",
    "text": "#EAF0F8",
    "muted": "#9AA8BC",
    "muted2": "#718096",
    "accent": "#38BDF8",
    "accent_hover": "#0EA5E9",
    "success": "#22C55E",
    "success_hover": "#16A34A",
    "warn": "#F59E0B",
    "error": "#EF4444",
}

UI = {
    "page_pad": 18,
    "gap": 14,
    "card_radius": 18,
    "entry_h": 38,
    "button_h": 38,
}

LOG_COLORS = {
    "INFO": COLORS["warn"],      # yellow
    "WARN": "#FBBF24",          # stronger yellow/amber
    "ERROR": COLORS["error"],    # red
    "SUCCESS": COLORS["success"],# green
}

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


@dataclass
class AuthResult:
    allowed: bool
    user: str
    message: str


class BackendRunner:
    def __init__(self, app):
        self.app = app
        self.proc = None

    def run(self, args, mode, set_busy=True, log_command=True):
        script = _normalise_script_path(self.app.script_path.get().strip() or DEFAULT_BACKEND)
        if not os.path.isfile(script):
            messagebox.showerror("Backend script missing", f"Could not find:\n{script}")
            self.app._log("ERROR", f"Backend script missing: {script}")
            return False
        if shutil.which("powershell.exe") is None and shutil.which("powershell") is None and shutil.which("pwsh") is None:
            messagebox.showerror("PowerShell missing", "PowerShell was not found on PATH. This app must run on a Windows machine with PowerShell available.")
            self.app._log("ERROR", "PowerShell executable was not found on PATH.")
            return False
        exe = shutil.which("powershell.exe") or shutil.which("powershell") or shutil.which("pwsh")
        cmd = [exe, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script] + args
        safe_args = []
        hide_next = False
        for a in args:
            text = str(a)
            if hide_next:
                safe_args.append("********")
                hide_next = False
                continue
            if text.lower().startswith(("-adminpassword=", "-password=")):
                safe_args.append(text.split("=", 1)[0] + "=********")
            else:
                safe_args.append(text)
            if text.lower() in ("-adminpassword", "-password"):
                hide_next = True
        if log_command:
            self.app._log("INFO", f"Backend path: {script}")
            self.app._log("INFO", "PowerShell args: " + " ".join(safe_args))
        self.app.current_mode = mode
        if set_busy:
            self.app.set_busy(True)
        threading.Thread(target=self._worker, args=(cmd,), daemon=True).start()
        return True

    def _worker(self, cmd):
        try:
            self.proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                universal_newlines=True,
            )
            for line in self.proc.stdout:
                self.app.msg_queue.put(("line", line.rstrip("\n")))
            self.proc.wait()
            self.app.msg_queue.put(("done", self.proc.returncode))
        except FileNotFoundError:
            self.app.msg_queue.put(("line", "LOG|ERROR|powershell.exe was not found on PATH."))
            self.app.msg_queue.put(("done", 1))
        except Exception as exc:
            self.app.msg_queue.put(("line", f"LOG|ERROR|{exc}"))
            _write_app_log("ERROR", "Backend worker crashed:\n" + traceback.format_exc())
            self.app.msg_queue.put(("done", 1))


class Card(ctk.CTkFrame):
    def __init__(self, master, title, icon="", subtitle="", **kwargs):
        super().__init__(
            master,
            fg_color=COLORS["card"],
            corner_radius=UI["card_radius"],
            border_width=1,
            border_color=COLORS["border_soft"],
            **kwargs,
        )
        self.grid_columnconfigure(0, weight=1)

        header = ctk.CTkFrame(self, fg_color="transparent")
        header.grid(row=0, column=0, sticky="ew", padx=18, pady=(16, 8))
        header.grid_columnconfigure(1, weight=1)

        if icon:
            ctk.CTkLabel(
                header,
                text=icon,
                width=34,
                height=30,
                fg_color=COLORS["surface_alt"],
                corner_radius=10,
                text_color=COLORS["accent"],
                font=ctk.CTkFont(size=16, weight="bold"),
            ).grid(row=0, column=0, rowspan=2 if subtitle else 1, sticky="nw", padx=(0, 10))

        ctk.CTkLabel(
            header,
            text=title,
            font=ctk.CTkFont(size=16, weight="bold"),
            text_color=COLORS["text"],
            anchor="w",
        ).grid(row=0, column=1, sticky="ew")

        if subtitle:
            ctk.CTkLabel(
                header,
                text=subtitle,
                font=ctk.CTkFont(size=12),
                text_color=COLORS["muted"],
                anchor="w",
            ).grid(row=1, column=1, sticky="ew", pady=(2, 0))

        self.body = ctk.CTkFrame(self, fg_color="transparent")
        self.body.grid(row=1, column=0, sticky="ew", padx=18, pady=(0, 18))
        self.body.grid_columnconfigure(0, weight=1)


class SearchPanel(Card):
    def __init__(self, master, title, icon, placeholder, search_callback, clear_callback):
        super().__init__(master, title, icon)
        self.search_callback = search_callback
        self.clear_callback = clear_callback
        self.results = []
        self.selected = None

        row = ctk.CTkFrame(self.body, fg_color="transparent")
        row.grid(row=0, column=0, sticky="ew")
        row.grid_columnconfigure(0, weight=1)
        self.entry = ctk.CTkEntry(row, placeholder_text=placeholder, height=UI["entry_h"], border_color=COLORS["border"])
        self.entry.grid(row=0, column=0, sticky="ew", padx=(0, 8))
        self.entry.bind("<Return>", lambda _e: self.do_search())
        self.search_btn = ctk.CTkButton(row, text="Search", width=92, height=UI["button_h"], fg_color=COLORS["accent"], hover_color=COLORS["accent_hover"], command=self.do_search)
        self.search_btn.grid(row=0, column=1)
        self.clear_btn = ctk.CTkButton(row, text="Clear", width=74, height=UI["button_h"], fg_color=COLORS["surface_alt"], hover_color=COLORS["card_hover"], command=self.clear)
        self.clear_btn.grid(row=0, column=2, padx=(8, 0))

        self.status = ctk.CTkLabel(self.body, text="Nothing selected", text_color=COLORS["muted"], anchor="w")
        self.status.grid(row=1, column=0, sticky="ew", pady=(8, 4))

        self.results_frame = ctk.CTkScrollableFrame(self.body, height=158, fg_color=COLORS["surface"], corner_radius=12)
        self.results_frame.grid(row=2, column=0, sticky="ew", pady=(4, 0))
        self.empty = ctk.CTkLabel(self.results_frame, text="Search results will appear here", text_color=COLORS["muted"])
        self.empty.pack(pady=18)

    def do_search(self):
        term = self.entry.get().strip()
        if not term:
            messagebox.showinfo("Search", "Enter a name, username, or email to search for.")
            return
        self.search_callback(term)

    def set_loading(self, loading):
        self.search_btn.configure(state="disabled" if loading else "normal", text="Searching..." if loading else "Search")

    def _normalise_matches(self, matches):
        if matches is None:
            return []

        if isinstance(matches, str):
            text = matches.strip()
            if not text:
                return []
            try:
                parsed = json.loads(text)
                return self._normalise_matches(parsed)
            except Exception:
                return [{"DisplayName": text}]

        if isinstance(matches, dict):
            return [matches]

        if isinstance(matches, list):
            safe = []
            for item in matches:
                if isinstance(item, dict):
                    safe.append(item)
                elif isinstance(item, str) and item.strip():
                    try:
                        parsed = json.loads(item.strip())
                        safe.extend(self._normalise_matches(parsed))
                    except Exception:
                        safe.append({"DisplayName": item.strip()})
            return safe

        return []

    def set_results(self, matches, on_select):
        self.results = self._normalise_matches(matches)


        for widget in self.results_frame.winfo_children():
            widget.destroy()
        if not self.results:
            ctk.CTkLabel(self.results_frame, text="No matching users found", text_color=COLORS["warn"]).pack(pady=18)
            return
        for match in self.results:
            name = match.get("DisplayName") or "Unknown user"
            sam = match.get("SamAccountName") or ""
            title = match.get("Title") or match.get("EmailAddress") or ""
            dept = match.get("Department") or ""
            text = f"{name}  ·  {sam}\n{title}{' · ' + dept if dept else ''}"
            btn = ctk.CTkButton(
                self.results_frame,
                text=text,
                anchor="w",
                fg_color=COLORS["card2"],
                hover_color=COLORS["card_hover"],
                border_width=1,
                border_color=COLORS["border_soft"],
                height=58,
                command=lambda m=match: on_select(m),
            )
            btn.pack(fill="x", padx=6, pady=4)

    def mark_selected(self, text):
        self.status.configure(text=text, text_color=COLORS["success"])

    def clear(self):
        self.selected = None
        self.status.configure(text="Nothing selected", text_color=COLORS["muted"])
        for widget in self.results_frame.winfo_children():
            widget.destroy()
        ctk.CTkLabel(self.results_frame, text="Search results will appear here", text_color=COLORS["muted"]).pack(pady=18)
        self.clear_callback()


class LoginDialog(ctk.CTkToplevel):
    def __init__(self, master):
        super().__init__(master)
        self.title("Login")
        self.geometry("420x260")
        self.resizable(False, False)
        self.configure(fg_color=COLORS["bg"])
        self.result = None

        self.transient(master)
        self.grab_set()

        frame = ctk.CTkFrame(self, fg_color=COLORS["card"], corner_radius=16, border_width=1, border_color=COLORS["border"])
        frame.pack(fill="both", expand=True, padx=16, pady=16)

        ctk.CTkLabel(frame, text="Authentication Required", font=ctk.CTkFont(size=20, weight="bold"), text_color=COLORS["text"]).pack(anchor="w", padx=18, pady=(18, 4))
        ctk.CTkLabel(frame, text="Enter your AD username and password to unlock the form.", text_color=COLORS["muted"], wraplength=360, justify="left").pack(anchor="w", padx=18, pady=(0, 14))

        self.username = ctk.CTkEntry(frame, placeholder_text="Username e.g. POD\\username or username", height=36)
        self.username.pack(fill="x", padx=18, pady=(0, 8))
        self.password = ctk.CTkEntry(frame, placeholder_text="Password", show="*", height=36)
        self.password.pack(fill="x", padx=18, pady=(0, 12))
        self.password.bind("<Return>", lambda _e: self._ok())

        btn_row = ctk.CTkFrame(frame, fg_color="transparent")
        btn_row.pack(fill="x", padx=18, pady=(4, 18))
        ctk.CTkButton(btn_row, text="Cancel", fg_color=COLORS["border"], command=self._cancel).pack(side="right", padx=(8, 0))
        ctk.CTkButton(btn_row, text="Login", command=self._ok).pack(side="right")

        self.protocol("WM_DELETE_WINDOW", self._cancel)
        self.after(100, self.username.focus_set)

    def _ok(self):
        username = self.username.get().strip()
        password = self.password.get()
        if not username or not password:
            messagebox.showwarning("Missing details", "Enter both username and password.", parent=self)
            return
        self.result = (username, password)
        self.destroy()

    def _cancel(self):
        self.result = None
        self.destroy()



def _clean_name_part(value):
    return (value or "").strip()


def _format_pattern(pattern, **values):
    """Apply simple settings.ini naming patterns.

    Supported tokens:
    {first}, {last}, {first_initial}, {last_initial}, {first[0]}, {last[0]},
    {display}, {upn}, {sam}, {domain}, {job_title}.
    """
    first = _clean_name_part(values.get("first", ""))
    last = _clean_name_part(values.get("last", ""))
    replacements = {
        "{first}": first,
        "{last}": last,
        "{first_initial}": first[:1],
        "{last_initial}": last[:1],
        "{first[0]}": first[:1],
        "{last[0]}": last[:1],
        "{display}": values.get("display", "") or "",
        "{upn}": values.get("upn", "") or "",
        "{sam}": values.get("sam", "") or "",
        "{domain}": values.get("domain", "") or "",
        "{job_title}": values.get("job_title", "") or "",
    }
    result = pattern or ""
    for token, replacement in replacements.items():
        result = result.replace(token, str(replacement))
    return result.strip()


def _account_safe(value, lower=True, remove_spaces=True):
    value = (value or "").strip()
    if remove_spaces:
        value = value.replace(" ", "")
    return value.lower() if lower else value


class ADUserCreatorV2(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.app_title = f"{COMPANY_NAME} AD Account Creator" if COMPANY_NAME else "AD Account Creator"
        self.title(f"{self.app_title} {APP_VERSION}")
        self.geometry("1380x900")
        self.minsize(1160, 760)
        self.configure(fg_color=COLORS["bg"])

        self.msg_queue = queue.Queue()
        self.current_mode = None
        self.template_dn = None
        self.manager_dn = None
        self.template_match = None
        self.manager_match = None
        self.summary_data = None
        self.check_after_ids = {}
        self.check_tokens = {}
        self.username_available = None
        self.upn_available = None
        self.display_name_available = None
        self.backend = BackendRunner(self)
        self.auth_result = AuthResult(True, "Admin credentials requested on create", "Admin credentials requested on create")

        # Admin credentials are requested when Create Account is clicked.
        self._build_app()
        self._set_app_enabled(True)
        self.set_status("Ready - admin credentials will be requested on create")
        self.after(80, self._poll_queue)
        self.after(200, self._run_startup_checks)

    # ---------------- STARTUP CHECKS ----------------
    def _run_startup_checks(self):
        warnings = []
        if not os.path.isfile(CONFIG_PATH):
            warnings.append(f"settings.ini missing at {CONFIG_PATH}")
        backend_path = _normalise_script_path(self.script_path.get().strip() or DEFAULT_BACKEND)
        if not os.path.isfile(backend_path):
            warnings.append(f"Backend script missing at {backend_path}")
        else:
            self._set_entry(self.script_path, backend_path)
        if not (shutil.which("powershell.exe") or shutil.which("powershell") or shutil.which("pwsh")):
            warnings.append("PowerShell was not found on PATH")
        if DEFAULT_OU_NAME and DEFAULT_OU_NAME not in OU_OPTIONS:
            warnings.append(f"DefaultOU '{DEFAULT_OU_NAME}' is not listed under [OUOptions]")
        if not _looks_like_dns_domain(DEFAULT_DOMAIN):
            warnings.append(f"DefaultDomain looks unusual: {DEFAULT_DOMAIN}")

        if warnings:
            for item in warnings:
                self._log("WARN", "Startup check: " + item)
            self.set_status("Startup checks found items to review")
        else:
            self._log("SUCCESS", "Startup checks passed: settings, backend path and PowerShell look OK.")

    # ---------------- AUTH ----------------
    def _authenticate(self, username, password):
        """Validate the typed AD credentials and explain failures.

        Important: there is NO admin/security-group membership check here.
        A successful username/password validation unlocks the form.
        """
        username = (username or "").strip()
        password = password or ""
        if not username or not password:
            return AuthResult(False, username, "Username and password are required.")

        raw_username = username
        domain_for_context = AUTH_DOMAIN_DNS
        user_for_validation = username

        if "\\" in username:
            netbios, user_part = username.split("\\", 1)
            domain_for_context = netbios or AUTH_DOMAIN_NETBIOS
            user_for_validation = user_part
        elif "@" in username:
            user_for_validation = username.split("@", 1)[0]
            domain_for_context = AUTH_DOMAIN_DNS

        ps_script = r"""
param(
    [string]$Domain,
    [string]$Username,
    [string]$Password
)
$ErrorActionPreference = 'Stop'
$result = [ordered]@{
    Success = $false
    Domain = $Domain
    Username = $Username
    Step = 'Starting'
    Message = ''
    Exception = ''
    IdentityFound = $false
    GroupsChecked = $false
    GroupValidation = 'Not used - no admin/security group requirement in this version'
}
try {
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    $result.Step = 'Creating domain context'
    $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)

    $result.Step = 'Finding user in AD'
    $user = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($ctx, $Username)
    if ($null -ne $user) {
        $result.IdentityFound = $true
        $result.DisplayName = $user.DisplayName
        $result.SamAccountName = $user.SamAccountName
        $result.UserPrincipalName = $user.UserPrincipalName
        $result.Enabled = $user.Enabled
        $result.IsAccountLockedOut = $user.IsAccountLockedOut()
    }

    $result.Step = 'Validating password'
    $valid = $ctx.ValidateCredentials($Username, $Password)
    if ($valid) {
        $result.Success = $true
        $result.Message = 'Password accepted. No AD group membership check was performed.'
    } else {
        $result.Message = 'Password was not accepted by the domain controller. This usually means the username format or password is wrong, the account is locked/disabled, or the selected domain is incorrect.'
    }
} catch {
    $result.Message = 'Credential validation failed before completion.'
    $result.Exception = $_.Exception.Message
}
$result | ConvertTo-Json -Compress -Depth 5
"""
        # IMPORTANT: Use a temporary .ps1 file with -File.
        # Passing a multi-line param() script through -Command caused PowerShell to treat
        # -Domain as a separate command/parameter, which produced: "The term '-Domain' is not recognized".
        import tempfile
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile("w", suffix=".ps1", delete=False, encoding="utf-8") as tf:
                tf.write(ps_script)
                temp_path = tf.name

            completed = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    temp_path,
                    "-Domain",
                    domain_for_context,
                    "-Username",
                    user_for_validation,
                    "-Password",
                    password,
                ],
                capture_output=True,
                text=True,
                timeout=25,
            )
        except FileNotFoundError:
            return AuthResult(False, raw_username, "PowerShell was not found, so credentials could not be checked.")
        except subprocess.TimeoutExpired:
            return AuthResult(False, raw_username, "Authentication timed out while contacting Active Directory.")
        except Exception as exc:
            return AuthResult(False, raw_username, f"Authentication crashed before completion:\n{exc}")
        finally:
            if temp_path:
                try:
                    os.remove(temp_path)
                except Exception:
                    pass

        output = (completed.stdout or "").strip()
        error_output = (completed.stderr or "").strip()
        try:
            json_line = output.splitlines()[-1] if output else "{}"
            info = json.loads(json_line)
        except Exception:
            details = (
                f"Authentication failed and the diagnostic JSON could not be read.\n\n"
                f"Entered username: {raw_username}\n"
                f"Domain tried: {domain_for_context}\n"
                f"Username tried: {user_for_validation}\n"
                f"PowerShell exit code: {completed.returncode}\n\n"
                f"STDOUT:\n{output or '(empty)'}\n\nSTDERR:\n{error_output or '(empty)'}"
            )
            return AuthResult(False, raw_username, details)

        if info.get("Success"):
            display = info.get("UserPrincipalName") or info.get("SamAccountName") or raw_username
            return AuthResult(True, display, "Logged in")

        details = [
            "Authentication denied by credential validation only.",
            "No admin group/security group check is in this version.",
            "",
            f"Entered username: {raw_username}",
            f"Domain tried: {info.get('Domain', domain_for_context)}",
            f"Username tried: {info.get('Username', user_for_validation)}",
            f"Last step: {info.get('Step', 'Unknown')}",
            f"AD user found: {info.get('IdentityFound', False)}",
        ]
        if "Enabled" in info:
            details.append(f"Account enabled: {info.get('Enabled')}")
        if "IsAccountLockedOut" in info:
            details.append(f"Account locked out: {info.get('IsAccountLockedOut')}")
        if info.get("DisplayName"):
            details.append(f"Display name found: {info.get('DisplayName')}")
        details.extend(["", f"Reason: {info.get('Message') or 'Unknown failure'}"])
        if info.get("Exception"):
            details.extend(["", f"Exception: {info.get('Exception')}"])
        if error_output:
            details.extend(["", f"PowerShell stderr: {error_output}"])
        return AuthResult(False, raw_username, "\n".join(details))

    def _build_denied(self):
        frame = ctk.CTkFrame(self, fg_color=COLORS["card"], corner_radius=18)
        frame.place(relx=0.5, rely=0.5, anchor="center")
        ctk.CTkLabel(frame, text="Access Denied", font=ctk.CTkFont(size=28, weight="bold"), text_color=COLORS["error"]).pack(padx=50, pady=(36, 8))
        ctk.CTkLabel(frame, text=self.auth_result.message, text_color=COLORS["text"]).pack(padx=50, pady=6)
        ctk.CTkLabel(frame, text=f"Signed in as: {self.auth_result.user}", text_color=COLORS["muted"]).pack(padx=50, pady=(0, 24))
        ctk.CTkButton(frame, text="Close", command=self.destroy).pack(pady=(0, 36))

    def _login_clicked(self):
        dialog = LoginDialog(self)
        self.wait_window(dialog)
        if not dialog.result:
            self.set_status("Login cancelled")
            return

        username, password = dialog.result
        self.login_btn.configure(text="Checking...", state="disabled")
        self.update_idletasks()
        result = self._authenticate(username, password)
        password = None  # Do not keep the password after validation.

        if result.allowed:
            self.auth_result = result
            self.user_label.configure(text=f"Logged in: {result.user}", text_color=COLORS["success"])
            self.login_btn.configure(text="Logged in", state="disabled", fg_color=COLORS["success"])
            self._set_app_enabled(True)
            self.set_status("Logged in - ready")
            self._log("SUCCESS", f"Logged in as {result.user}")
        else:
            self.login_btn.configure(text="Login", state="normal", fg_color=COLORS["accent"])
            messagebox.showerror("Login failed - diagnostics", result.message, parent=self)
            self._log("ERROR", result.message.replace("\n", " | "))
            self.set_status(result.message)

    def _set_app_enabled(self, enabled):
        state = "normal" if enabled else "disabled"

        def walk(widget):
            for child in widget.winfo_children():
                if child in (getattr(self, "login_btn", None), getattr(self, "user_label", None)):
                    continue
                try:
                    if isinstance(child, ctk.CTkTextbox):
                        child.configure(state="disabled")
                    elif isinstance(child, (ctk.CTkEntry, ctk.CTkButton, ctk.CTkCheckBox, ctk.CTkRadioButton)):
                        child.configure(state=state)
                except Exception:
                    pass
                walk(child)

        if hasattr(self, "main"):
            walk(self.main)
        # Always keep log/preview text boxes read-only.
        for name in ("ou_preview", "log_box"):
            if hasattr(self, name):
                try:
                    getattr(self, name).configure(state="disabled")
                except Exception:
                    pass

    def _require_login(self):
        if not getattr(self.auth_result, "allowed", False):
            messagebox.showwarning("Login required", "Please click Login first.")
            return False
        return True

    # ---------------- UI ----------------
    def _build_app(self):
        self.grid_rowconfigure(1, weight=1)
        self.grid_columnconfigure(0, weight=1)
        self._build_header()
        self._build_content()
        self._build_statusbar()

    def _build_header(self):
        header = ctk.CTkFrame(self, height=92, fg_color=COLORS["surface"], corner_radius=0)
        header.grid(row=0, column=0, sticky="ew")
        header.grid_columnconfigure(1, weight=1)

        logo = ctk.CTkLabel(
            header,
            text="AD",
            width=48,
            height=48,
            fg_color=COLORS["accent"],
            corner_radius=14,
            text_color="#06111F",
            font=ctk.CTkFont(size=18, weight="bold"),
        )
        logo.grid(row=0, column=0, sticky="w", padx=(22, 14), pady=20)

        title_stack = ctk.CTkFrame(header, fg_color="transparent")
        title_stack.grid(row=0, column=1, sticky="ew", pady=16)
        title_stack.grid_columnconfigure(0, weight=1)

        ctk.CTkLabel(
            title_stack,
            text=self.app_title,
            font=ctk.CTkFont(size=25, weight="bold"),
            text_color=COLORS["text"],
            anchor="w",
        ).grid(row=0, column=0, sticky="ew")

        subtitle = f"{APP_VERSION}  •  validated create flow, safer backend calls and persistent logs"
        ctk.CTkLabel(
            title_stack,
            text=subtitle,
            font=ctk.CTkFont(size=13),
            text_color=COLORS["muted"],
            anchor="w",
        ).grid(row=1, column=0, sticky="ew", pady=(4, 0))

        env_text = f"Domain: {DEFAULT_DOMAIN}"
        ctk.CTkLabel(
            header,
            text=env_text,
            height=34,
            fg_color=COLORS["surface_alt"],
            corner_radius=12,
            text_color=COLORS["muted"],
            font=ctk.CTkFont(size=12),
        ).grid(row=0, column=2, sticky="e", padx=(12, 22), pady=20)


    def _build_content(self):
        self.main = ctk.CTkScrollableFrame(self, fg_color=COLORS["bg"], corner_radius=0)
        self.main.grid(row=1, column=0, sticky="nsew", padx=UI["page_pad"], pady=UI["page_pad"])
        self.main.grid_columnconfigure(0, weight=2, uniform="main")
        self.main.grid_columnconfigure(1, weight=2, uniform="main")
        self.main.grid_columnconfigure(2, weight=1, uniform="side")
        self.main.grid_rowconfigure(2, weight=1)

        self._build_identity_card()
        self._build_job_card()
        self._build_template_card()
        self._build_manager_card()
        self._build_options_card()
        self._build_progress_card()
        self._build_summary_card()

    def _entry(self, master, row, label, default="", placeholder=""):
        ctk.CTkLabel(
            master,
            text=label,
            anchor="w",
            text_color=COLORS["muted"],
            font=ctk.CTkFont(size=12, weight="bold"),
        ).grid(row=row, column=0, sticky="ew", pady=(6, 3))
        e = ctk.CTkEntry(
            master,
            height=UI["entry_h"],
            placeholder_text=placeholder,
            fg_color=COLORS["surface"],
            border_width=1,
            border_color=COLORS["border_soft"],
            text_color=COLORS["text"],
        )
        e.grid(row=row + 1, column=0, sticky="ew", pady=(0, 7))
        if default:
            e.insert(0, default)
        return e

    def _build_identity_card(self):
        card = Card(self.main, "Identity", "👤", "Name and logon details")
        card.grid(row=0, column=0, sticky="nsew", padx=(0, UI["gap"] // 2), pady=(0, UI["gap"]))
        self.first_name = self._entry(card.body, 0, "First name")
        self.last_name = self._entry(card.body, 2, "Last name")
        self.display_name = self._entry(card.body, 4, "Display name")
        self.display_name.configure(state="readonly")
        self.display_check_label = ctk.CTkLabel(card.body, text="", anchor="w", text_color=COLORS["muted"])
        self.display_check_label.grid(row=6, column=0, sticky="ew", pady=(0, 4))
        self.upn_prefix = self._entry(card.body, 7, "UPN prefix / logon name")
        self.upn_check_label = ctk.CTkLabel(card.body, text="", anchor="w", text_color=COLORS["muted"])
        self.upn_check_label.grid(row=9, column=0, sticky="ew", pady=(0, 4))
        self.sam_name = self._entry(card.body, 10, "SAMAccountName")
        self.sam_check_label = ctk.CTkLabel(card.body, text="", anchor="w", text_color=COLORS["muted"])
        self.sam_check_label.grid(row=12, column=0, sticky="ew", pady=(0, 4))
        self.email = self._entry(card.body, 13, "Email (optional)")
        self.first_name.bind("<KeyRelease>", self._suggest_names)
        self.last_name.bind("<KeyRelease>", self._suggest_names)
        self.upn_prefix.bind("<KeyRelease>", self._on_upn_changed)
        self.sam_name.bind("<KeyRelease>", self._on_sam_changed)
        self.email.bind("<KeyRelease>", lambda _e: self._mark_touched(self.email))

    def _build_job_card(self):
        card = Card(self.main, "Job Details", "💼", "Role, department and contact info")
        card.grid(row=0, column=1, sticky="nsew", padx=UI["gap"] // 2, pady=(0, UI["gap"]))
        self.job_title = self._entry(card.body, 0, "Job title")
        self.description = self._entry(card.body, 2, "AD Description (defaults to job title)")
        self.department = self._entry(card.body, 4, "Department")
        self.company = self._entry(card.body, 6, "Company")
        self.office = self._entry(card.body, 8, "Office")
        self.phone = self._entry(card.body, 10, "Telephone", DEFAULT_PHONE)
        self.job_title.bind("<KeyRelease>", self._sync_description_from_job_title)
        self.description.bind("<KeyRelease>", lambda _e: self._mark_touched(self.description))

    def _build_template_card(self):
        self.template_panel = SearchPanel(
            self.main, "Copy Existing User", "👥", "Name, username, or email", self._search_template, self._clear_template
        )
        self.template_panel.grid(row=1, column=0, sticky="nsew", padx=(0, UI["gap"] // 2), pady=(0, UI["gap"]))
        self.group_preview_label = ctk.CTkLabel(
            self.template_panel.body,
            text="Groups to be copied will appear here after selecting a template.",
            anchor="w",
            text_color=COLORS["muted"],
        )
        self.group_preview_label.grid(row=3, column=0, sticky="ew", pady=(10, 4))
        self.group_preview_box = ctk.CTkTextbox(
            self.template_panel.body,
            height=115,
            fg_color=COLORS["surface"],
            border_width=1,
            border_color=COLORS["border_soft"],
            text_color=COLORS["text"],
        )
        self.group_preview_box.grid(row=4, column=0, sticky="ew")
        self.group_preview_box.insert("1.0", "No template selected.")
        self.group_preview_box.configure(state="disabled")

    def _build_manager_card(self):
        self.manager_panel = SearchPanel(
            self.main, "Manager", "👨", "Name, username, or email", self._search_manager, self._clear_manager
        )
        self.manager_panel.grid(row=1, column=1, sticky="nsew", padx=UI["gap"] // 2, pady=(0, UI["gap"]))

    def _build_options_card(self):
        card = Card(self.main, "Options", "⚙", "OU, domain and backend options")
        card.grid(row=0, column=2, rowspan=2, sticky="nsew", padx=(UI["gap"] // 2, 0), pady=(0, UI["gap"]))

        ctk.CTkLabel(card.body, text="Target OU", anchor="w", text_color=COLORS["text"]).grid(
            row=0, column=0, sticky="ew", pady=(5, 6)
        )
        self.ou_choice = ctk.StringVar(value=DEFAULT_OU_NAME if DEFAULT_OU_NAME in OU_OPTIONS else (next(iter(OU_OPTIONS.keys())) if OU_OPTIONS else "Custom"))
        self.ou_buttons = []
        row = 1
        for label, dn in OU_OPTIONS.items():
            rb = ctk.CTkRadioButton(
                card.body,
                text=label,
                variable=self.ou_choice,
                value=label,
                text_color=COLORS["text"],
                radiobutton_width=18,
                radiobutton_height=18,
                command=self._on_ou_changed,
            )
            rb.grid(row=row, column=0, sticky="w", pady=4)
            self.ou_buttons.append(rb)
            row += 1

        custom_rb = ctk.CTkRadioButton(
            card.body,
            text="Custom OU",
            variable=self.ou_choice,
            value="Custom",
            text_color=COLORS["text"],
            radiobutton_width=18,
            radiobutton_height=18,
            command=self._on_ou_changed,
        )
        custom_rb.grid(row=row, column=0, sticky="w", pady=(8, 4))
        self.ou_buttons.append(custom_rb)
        row += 1

        self.custom_ou = ctk.CTkEntry(card.body, height=34, placeholder_text="Paste custom OU distinguished name")
        self.custom_ou.grid(row=row, column=0, sticky="ew", pady=(0, 6))
        self.custom_ou.bind("<KeyRelease>", lambda _e: self._on_custom_ou_changed())
        row += 1

        self.ou_preview = ctk.CTkTextbox(card.body, height=78, fg_color=COLORS["surface"], border_width=1, border_color=COLORS["border_soft"], text_color=COLORS["muted"])
        self.ou_preview.grid(row=row, column=0, sticky="ew", pady=(8, 10))
        self.ou_preview.insert("1.0", OU_OPTIONS[self.ou_choice.get()])
        self.ou_preview.configure(state="disabled")
        self.ou_choice.trace_add("write", lambda *_: self._on_ou_changed())
        row += 1

        # No orange helper text here - OU paths remain visible in the read-only box above.

        self.account_expiry = self._entry(card.body, row, "Account expiry date (YYYY-MM-DD, blank = never expires)")
        row += 2
        self.domain = self._entry(card.body, row, "Domain", DEFAULT_DOMAIN)
        row += 2
        self.script_path = self._entry(card.body, row, "Backend script", DEFAULT_BACKEND)
        row += 2
        self.skip_mailbox = ctk.CTkCheckBox(card.body, text="Skip mailbox creation", text_color=COLORS["text"])
        self.skip_mailbox.grid(row=row, column=0, sticky="w", pady=5)
        row += 1
        self.create_btn = ctk.CTkButton(
            card.body, text="Create Account", height=46, fg_color=COLORS["success"], hover_color=COLORS["success_hover"], font=ctk.CTkFont(size=14, weight="bold"), command=self._create_account
        )
        self.create_btn.grid(row=row, column=0, sticky="ew", pady=(18, 8))
        row += 1
        self.reset_btn = ctk.CTkButton(card.body, text="Reset Form", height=UI["button_h"], fg_color=COLORS["surface_alt"], hover_color=COLORS["card_hover"], command=self._reset_form)
        self.reset_btn.grid(row=row, column=0, sticky="ew")

    def _build_progress_card(self):
        card = Card(self.main, "Progress & Log", "📈", "Live backend output")
        card.grid(row=2, column=0, columnspan=2, sticky="nsew", padx=(0, UI["gap"] // 2), pady=(0, UI["gap"]))
        card.body.grid_rowconfigure(3, weight=1)

        progress_row = ctk.CTkFrame(card.body, fg_color="transparent")
        progress_row.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        progress_row.grid_columnconfigure(0, weight=1)

        self.progress = ctk.CTkProgressBar(progress_row, height=14, progress_color=COLORS["accent"])
        self.progress.grid(row=0, column=0, sticky="ew", padx=(0, 10))
        self.progress.set(0)

        self.progress_badge = ctk.CTkLabel(
            progress_row,
            text="0%",
            width=54,
            height=26,
            fg_color=COLORS["surface_alt"],
            corner_radius=10,
            text_color=COLORS["muted"],
            font=ctk.CTkFont(size=12, weight="bold"),
        )
        self.progress_badge.grid(row=0, column=1, sticky="e")

        self.progress_text = ctk.CTkLabel(card.body, text="Ready", text_color=COLORS["muted"], anchor="w")
        self.progress_text.grid(row=1, column=0, sticky="ew")

        self.log_box = ctk.CTkTextbox(
            card.body,
            height=230,
            font=ctk.CTkFont(family="Consolas", size=12),
            fg_color=COLORS["surface"],
            border_width=1,
            border_color=COLORS["border_soft"],
        )
        self.log_box.grid(row=2, column=0, sticky="nsew", pady=(10, 0))
        self.log_box.configure(state="disabled")

    def _build_summary_card(self):
        card = Card(self.main, "Summary", "📋", "Created user details and to-do list")
        card.grid(row=2, column=2, sticky="nsew", padx=(UI["gap"] // 2, 0), pady=(0, UI["gap"]))
        self.summary_body = card.body
        self._show_empty_summary()

    def _build_statusbar(self):
        bar = ctk.CTkFrame(self, height=42, fg_color=COLORS["surface"], corner_radius=0)
        bar.grid(row=2, column=0, sticky="ew")
        bar.grid_columnconfigure(0, weight=1)
        self.status_label = ctk.CTkLabel(bar, text="Ready", text_color=COLORS["muted"], anchor="w")
        self.status_label.grid(row=0, column=0, sticky="ew", padx=(22, 8))
        self.mode_label = ctk.CTkLabel(
            bar,
            text="Ready",
            width=86,
            height=26,
            fg_color=COLORS["surface_alt"],
            corner_radius=10,
            text_color=COLORS["success"],
            font=ctk.CTkFont(size=12, weight="bold"),
        )
        self.mode_label.grid(row=0, column=1, padx=(8, 8), pady=8)
        self.clock_label = ctk.CTkLabel(bar, text="", text_color=COLORS["muted"], width=80)
        self.clock_label.grid(row=0, column=2, padx=(8, 22))
        self._tick_clock()

    # ---------------- FORM HELPERS ----------------
    def _suggest_names(self, _event=None):
        first = self.first_name.get().strip()
        last = self.last_name.get().strip()
        self._update_display_name()
        if first and last:
            if not getattr(self.upn_prefix, "_touched", False):
                upn_value = _format_pattern(NAMING.get("upn", "{first}.{last}"), first=first, last=last, domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
                self._set_entry(self.upn_prefix, _account_safe(upn_value))
            if not getattr(self.sam_name, "_touched", False):
                sam_value = _format_pattern(NAMING.get("sam", "{first} {last}"), first=first, last=last, domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
                self._set_entry(self.sam_name, sam_value[:20])
            if hasattr(self, "email") and not getattr(self.email, "_touched", False):
                upn_current = self.upn_prefix.get().strip()
                sam_current = self.sam_name.get().strip()
                email_value = _format_pattern(NAMING.get("email", "{upn}@{domain}"), first=first, last=last, upn=upn_current, sam=sam_current, display=self._calculated_display_name(), domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
                self._set_entry(self.email, _account_safe(email_value))
        self._schedule_identity_checks()

    def _on_upn_changed(self, _event=None):
        self._mark_touched(self.upn_prefix)
        if hasattr(self, "email") and not getattr(self.email, "_touched", False):
            email_value = _format_pattern(NAMING.get("email", "{upn}@{domain}"), first=self.first_name.get().strip(), last=self.last_name.get().strip(), upn=self.upn_prefix.get().strip(), sam=self.sam_name.get().strip(), display=self._calculated_display_name(), domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
            self._set_entry(self.email, _account_safe(email_value))
        self._schedule_check("upn", self.upn_prefix.get().strip())

    def _on_sam_changed(self, _event=None):
        self._mark_touched(self.sam_name)
        self._schedule_check("sam", self.sam_name.get().strip())

    def _schedule_identity_checks(self):
        self._schedule_check("display", self._calculated_display_name())
        self._schedule_check("upn", self.upn_prefix.get().strip())
        self._schedule_check("sam", self.sam_name.get().strip())

    def _mark_touched(self, entry):
        entry._touched = True

    def _set_entry(self, entry, value):
        entry.configure(state="normal")
        entry.delete(0, "end")
        entry.insert(0, value or "")

    def _sync_description_from_job_title(self, _event=None):
        if hasattr(self, "description") and not getattr(self.description, "_touched", False):
            desc = _format_pattern(NAMING.get("description", "{job_title}"), first=self.first_name.get().strip(), last=self.last_name.get().strip(), display=self._calculated_display_name(), upn=self.upn_prefix.get().strip(), sam=self.sam_name.get().strip(), domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN, job_title=self.job_title.get().strip())
            self._set_entry(self.description, desc)

    def _on_custom_ou_changed(self):
        if hasattr(self, "ou_choice"):
            self.ou_choice.set("Custom")
        self._update_ou_preview()

    def _selected_ou_path(self):
        if self.ou_choice.get() == "Custom":
            return self.custom_ou.get().strip() if hasattr(self, "custom_ou") else ""
        return OU_OPTIONS.get(self.ou_choice.get(), DEFAULT_OU)

    def _is_contractor(self):
        return self.ou_choice.get() == CONTRACTOR.get("ou_label", "Contractor")

    def _calculated_display_name(self):
        first = self.first_name.get().strip()
        last = self.last_name.get().strip()
        base = _format_pattern(NAMING.get("display", "{first} {last}"), first=first, last=last, domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
        if self._is_contractor() and base:
            return _format_pattern(CONTRACTOR.get("display_name", "EXT_{display}"), first=first, last=last, display=base, domain=self.domain.get().strip() if hasattr(self, "domain") else DEFAULT_DOMAIN)
        return base

    def _update_display_name(self):
        if hasattr(self, "display_name"):
            display = self._calculated_display_name()
            self._set_entry(self.display_name, display)
            self.display_name.configure(state="readonly")
            self._schedule_check("display", display)

    def _on_ou_changed(self):
        self._update_ou_preview()
        self._update_display_name()
        if hasattr(self, "account_expiry"):
            current = self.account_expiry.get().strip()
            if self._is_contractor():
                # Default contractor expiry to 90 days from today. It can be changed manually.
                self._set_entry(self.account_expiry, (datetime.now() + timedelta(days=int(CONTRACTOR.get('expiry_days', 90)))).strftime("%Y-%m-%d"))
            elif current:
                # Non-contractors default to no expiry.
                self._set_entry(self.account_expiry, "")

    def _update_ou_note(self):
        return

    def _update_ou_preview(self):
        if hasattr(self, "ou_preview"):
            self.ou_preview.configure(state="normal")
            self.ou_preview.delete("1.0", "end")
            selected_path = self._selected_ou_path() or "Enter a custom OU distinguished name above."
            self.ou_preview.insert("1.0", selected_path)
            self.ou_preview.configure(state="disabled")
        self._update_ou_note()

    def _reset_form(self):
        for e in [self.first_name, self.last_name, self.display_name, self.upn_prefix, self.sam_name, self.email, self.job_title, self.description, self.department, self.company, self.office, self.account_expiry, self.custom_ou]:
            self._set_entry(e, "")
            if hasattr(e, "_touched"):
                e._touched = False
        self._set_entry(self.phone, DEFAULT_PHONE)
        self.ou_choice.set(DEFAULT_OU_NAME if DEFAULT_OU_NAME in OU_OPTIONS else (next(iter(OU_OPTIONS.keys())) if OU_OPTIONS else "Custom"))
        self._update_ou_preview()
        self.template_panel.clear()
        self.manager_panel.clear()
        self._clear_group_preview()
        self._clear_check_labels()
        self.summary_data = None
        self._show_empty_summary()
        self._set_progress(0, "Ready")
        self.set_status("Ready")


    # ---------------- AVAILABILITY CHECKS ----------------
    def _clear_check_labels(self):
        for attr in ("sam_check_label", "upn_check_label", "display_check_label"):
            if hasattr(self, attr):
                getattr(self, attr).configure(text="", text_color=COLORS["muted"])
        self.username_available = None
        self.upn_available = None
        self.display_name_available = None

    def _schedule_check(self, kind, value):
        value = (value or "").strip()
        label = {"sam": "sam_check_label", "upn": "upn_check_label", "display": "display_check_label"}.get(kind)
        if not label or not hasattr(self, label):
            return
        if kind in self.check_after_ids:
            try:
                self.after_cancel(self.check_after_ids[kind])
            except Exception:
                pass
        if not value:
            getattr(self, label).configure(text="", text_color=COLORS["muted"])
            return
        getattr(self, label).configure(text="Checking...", text_color=COLORS["muted"])
        self.check_after_ids[kind] = self.after(650, lambda k=kind, v=value: self._run_availability_check(k, v))

    def _run_availability_check(self, kind, value):
        token = f"{kind}:{value}:{time.time()}"
        self.check_tokens[kind] = token
        script = _normalise_script_path(self.script_path.get().strip() or DEFAULT_BACKEND)
        if not os.path.isfile(script):
            self._apply_check_result(kind, value, {"Success": False, "Error": "Backend script missing"}, token)
            return
        exe = shutil.which("powershell.exe") or shutil.which("powershell") or shutil.which("pwsh")
        if not exe:
            self._apply_check_result(kind, value, {"Success": False, "Error": "PowerShell not found"}, token)
            return
        args = ["-Mode", "Check", "-CheckType", kind, "-CheckValue", value, "-DefaultDomain", self.domain.get().strip() or DEFAULT_DOMAIN]
        cmd = [exe, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script] + args
        threading.Thread(target=self._availability_worker, args=(kind, value, token, cmd), daemon=True).start()

    def _availability_worker(self, kind, value, token, cmd):
        try:
            completed = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            output = (completed.stdout or "").strip()
            data = {"Success": False, "Error": (completed.stderr or "No RESULT output from backend").strip()}
            for line in output.splitlines():
                if line.startswith("RESULT|"):
                    try:
                        data = json.loads(line[len("RESULT|"):])
                    except json.JSONDecodeError as exc:
                        data = {"Success": False, "Error": f"Invalid RESULT JSON from backend: {exc}"}
                    break
            self.msg_queue.put(("check", (kind, value, token, data)))
        except Exception as exc:
            _write_app_log("ERROR", "Availability check crashed:\n" + traceback.format_exc())
            self.msg_queue.put(("check", (kind, value, token, {"Success": False, "Error": str(exc)})))

    def _apply_check_result(self, kind, value, data, token):
        if self.check_tokens.get(kind) != token:
            return
        label = {"sam": "sam_check_label", "upn": "upn_check_label", "display": "display_check_label"}.get(kind)
        if not label or not hasattr(self, label):
            return
        widget = getattr(self, label)
        if not data.get("Success"):
            widget.configure(text=f"⚠ Check failed: {data.get('Error', 'Unknown error')}", text_color=COLORS["warn"])
            return
        exists = bool(data.get("Exists"))
        count = int(data.get("Count") or (1 if exists else 0))
        if kind == "sam":
            self.username_available = not exists
            widget.configure(
                text="✓ SAMAccountName available" if not exists else "✗ SAMAccountName already exists",
                text_color=COLORS["success"] if not exists else COLORS["error"],
            )
        elif kind == "upn":
            self.upn_available = not exists
            widget.configure(
                text="✓ UPN available" if not exists else "✗ UPN already exists",
                text_color=COLORS["success"] if not exists else COLORS["error"],
            )
        elif kind == "display":
            self.display_name_available = not exists
            if not exists:
                widget.configure(text="✓ Display name available", text_color=COLORS["success"])
            else:
                names = data.get("Matches") or []
                extra = f" ({count} match{'es' if count != 1 else ''})"
                if names:
                    extra += ": " + ", ".join(str(x) for x in names[:3])
                widget.configure(text=f"⚠ Display name already exists{extra}", text_color=COLORS["warn"])

    def _clear_group_preview(self):
        if hasattr(self, "group_preview_label"):
            self.group_preview_label.configure(text="Groups to be copied will appear here after selecting a template.", text_color=COLORS["muted"])
        if hasattr(self, "group_preview_box"):
            self.group_preview_box.configure(state="normal")
            self.group_preview_box.delete("1.0", "end")
            self.group_preview_box.insert("1.0", "No template selected.")
            self.group_preview_box.configure(state="disabled")

    def _show_group_preview(self, match):
        groups = match.get("GroupNames") or []
        if isinstance(groups, str):
            groups = [groups]
        count = len(groups) if groups else int(match.get("GroupCount") or 0)
        privileged_terms = ("domain admins", "enterprise admins", "schema admins", "administrators", "account operators", "server operators", "backup operators", "exchange organization administrators", "organization management")
        if hasattr(self, "group_preview_label"):
            self.group_preview_label.configure(text=f"Groups to be copied ({count})", text_color=COLORS["text"])
        if hasattr(self, "group_preview_box"):
            self.group_preview_box.configure(state="normal")
            self.group_preview_box.delete("1.0", "end")
            if not groups:
                self.group_preview_box.insert("1.0", "No group list returned by backend.")
            else:
                for g in groups:
                    prefix = "⚠" if any(term in str(g).lower() for term in privileged_terms) else "✓"
                    self.group_preview_box.insert("end", f"{prefix} {g}\n")
            self.group_preview_box.configure(state="disabled")

    # ---------------- SEARCH ----------------
    def _search_template(self, term):
        self.template_panel.set_loading(True)
        self.set_status(f"Searching template user: {term}")
        self._run_search("Template", term, "search_template")

    def _search_manager(self, term):
        self.manager_panel.set_loading(True)
        self.set_status(f"Searching manager: {term}")
        self._run_search("Manager", term, "search_manager")

    def _run_search(self, search_type, term, mode):
        term = (term or "").strip()
        if len(term) < 2:
            messagebox.showinfo("Search", "Enter at least 2 characters to search.")
            self.template_panel.set_loading(False)
            self.manager_panel.set_loading(False)
            return
        ok = self.backend.run(["-Mode", "Search", "-SearchType", search_type, "-SearchTerm", term], mode)
        if not ok:
            self.template_panel.set_loading(False)
            self.manager_panel.set_loading(False)

    def _apply_template(self, match):
        self.template_match = match
        self.template_dn = match.get("DistinguishedName")
        groups = match.get("GroupCount", 0) or 0
        self.template_panel.mark_selected(f"Copying from: {match.get('DisplayName')} ({groups} group(s))")
        self._show_group_preview(match)
        for entry, key in [(self.job_title, "Title"), (self.description, "Title"), (self.department, "Department"), (self.company, "Company"), (self.office, "Office")]:
            if match.get(key):
                self._set_entry(entry, match.get(key))
        if match.get("OfficePhone"):
            self._set_entry(self.phone, match.get("OfficePhone"))
        self.set_status("Template user selected")

    def _apply_manager(self, match):
        self.manager_match = match
        self.manager_dn = match.get("DistinguishedName")
        self.manager_panel.mark_selected(f"Manager: {match.get('DisplayName')}")
        self.set_status("Manager selected")

    def _clear_template(self):
        self.template_dn = None
        self.template_match = None
        self._clear_group_preview()

    def _clear_manager(self):
        self.manager_dn = None
        self.manager_match = None

    # ---------------- VALIDATION ----------------
    def _validate_create_inputs(self, first, last, upn, sam, domain, email, expiry, ou_path):
        errors = []
        if not first:
            errors.append("First name is required.")
        if not last:
            errors.append("Last name is required.")
        if not upn:
            errors.append("UPN prefix / logon name is required.")
        if not sam:
            errors.append("SAMAccountName is required.")
        if not domain:
            errors.append("Domain is required.")
        elif not _looks_like_dns_domain(domain):
            errors.append("Domain must look like a DNS domain, for example company.local or company.com.")
        if sam and len(sam) > 20:
            errors.append("SAMAccountName must be 20 characters or fewer.")
        if sam and re.search(r'[/\\\[\]:;|=,+*?<>@"]', sam):
            errors.append("SAMAccountName contains a character AD does not normally allow.")
        if upn and re.search(r"[^A-Za-z0-9._%+-]", upn):
            errors.append("UPN prefix contains an unusual character. Use letters, numbers, dots, hyphens or underscores.")
        if email and not _looks_like_email(email):
            errors.append("Email address does not look valid.")
        if expiry:
            try:
                parsed = datetime.strptime(expiry, "%Y-%m-%d")
                if parsed.date() < datetime.now().date():
                    errors.append("Account expiry date is in the past.")
            except ValueError:
                errors.append("Account expiry must be blank or in YYYY-MM-DD format.")
        if not ou_path:
            errors.append("Enter a custom OU path or select one of the preset OUs.")
        elif not _looks_like_dn(ou_path):
            errors.append("OU path must look like a distinguished name, for example OU=Users,DC=company,DC=local.")
        script = _normalise_script_path(self.script_path.get().strip() or DEFAULT_BACKEND)
        if not os.path.isfile(script):
            errors.append(f"Backend script does not exist: {script}")
        return errors

    # ---------------- CREATE ----------------
    def _create_account(self):
        first = self.first_name.get().strip()
        last = self.last_name.get().strip()
        upn = self.upn_prefix.get().strip()
        sam = self.sam_name.get().strip()
        domain = self.domain.get().strip()
        display = self._calculated_display_name()
        expiry = self.account_expiry.get().strip() if hasattr(self, "account_expiry") else ""
        ou_path = self._selected_ou_path()
        errors = self._validate_create_inputs(first, last, upn, sam, domain, self.email.get().strip(), expiry, ou_path)
        if errors:
            messagebox.showwarning("Check account details", "Please fix the following before creating the account:\n\n" + "\n".join(f"- {e}" for e in errors))
            self.set_status("Validation failed - check required fields")
            self._log("WARN", "Validation blocked create: " + " | ".join(errors))
            return
        self._set_entry(self.script_path, _normalise_script_path(self.script_path.get().strip() or DEFAULT_BACKEND))
        if self.username_available is False:
            messagebox.showwarning("SAMAccountName unavailable", "The SAMAccountName already exists. Choose another username before creating the account.")
            return
        if self.upn_available is False:
            messagebox.showwarning("UPN unavailable", "The UPN already exists. Choose another logon name before creating the account.")
            return
        if self.display_name_available is False:
            if not messagebox.askyesno("Duplicate display name", "A user with this display name already exists. Continue anyway?"):
                return
        contractor_note = ""
        if self._is_contractor():
            contractor_note = (
                f"\n\nContractor selected:"
                f"\n- Display name will be {display}"
                f"\n- Account expiry will be set to {expiry or (datetime.now() + timedelta(days=int(CONTRACTOR.get('expiry_days', 90)))).strftime('%Y-%m-%d')}"
            )
        if not messagebox.askyesno("Confirm account creation", f"Create account for {first} {last} ({upn}@{domain})?{contractor_note}"):
            return

        cred_dialog = LoginDialog(self)
        cred_dialog.title("Admin credentials required")
        self.wait_window(cred_dialog)
        if not cred_dialog.result:
            self.set_status("Account creation cancelled - admin credentials not supplied")
            return
        admin_username, admin_password = cred_dialog.result
        if not admin_username.strip() or not admin_password:
            messagebox.showwarning("Missing admin credentials", "Enter the admin username and password to create the account.")
            return

        args = [
            "-Mode", "Create",
            "-FirstName", first,
            "-LastName", last,
            "-DisplayName", display,
            "-UserLogonName", upn,
            "-SamAccountName", sam,
            "-JobTitle", self.job_title.get().strip(),
            "-Description", self.description.get().strip(),
            "-Department", self.department.get().strip(),
            "-Company", self.company.get().strip(),
            "-Office", self.office.get().strip(),
            "-Phone", self.phone.get().strip(),
            "-Email", self.email.get().strip(),
            "-OUPath", ou_path,
            "-DefaultDomain", domain,
            "-DefaultNetBIOSDomain", AUTH_DOMAIN_NETBIOS,
            "-ExchangeServer", EXCHANGE_SERVER,
            "-ExchangeEnabled", "1" if EXCHANGE_ENABLED else "0",
            "-AdminUsername", admin_username.strip(),
            "-AdminPassword", admin_password,
        ]
        if expiry:
            args += ["-AccountExpiryDate", expiry]
        if self._is_contractor():
            args.append("-ContractorAccount")
        if self.template_dn:
            args += ["-TemplateDN", self.template_dn]
        if self.manager_dn:
            args += ["-ManagerDN", self.manager_dn]
        if self.skip_mailbox.get():
            args.append("-SkipMailbox")

        self._clear_log()
        self._set_progress(0.05, "Starting account creation...")
        self.set_status("Creating account...")
        self.backend.run(args, "create")

    # ---------------- QUEUE / OUTPUT ----------------
    def _poll_queue(self):
        try:
            while True:
                kind, payload = self.msg_queue.get_nowait()
                if kind == "line":
                    self._handle_line(payload)
                elif kind == "done":
                    self._handle_done(payload)
                elif kind == "check":
                    c_kind, c_value, c_token, c_data = payload
                    self._apply_check_result(c_kind, c_value, c_data, c_token)
        except queue.Empty:
            pass
        self.after(80, self._poll_queue)

    def _handle_line(self, line):
        if line.startswith("LOG|"):
            parts = line.split("|", 2)
            if len(parts) == 3:
                _, level, msg = parts
                self._log(level, msg)
                self._update_progress_from_log(level, msg)
            else:
                self._log("INFO", line)
        elif line.startswith("RESULT|"):
            raw = line[len("RESULT|"):]
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                self._log("ERROR", f"Could not parse result JSON: {raw}")
                return
            self._handle_result(data)
        elif line.strip():
            self._log("INFO", line)

    def _handle_result(self, data):
        if isinstance(data, str):
            try:
                data = json.loads(data)
            except Exception:
                data = {"Success": True, "Matches": [data]}

        if self.current_mode == "search_template":
            self.template_panel.set_loading(False)
            matches = data.get("Matches", []) if isinstance(data, dict) and data.get("Success", True) else []
            count = 1 if isinstance(matches, dict) else (len(matches) if isinstance(matches, list) else 0)
            self.template_panel.set_results(matches, self._apply_template)
            self.set_status(f"Found {count} template match(es)")
        elif self.current_mode == "search_manager":
            self.manager_panel.set_loading(False)
            matches = data.get("Matches", []) if isinstance(data, dict) and data.get("Success", True) else []
            count = 1 if isinstance(matches, dict) else (len(matches) if isinstance(matches, list) else 0)
            self.manager_panel.set_results(matches, self._apply_manager)
            self.set_status(f"Found {count} manager match(es)")
        elif self.current_mode == "create":
            self.summary_data = data
            self._show_summary(data)
            self._set_progress(1 if data.get("Success") else 0, "Complete" if data.get("Success") else "Failed")

    def _handle_done(self, returncode):
        self.template_panel.set_loading(False)
        self.manager_panel.set_loading(False)
        self.set_busy(False)
        if returncode != 0:
            self._log("ERROR", f"Backend exited with code {returncode}")
            if self.current_mode != "create":
                self.set_status("Command failed")
            elif not self.summary_data:
                self._show_summary({"Success": False, "Error": f"Backend exited with code {returncode}. Check the log output."})
                self._set_progress(0, "Failed")
                self.set_status("Account creation failed")
        self.current_mode = None

    def _update_progress_from_log(self, level, msg):
        m = msg.lower()
        progress_map = [
            ("preparing", 0.10),
            ("pulling attributes", 0.18),
            ("creating ad account", 0.34),
            ("ad account created", 0.48),
            ("adding group", 0.62),
            ("replication", 0.72),
            ("connecting to exchange", 0.84),
            ("mailbox enabled", 0.95),
        ]
        for key, value in progress_map:
            if key in m:
                self._set_progress(max(self.progress.get(), value), msg)
                self.set_status(msg)
                break
        if level == "ERROR":
            self.set_status(msg)

    def _log(self, level, message):
        level = (level or "INFO").upper()
        color = LOG_COLORS.get(level, COLORS["muted"])
        self.log_box.configure(state="normal")
        try:
            self.log_box.tag_config(level, foreground=color)
            # Colour the whole line by severity so SUCCESS/ERROR/WARN are easy to spot.
            self.log_box.insert("end", f"[{level}] {message}\n", level)
        except Exception:
            # Fallback for older CustomTkinter versions without tag support.
            self.log_box.insert("end", f"[{level}] {message}\n")
        self.log_box.configure(state="disabled")
        self.log_box.see("end")
        _write_app_log(level, message)

    def _clear_log(self):
        self.log_box.configure(state="normal")
        self.log_box.delete("1.0", "end")
        self.log_box.configure(state="disabled")

    # ---------------- SUMMARY ----------------
    def _show_empty_summary(self):
        for widget in self.summary_body.winfo_children():
            widget.destroy()
        ctk.CTkLabel(self.summary_body, text="Create an account to see the summary here.", text_color=COLORS["muted"], wraplength=260).grid(row=0, column=0, sticky="w", pady=10)

    def _show_summary(self, data):
        for widget in self.summary_body.winfo_children():
            widget.destroy()
        if not data.get("Success"):
            ctk.CTkLabel(self.summary_body, text="Account creation failed", font=ctk.CTkFont(size=16, weight="bold"), text_color=COLORS["error"]).grid(row=0, column=0, sticky="w", pady=(0, 8))
            ctk.CTkLabel(self.summary_body, text=data.get("Error", "Unknown error"), text_color=COLORS["text"], wraplength=280, justify="left").grid(row=1, column=0, sticky="w")
            return

        title = "DRY RUN - Preview" if data.get("DryRun") else "Account Created"
        title_color = COLORS["warn"] if data.get("DryRun") else COLORS["success"]
        ctk.CTkLabel(self.summary_body, text=f"✓ {title}", font=ctk.CTkFont(size=18, weight="bold"), text_color=title_color).grid(row=0, column=0, sticky="w", pady=(0, 10))

        fields = [
            ("Name", data.get("DisplayName")),
            ("Email", data.get("PrimaryEmail")),
            ("UPN", data.get("UPN")),
            ("Username", data.get("SamAccountName")),
            ("Password", data.get("Password")),
            ("Expiry", data.get("AccountExpiry")),
            ("Job title", data.get("JobTitle")),
            ("Description", data.get("Description")),
            ("Department", data.get("Department")),
            ("Mailbox", data.get("MailboxStatus")),
        ]
        row = 1
        for label, value in fields:
            if value:
                self._summary_row(row, label, str(value))
                row += 1

        ctk.CTkButton(self.summary_body, text="Copy Entire Summary", height=38, command=self._copy_summary).grid(row=row, column=0, sticky="ew", pady=(12, 12))
        row += 1

        added = data.get("GroupsAdded", []) or []
        failed = data.get("GroupsFailed", []) or []
        ctk.CTkLabel(self.summary_body, text=f"Groups copied: {len(added)}", font=ctk.CTkFont(weight="bold"), text_color=COLORS["text"]).grid(row=row, column=0, sticky="w", pady=(6, 2)); row += 1
        if failed:
            ctk.CTkLabel(self.summary_body, text=f"Groups failed: {len(failed)}", text_color=COLORS["error"]).grid(row=row, column=0, sticky="w"); row += 1

        ctk.CTkLabel(self.summary_body, text="To Do", font=ctk.CTkFont(size=15, weight="bold"), text_color=COLORS["text"]).grid(row=row, column=0, sticky="w", pady=(12, 4)); row += 1
        self.todo_vars = []
        for item in TODO_ITEMS:
            var = ctk.BooleanVar(value=False)
            cb = ctk.CTkCheckBox(self.summary_body, text=item, text_color=COLORS["text"], variable=var)
            cb.grid(row=row, column=0, sticky="w", pady=3)
            self.todo_vars.append((item, var))
            row += 1

    def _summary_row(self, row, label, value):
        frame = ctk.CTkFrame(self.summary_body, fg_color="transparent")
        frame.grid(row=row, column=0, sticky="ew", pady=3)
        frame.grid_columnconfigure(1, weight=1)
        ctk.CTkLabel(frame, text=label, width=78, anchor="w", text_color=COLORS["muted"]).grid(row=0, column=0, sticky="w")
        entry = ctk.CTkEntry(frame, height=30)
        entry.grid(row=0, column=1, sticky="ew", padx=(4, 5))
        entry.insert(0, value)
        entry.configure(state="readonly")
        ctk.CTkButton(frame, text="Copy", width=54, height=30, command=lambda v=value: self._copy(v)).grid(row=0, column=2)

    def _copy(self, value):
        self.clipboard_clear()
        self.clipboard_append(value)
        self.set_status("Copied to clipboard")

    def _copy_summary(self):
        if not self.summary_data:
            return
        d = self.summary_data
        lines = [
            str(d.get('SamAccountName', '') or ''),
            str(d.get('PrimaryEmail', '') or ''),
            str(d.get('Password', '') or ''),
            "",
            "To Do:",
        ]

        # Copy the visible To Do items as plain lines, no tick boxes or labels.
        todo_items = getattr(self, "todo_vars", None)
        if todo_items:
            for item, _var in todo_items:
                lines.append(item)
        else:
            lines.extend(TODO_ITEMS)

        self._copy("\n".join(lines))


    def _set_progress(self, value, text=None):
        value = max(0, min(1, float(value)))
        self.progress.set(value)
        if hasattr(self, "progress_badge"):
            self.progress_badge.configure(text=f"{int(round(value * 100))}%")
        if text and hasattr(self, "progress_text"):
            self.progress_text.configure(text=text)

    # ---------------- STATUS ----------------
    def set_busy(self, busy):
        state = "disabled" if busy else "normal"
        self.create_btn.configure(state=state, text="Creating account..." if busy else "Create Account")

    def set_status(self, text):
        self.status_label.configure(text=text)
        if hasattr(self, "mode_label"):
            lowered = str(text).lower()
            if any(word in lowered for word in ("failed", "error", "denied", "missing", "invalid")):
                self.mode_label.configure(text="Attention", text_color=COLORS["error"])
            elif any(word in lowered for word in ("creating", "searching", "working", "checking")):
                self.mode_label.configure(text="Working", text_color=COLORS["warn"])
            else:
                self.mode_label.configure(text="Ready", text_color=COLORS["success"])

    def _tick_clock(self):
        self.clock_label.configure(text=time.strftime("%H:%M:%S"))
        self.after(1000, self._tick_clock)


if __name__ == "__main__":
    # Better taskbar grouping/name on Windows
    try:
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("ADAccountCreator.Generic")
    except Exception:
        pass
    app = ADUserCreatorV2()
    app.mainloop()
