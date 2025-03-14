# Parses the links.json file and creates hard links for the top-level "files" key from values to keys.
# Loops through all keys in the "directories" key and creates hard linkes for all files in the directories (values to keys).

import json
import os
import pathlib
import argparse
import difflib

# Parse the command line arguments
parser = argparse.ArgumentParser(description='Create hard links for files and directories in links.json')
# Infect meta or mesa (non-meta) files and directories
parser.add_argument('--infect-meta', action='store_true', help='Infect meta files and directories')
parser.add_argument('--infect-mesa', action='store_true', help='Infect mesa files and directories')
# Merge files if they are different (default is to replace the destination file with the source file)
parser.add_argument('--merge', action='store_true', help='Merge files if they are different')
# Dry run
parser.add_argument('--dry-run', action='store_true', help='Print what would be done without actually doing it')
# Optionally, specify a single file or a single directory to create hard links for
parser.add_argument('--files', nargs='*', help='Files to create hard link for', default=[])
parser.add_argument('--directories', nargs='*', help='Directory to create hard links for', default=[])
# Parse the arguments
args = parser.parse_args()

# Check if the user specified both --infect-meta and --infect-mesa or neither
if args.infect_meta and args.infect_mesa:
    print("Specify either --infect-meta or --infect-mesa, not both. Infection is making the infecting files and directories the source of hard links (i.e., the infected files and directories).")
    exit()
if not args.infect_meta and not args.infect_mesa:
    print("Specify either --infect-meta or --infect-mesa. Infection is making the infecting files and directories the source of hard links (i.e., the infected files and directories).")
    exit()

# Load the links.json file
with open('links.json', 'r') as file:
    links = json.load(file)

# Split into files and directories dictionaries
files = links['files']
directories = links['directories']

# Define a function that retrieves the nth previous version of a file in its git history. The .git directory should be searched for by checking the file's directory, and the parent directories, recursively, until the .git directory is found. The function should return the contents of the nth previous version of the file, or None if the file is not found in the git history.
def nth_previous_version(file, n):
    # Check if the file exists
    if not os.path.exists(file):
        print(f"File {file} not found.")
        return None
    # Return the contents of the file if n is 0
    if n == 0:
        with open(file, 'r') as f:
            return f.read()
    # Check if the file is in a git repository
    git_dir = None
    directory = os.path.dirname(file)
    while directory != '/':  # Stop at the root directory
        if directory == '':
            directory = '.'
        if '.git' in os.listdir(directory):
            git_dir = directory
            break
        directory = os.path.dirname(directory)
    if git_dir is None:
        print(f"File {file} is not in a git repository.")
        return None
    # Get the path of the file relative to the git directory
    file = os.path.relpath(file, git_dir)
    # Get the contents of the nth previous version of the file
    print(f"Getting {n}th previous version of {file} in {git_dir} ...")
    command = f"git -C {git_dir} show HEAD~{n}:{file}"
    contents = os.popen(command).read()
    return contents

# Define a function that returns the last common ancestor of two files in their respective git histories. The function should return the contents of the last common ancestor of the two files, or None if the files do not have a common ancestor.
def last_common_ancestor(file1, file2):
    # Alternately iterate through the git histories of the two files, starting from the most recent version, until a common ancestor is found
    for n1 in range(0, 30):  # Limit the number of iterations to 30
        contents1 = nth_previous_version(file1, n1)
        if contents1 is None:
            return None
        for n2 in range(0, 30):
            contents2 = nth_previous_version(file2, n2)
            if contents2 is None:
                return None
            if contents1 == contents2:
                # print(f"Common ancestor found at {n1}th previous version of {file1} and {n2}th previous version of {file2}.")
                return contents1
    return None

# Define a function that merges two files. The function should use git merge-file and replace the contents of the destination file with the merged contents. The function should return True if the merge is successful, and False otherwise. The common ancestor of the two files should be used as the base for the merge.
def merge_files(dest, src):
    # Get the last common ancestor of the two files
    common_ancestor = last_common_ancestor(dest, src)
    if common_ancestor is None:
        print(f"Files {dest} and {src} do not have a common ancestor.")
        return False
    # Merge the two files using the common ancestor
    common_ancestor_tmp = '.common_ancestor.tmp'
    with open(common_ancestor_tmp, 'w') as f:
        f.write(common_ancestor)
    command = f"git merge-file {dest} {common_ancestor_tmp} {src}"
    if args.dry_run:
        print(f"Would merge {src} into {dest} using common ancestor {common_ancestor_tmp}")
    else:
        os.system(command)
    # Remove the temporary common ancestor file
    os.remove(common_ancestor_tmp)
    return True

