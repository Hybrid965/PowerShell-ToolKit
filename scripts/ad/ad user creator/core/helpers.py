def parse_bool(value, default=True):
    if value is None:
        return default
    return str(value).strip().lower() in ("1", "yes", "true", "on", "enabled")


def clean_name_part(value):
    return (value or "").strip()


def format_pattern(pattern, **values):
    first = clean_name_part(values.get("first", ""))
    last = clean_name_part(values.get("last", ""))
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


def account_safe(value, lower=True, remove_spaces=True):
    value = (value or "").strip()
    if remove_spaces:
        value = value.replace(" ", "")
    return value.lower() if lower else value
