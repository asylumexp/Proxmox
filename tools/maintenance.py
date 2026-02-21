#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path

# Repo-root relative paths
REPO_ROOT = Path(__file__).resolve().parents[1]
JSON_DIR = REPO_ROOT / "frontend" / "public" / "json"
STATUSES_FILE = JSON_DIR / "statuses.json"

EXCLUDE_FILES = {"versions.json", "metadata.json", "statuses.json"}


def load_statuses() -> dict:
    if not STATUSES_FILE.exists():
        return {}
    return json.loads(STATUSES_FILE.read_text(encoding="utf-8"))


def save_statuses(statuses: dict) -> None:
    sorted_statuses = dict(sorted(statuses.items(), key=lambda kv: kv[0]))
    STATUSES_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATUSES_FILE.write_text(
        json.dumps(sorted_statuses, indent=4, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Statuses updated: {STATUSES_FILE}")


def iter_json_script_files() -> list[str]:
    if not JSON_DIR.exists():
        return []
    files = []
    for p in sorted(JSON_DIR.iterdir()):
        if p.is_file() and p.suffix == ".json" and p.name not in EXCLUDE_FILES:
            files.append(p.name)
    return files


def add_pending_status() -> None:
    """Set status to 🚧 for any JSON script missing a status, then sort and save."""
    statuses = load_statuses()
    changed = False

    for fname in iter_json_script_files():
        if fname not in statuses or statuses.get(fname) is None:
            statuses[fname] = "🚧"
            print(f"Pending status added for {fname}")
            changed = True

    if changed:
        save_statuses(statuses)
    else:
        print("No missing statuses found.")


def remove_missing_statuses() -> None:
    """Remove entries from statuses.json where the corresponding file no longer exists."""
    statuses = load_statuses()
    existing = set(iter_json_script_files())

    removed_any = False
    for fname in list(statuses.keys()):
        if fname in EXCLUDE_FILES:
            continue
        if fname not in existing:
            statuses.pop(fname, None)
            print(f"Removed status for missing script: {fname}")
            removed_any = True

    if removed_any:
        save_statuses(statuses)
    else:
        print("No missing scripts found in statuses.json.")


def replace_build_func_url() -> None:
    """Replace build.func URL in ./ct files."""
    old_url = "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"
    new_url = "https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func"
    ct_dir = REPO_ROOT / "ct"

    print("Checking and replacing build.func URLs...")
    updated = 0

    for path in ct_dir.rglob("*"):
        if not path.is_file():
            continue
        # most of these are .sh, but avoid missing any with no suffix
        if path.name.startswith("."):
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        if old_url in content:
            path.write_text(content.replace(old_url, new_url), encoding="utf-8")
            updated += 1
            print(f"Updated: {path.relative_to(REPO_ROOT)}")

    print(f"build.func URL updates: {updated}")


def update_license_url() -> None:
    """Replace old license header URL with this fork's license URL."""
    old = "# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE"
    new = "# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE"

    print("Checking and updating license headers...")
    updated = 0

    for path in REPO_ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in {".sh", ".func"}:
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        if old in content:
            path.write_text(content.replace(old, new), encoding="utf-8")
            updated += 1
            print(f"Updated license in {path.relative_to(REPO_ROOT)}")

    print(f"License header updates: {updated}")


def search_externally_managed() -> None:
    """Search ./install for EXTERNALLY-MANAGED removal + setup_uv."""
    target_dir = REPO_ROOT / "install"
    pattern = re.compile(r"rm -rf /usr/lib/python3\.\*/EXTERNALLY-MANAGED")

    for path in target_dir.rglob("*"):
        if not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        if pattern.search(content) and "setup_uv" in content:
            print(path.relative_to(REPO_ROOT))


def post_merge_maintenance() -> None:
    """Run the standard maintenance pass after an upstream merge."""
    add_pending_status()
    remove_missing_statuses()
    update_license_url()
    replace_build_func_url()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Proxmox fork maintenance helpers")

    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("post-merge", help="Run the standard post-merge maintenance pass")
    sub.add_parser("add-pending-status", help="Set 🚧 for scripts missing a status")
    sub.add_parser("remove-missing-statuses", help="Remove statuses for scripts that no longer exist")
    sub.add_parser("update-license-url", help="Update license header URL in scripts")
    sub.add_parser("replace-build-func-url", help="Replace build.func URL in ct scripts")
    sub.add_parser("search-externally-managed", help="Search install/ for EXTERNALLY-MANAGED with setup_uv")

    return p


def main() -> int:
    args = build_parser().parse_args()

    if args.cmd == "post-merge":
        post_merge_maintenance()
    elif args.cmd == "add-pending-status":
        add_pending_status()
    elif args.cmd == "remove-missing-statuses":
        remove_missing_statuses()
    elif args.cmd == "update-license-url":
        update_license_url()
    elif args.cmd == "replace-build-func-url":
        replace_build_func_url()
    elif args.cmd == "search-externally-managed":
        search_externally_managed()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
