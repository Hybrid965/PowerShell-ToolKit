from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class AuthResult:
    allowed: bool
    user: str
    message: str


@dataclass
class SearchResult:
    display_name: str = ""
    sam_account_name: str = ""
    distinguished_name: str = ""
    title: str = ""
    department: str = ""
    email_address: str = ""
    raw: Optional[Dict[str, Any]] = None


@dataclass
class CreationSummary:
    success: bool
    display_name: str = ""
    upn: str = ""
    sam_account_name: str = ""
    primary_email: str = ""
    password: str = ""
    error: str = ""
    groups_added: Optional[List[str]] = None
    groups_failed: Optional[List[str]] = None