# Define a function to replace a file with a hard link to another file. The function should remove the destination file and create a hard link to the source file in its place. The function should return True if the hard link is created successfully, and False otherwise. If the destination file does not exist, the function should create a hard link to the source file.
def replace_with_hard_link(dest, src):
    if os.path.exists(dest):
        if not args.dry_run:
            os.remove(dest)
        print(f"Removed {dest}.")
    if not args.dry_run:
        os.link(src, dest)
    print(f"Created hard link at {dest} to {src}.")
    return True

# Define a function to find a file or directory passed to argument args.files or args.directories and return the key in links.json. The function should search for the file in the directories in links.json if it is not found in the files of links.json. Note that the file name could be either the key or the value in the files dictionary. The function should return either the source or destination file name or directory name, the opposite of what was passed to it, or None if the file or directory is not found in links.json or its directories.
def opposite_file_or_directory(file_or_directory):
    # If the file or directory starts with '..', it is not from the meta directory, so it should return a file or directory from the meta directory (if it exists in the files or directories of links.json)
    if file_or_directory.startswith('..'):
        search_keys = True
        potential_opposite = file_or_directory[3:]
    else:
        search_keys = False  # Search values
        potential_opposite = os.path.join('..', file_or_directory)
    print(f"Potential opposite: {potential_opposite}")
    # This checks if the file or directory is in the files or directories dictionary and returns the key. The meta files and directories are keys and the non-meta files and directories are values.
    for key, value in files.items():
        if search_keys:
            if key == file_or_directory:
                return value
        else:
            if value == file_or_directory:
                return key
    for key, value in directories.items():
        if search_keys:
            if key == file_or_directory:
                return value
        else:
            if value == file_or_directory:
                return key
    # This checks if the file or directory is in the directories found in the directories of the dictionary (as a key or value) and returns the key
    for key, value in directories.items():
        # Recursively search for the file or directory in the directories
        if search_keys:
            if os.path.exists(key):
                for root_, dirs_, files_ in os.walk(key):
                    for file_ in files_:
                        if file_ == file_or_directory:
                            return potential_opposite
        else:
            if os.path.exists(value):
                for root_, dirs_, files_ in os.walk(value):
                    for file_ in files_:
                        if file_ == file_or_directory.split('/')[-1]:
                            return potential_opposite
    return None

# Create hard links for the files specified on the command line
if len(args.files) > 0:  # Process files only
    for file in args.files:
        opposite = opposite_file_or_directory(file)
        if opposite is not None:
            if args.infect_meta:
                if file.startswith('..'):  # Given as mesa file
                    src = file
                    dest = opposite
                else:  # Given as meta file
                    src = opposite
                    dest = file
            else:  # Infect mesa
                if file.startswith('..'):  # Given as mesa file
                    src = opposite
                    dest = file
                else:  # Given as meta file
                    src = file
                    dest = opposite
            print(f"Infecting {dest} with {src} ...")
            # Use the difference between the dest and src files, if dest exists
            if os.path.exists(dest):
                with open(dest, 'r') as f:
                    dest_lines = f.readlines()
                with open(src, 'r') as f:
                    src_lines = f.readlines()
                diff = difflib.unified_diff(dest_lines, src_lines)
                diff = list(diff)
                if len(diff) == 0:
                    print(f"File {dest} is the same as {src}. Replacing with merged hard link.")
                else:
                    print(f"Destination file {dest} is different from source file {src}.")
                    print("".join(diff))
            else:
                print(f"File {dest} does not exist. Creating hard link.")
            # Make directories if necessary
            if not args.dry_run:
                pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
            else:
                if not os.path.exists(pathlib.Path(dest).parent):
                    print(f"Would create directory {pathlib.Path(dest).parent}")
            # Create the hard link
            if not args.dry_run:
                if args.merge:
                    merge_files(dest=src, src=dest)  # Merge the files into src
                    os.remove(dest)  # Remove the destination file
                    os.link(src, dest)  # Create the hard link
                else:
                    replace_with_hard_link(dest=dest, src=src)
            else:
                print(f"Would create hard link at {dest} to {src}")
        else:
            print(f"File {file} not found in links.json. Skipping.")
    exit()  # Exit after the last file

