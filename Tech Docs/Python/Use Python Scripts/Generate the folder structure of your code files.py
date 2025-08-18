import os
import sys

IGNORED_FOLDERS = {'myenv', '.git', '__pycache__', 'venv', 'env'}

def print_folder_structure(start_path, indent="" "", output=sys.stdout):
    if not os.path.isdir(start_path):
        print("Invalid directory path", file=output)
        return

    folder_name = os.path.basename(start_path)
    print(f"{indent}{folder_name}/", file=output)

    for item in sorted(os.listdir(start_path)):
        if item in IGNORED_FOLDERS:
            continue  

        item_path = os.path.join(start_path, item)
        if os.path.isdir(item_path):
            print_folder_structure(item_path, indent + "│   ", output)
        else:
            print(f"{indent}│   {item}", file=output)

project_path = r"D:\MockDataGenerator"

with open("folder_structure.txt", "w", encoding="utf-8") as f:
    print_folder_structure(project_path, output=f)