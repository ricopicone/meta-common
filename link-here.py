# Parses the links.json file and creates hard links for the top-level "files" key from keys to values.
# Loops through all keys in the "directories" key and creates hard linkes for all files in the directories.

import json
import os
import pathlib

# Load the links.json file
with open('links.json', 'r') as file:
    links = json.load(file)

# Split into files and directories dictionaries
files = links['files']
directories = links['directories']

# Create hard links for the files
for src, dest in files.items():
    # If dest exists, rm it first
    if os.path.exists(dest):
        os.remove(dest)
    # Make directories if necessary
    pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
    # Create the hard link
    os.link(src, dest)

# Create hard links for all files in the directories, recursively, ignoring .DS_Store files
for src_dir, dest_dir in directories.items():
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            if file != '.DS_Store':
                src = os.path.join(root, file)
                dest = os.path.join(dest_dir, file)
                # If dest exists, rm it first
                if os.path.exists(dest):
                    os.remove(dest)
                # Make directories if necessary
                pathlib.Path(dest).parent.mkdir(parents=True, exist_ok=True)
                # Create the hard link
                os.link(src, dest)