# Create hard links for the directories specified on the command line
if len(args.directories) > 0:  # Process directories only
    for directory in args.directories:
        opposite = opposite_file_or_directory(directory)
        if opposite is not None:
            if args.infect_meta:
                if directory.startswith('..'):  # Given as mesa directory
                    src = directory
                    dest = opposite
                else:  # Given as meta directory
                    src = opposite
                    dest = directory
            else:  # Infect mesa
                if directory.startswith('..'):  # Given as mesa directory
                    src = opposite
                    dest = directory
                else:  # Given as meta directory
                    src = directory
                    dest = opposite
            print(f"Infecting {dest} with {src} ...")
            # Loop through all files in the directory
            for root, dirs, files in os.walk(src):
                for file in files:
                    src_file = os.path.join(root, file)
                    dest_file = os.path.join(dest, file)
                    # Use the difference between the dest and src files, if dest exists
                    if os.path.exists(dest_file):
                        with open(dest_file, 'r') as file:
                            dest_lines = file.readlines()
                        with open(src_file, 'r') as file:
                            src_lines = file.readlines()
                        diff = difflib.unified_diff(dest_lines, src_lines)
                        diff = list(diff)
                        if len(diff) == 0:
                            print(f"File {dest_file} is the same as {src_file}. Replacing with merged hard link.")
                        else:
                            print(f"Destination file {dest_file} is different from source file {src_file}.")
                            print("".join(diff))
                    else:
                        print(f"File {dest_file} does not exist. Creating hard link.")
                    # Make directories if necessary
                    if not args.dry_run:
                        pathlib.Path(dest_file).parent.mkdir(parents=True, exist_ok=True)
                    else:
                        if not os.path.exists(pathlib.Path(dest_file).parent):
                            print(f"Would create directory {pathlib.Path(dest_file).parent}")
                    # Create the hard link
                    if not args.dry_run:
                        if args.merge:
                            merge_files(dest=src, src=dest)  # Merge the files into src
                            os.remove(dest)  # Remove the destination file
                            os.link(src, dest)  # Create the hard link
                        else:
                            replace_with_hard_link(dest=dest, src=src)
                    else:
                        print(f"Would create hard link at {dest_file} to {src_file}")
        else:
            print(f"Directory {directory} not found in links.json. Skipping.")
    exit()  # Exit after the last directory

# Create hard links for the files
for dest, src in files.items():
    # Use the difference between the dest and src files, if dest exists
    if os.path.exists(dest):
        with open(dest, 'r') as file:
            dest_lines = file.readlines()
        with open(src, 'r') as file:
            src_lines = file.readlines()
        diff = difflib.unified_diff(dest_lines, src_lines)
        diff = list(diff)
        if len(diff) == 0:
            print(f"File {dest} is the same as {src}. Replacing with merged hard link.")
        else:
            print(f"Destination file {dest} is different from source file {src}.")
            print("".join(diff))
    else:
        print(f"File {dest} does not exist. Creating hard link.")
    # Make directories if necessary
    if not args.dry_run:
        pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
    else:
        if not os.path.exists(pathlib.Path(dest).parent):
            print(f"Would create directory {pathlib.Path(dest).parent}")
    # Create the hard link
    if not args.dry_run:
        if args.merge:
            merge_files(dest=src, src=dest)  # Merge the files into src
            os.remove(dest)  # Remove the destination file
            os.link(src, dest)  # Create the hard link
        else:
            replace_with_hard_link(dest=dest, src=src)
    else:
        print(f"Would create hard link at {dest} to {src}")

def is_binary(filename):
    try:
        with open(filename, 'r') as f:
            for line in f:
                pass
        return False  # If no exception, it's likely a text file
    except UnicodeDecodeError:
        return True  # If exception, it's likely a binary file

# Create hard links for all files in the directories, recursively, ignoring .DS_Store files
for dest_dir, src_dir in directories.items():
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file != '.DS_Store':
                src = os.path.join(root, file)
                dest = os.path.join(dest_dir, file)
                # Use the difference between the dest and src files, if dest exists
                if os.path.exists(dest):
                    # Check if the file is binary
                    if is_binary(dest):
                        print(f"File {dest} is binary. Skipping.")
                        continue
                    with open(dest, 'r') as file:
                        dest_lines = file.readlines()
                    with open(src, 'r') as file:
                        src_lines = file.readlines()
                    diff = difflib.unified_diff(dest_lines, src_lines)
                    diff = list(diff)
                    if len(diff) == 0:
                        print(f"File {dest} is the same as {src}. Replacing with merged hard link.")
                        if not args.dry_run:
                            os.remove(dest)
                    else:
                        print(f"Destination file {dest} is different from source file {src}.")
                        print("".join(diff))
                else:
                    print(f"File {dest} does not exist. Creating hard link.")
                # Make directories if necessary
                if not args.dry_run:
                    pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
                else:
                    if not os.path.exists(pathlib.Path(dest).parent):
                        print(f"Would create directory {pathlib.Path(dest).parent}")
                # Create the hard link
                if not args.dry_run:
                    if args.merge:
                        merge_files(dest=src, src=dest)  # Merge the files into src
                        if os.path.exists(dest):
                            os.remove(dest)  # Remove the destination file
                        os.link(src, dest)  # Create the hard link
                    else:
                        replace_with_hard_link(dest=dest, src=src)
                else:
                    print(f"Would create hard link at {dest} to {src}")