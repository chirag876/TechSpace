import os
import sys

IGNORED_FOLDERS = {
    'myenv', '.git', '__pycache__', 'venv', 'env', 'node_modules',
    '.idea', '.vscode', '.pytest_cache', 'dist', 'build', '.eggs',
    '.mypy_cache', '.tox', '.nox', '.coverage', 'htmlcov',
    '.github', '.gitlab', '.vs', 'logs', 'tmp', 'temp', 'cache', 'caches'
}


def print_tree(start_path, prefix="", output=sys.stdout, max_depth=None, current_depth=0):
    if max_depth is not None and current_depth > max_depth:
        return

    try:
        items = [item for item in os.listdir(start_path) if item not in IGNORED_FOLDERS]
    except PermissionError:
        return

    items.sort()
    total_items = len(items)

    for index, item in enumerate(items):
        item_path = os.path.join(start_path, item)
        connector = "└── " if index == total_items - 1 else "├── "

        print(f"{prefix}{connector}{item}", file=output)

        if os.path.isdir(item_path):
            extension = "    " if index == total_items - 1 else "│   "
            print_tree(
                item_path,
                prefix + extension,
                output,
                max_depth,
                current_depth + 1
            )


project_path = 'FOLDER_PATH_HERE'  # Replace with your project path

with open("folder_structure.txt", "w", encoding="utf-8") as f:
    print(project_path)
    print_tree(project_path, output=f, max_depth=5)
