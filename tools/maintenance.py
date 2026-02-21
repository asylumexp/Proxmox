import os
import json
import re

STATUSES_FILE = './frontend/public/json/statuses.json'
EXCLUDE_FILES = ('versions.json', 'metadata.json')


def load_statuses():
    """Load the statuses.json into a dict."""
    if not os.path.exists(STATUSES_FILE):
        return {}
    with open(STATUSES_FILE, 'r', encoding='UTF-8') as f:
        return json.load(f)


def save_statuses(statuses):
    """Write the statuses dict back to statuses.json, sorted alphabetically by filename."""
    sorted_statuses = dict(sorted(statuses.items()))
    os.makedirs(os.path.dirname(STATUSES_FILE), exist_ok=True)
    with open(STATUSES_FILE, 'w', encoding='UTF-8') as f:
        json.dump(sorted_statuses, f, indent=4, ensure_ascii=False)
    print(f'Statuses updated: {STATUSES_FILE}')


def list_scripts_by_status(status_filter=None):
    """
    Print filenames whose status matches the emoji filter, or all if None.
    status_filter should be an emoji like '❌', '✅', '🚧' or '🧪'.
    """
    statuses = load_statuses()
    for filename, status in statuses.items():
        if filename in EXCLUDE_FILES:
            continue

        # If filtering, only show matches; otherwise, show all
        if status_filter:
            if status == status_filter:
                print(f'{filename}: {status}')
        else:
            print(f'{filename}: {status}')


def list_scripts_without_status():
    """Print filenames that have no status set (None)."""
    statuses = load_statuses()
    for filename, status in statuses.items():
        if filename in EXCLUDE_FILES:
            continue
        if status is None:
            print(filename)


def detect_indent(text):
    lines = text.splitlines()
    for line in lines:
        match = re.match(r'^(\s+)[^\s]', line)
        if match:
            return len(match.group(1))
    return 4


def add_pending_status():
    """Set status to 🚧 for any JSON script missing a status, then sort and save."""
    json_dir = './frontend/public/json'
    statuses = load_statuses()

    for fname in sorted(os.listdir(json_dir)):
        if not fname.endswith('.json') or fname in EXCLUDE_FILES:
            continue
        if fname not in statuses or statuses[fname] is None:
            statuses[fname] = '🚧'
            print(f'Pending status added for {fname}')

    save_statuses(statuses)


def remove_missing_statuses():
    """Remove entries from statuses.json where the corresponding file no longer exists."""
    json_dir = './frontend/public/json'
    statuses = load_statuses()
    existing = {
        fname for fname in os.listdir(json_dir)
        if fname.endswith('.json') and fname not in EXCLUDE_FILES
    }

    removed = False
    for fname in list(statuses.keys()):
        if fname not in existing and fname not in EXCLUDE_FILES:
            statuses.pop(fname)
            print(f'Removed status for missing script: {fname}')
            removed = True

    if removed:
        save_statuses(statuses)
    else:
        print('No missing scripts found in statuses.json.')


def replace_build_func_url():
    """Replace build.func URL in ./ct files (no change to statuses.json)."""
    old_url = "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"
    new_url = "https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func"
    ct_dir = './ct'

    print("Checking and replacing build.func URLs...")
    for root, _, files in os.walk(ct_dir):
        for filename in files:
            filepath = os.path.join(root, filename)
            try:
                with open(filepath, 'r+', encoding='UTF-8') as file:
                    content = file.read()
                    if old_url in content:
                        file.seek(0)
                        file.write(content.replace(old_url, new_url))
                        file.truncate()
                        print(f'Updated: {filepath}')
            except Exception as e:
                print(f"Error processing {filepath}: {e}")


def update_license_url():
    """Replace old license header URL with new repository URL."""
    old = "# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE"
    new = "# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE"
    print("Checking and updating license headers...")
    for root, _, files in os.walk('.'):
        for fname in files:
            if not fname.endswith(('.sh', '.func')):
                continue
            path = os.path.join(root, fname)
            try:
                with open(path, 'r+', encoding='utf-8') as f:
                    lines = f.readlines()
                    updated = False
                    for i, line in enumerate(lines):
                        if old in line:
                            lines[i] = line.replace(old, new)
                            updated = True
                    if updated:
                        f.seek(0)
                        f.writelines(lines)
                        f.truncate()
                        print(f'Updated license in {path}')
            except Exception as e:
                print(f"Error processing {path}: {e}")


def search_externally_managed():
    """Search ./install for rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED and check for setup_uv."""
    target_dir = './install'
    pattern = re.compile(r'rm -rf /usr/lib/python3\.\*/EXTERNALLY-MANAGED')
    for root, _, files in os.walk(target_dir):
        for name in files:
            path = os.path.join(root, name)
            try:
                with open(path, encoding='utf-8') as f:
                    content = f.read()
            except (UnicodeDecodeError, PermissionError):
                continue
            if pattern.search(content) and 'setup_uv' in content:
                print(path)


def main():
    while True:
        print("\nMenu:")
        print("1. List all scripts with a specific status")
        print("2. List all scripts with no status")
        print("3. Add pending status (🚧) to all scripts missing a status")
        print("4. Remove statuses for scripts no longer present")
        print("5. Replace old build.func URL with new one in ./ct")
        print("6. Search install for EXTERNALLY-MANAGED with setup_uv")
        print("7. Update license URL in scripts")
        print("8. Exit")

        choice = input("Enter your choice: ")

        if choice == '1':
            print("Filter by:")
            print("1. ❌ (Error)")
            print("2. ✅ (Success)")
            print("3. 🚧 (Pending)")
            print("4. 🧪 (Testing)")
            print("5. Show all")
            status_choice = input("Enter your filter choice: ")
            status_map = {
                '1': '❌',
                '2': '✅',
                '3': '🚧',
                '4': '🧪',
                '5': None
            }
            list_scripts_by_status(status_map.get(status_choice))
        elif choice == '2':
            list_scripts_without_status()
        elif choice == '3':
            add_pending_status()
        elif choice == '4':
            remove_missing_statuses()
        elif choice == '5':
            replace_build_func_url()
        elif choice == '6':
            search_externally_managed()
        elif choice == '7':
            update_license_url()
        elif choice == '8':
            print("Exiting...")
            break
        else:
            print("Invalid choice, please try again.")


if __name__ == '__main__':
    main()

