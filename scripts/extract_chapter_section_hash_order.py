import json
import argparse
import os
import pathlib

# Parse arguments (the directory containing the book-<edition>-cleaned.json files)
parser = argparse.ArgumentParser(description='Extract the order of sections and chapters from the JSON files.')
parser.add_argument('directory', type=str, help='The directory containing the book-<edition>-cleaned.json files.')
args = parser.parse_args()

print("Adding 'next' and 'prev' hash mappings to the cleaned JSON files in the directory: ", args.directory)

# Step 1: Read the JSON files
# 1.1 Identify the JSON files in the directory
# 1.2 Load the JSON files

# 1.1 Identify the JSON files in the directory
# If directory passed is a file, just use that file
json_files = []
if os.path.isfile(args.directory):
    json_files.append(args.directory)
else:
    for root, dirs, files in os.walk(args.directory):
        for file in files:
            if file.endswith('.json') and file.startswith('book-') and file.endswith('-cleaned.json'):
                json_files.append(os.path.join(root, file))

# Extract the edition numbers from the filenames
edition_numbers = []
for file in json_files:
    file_stem = pathlib.Path(file).stem
    edition_number = file_stem.split('-')[1]
    edition_numbers.append(edition_number)

# 1.2 Load the JSON files
data = {}
for i, file in enumerate(json_files):
    with open(file, 'r') as file:
        data[edition_numbers[i]] = json.load(file)

# Step 2: For each edition, iterate through the sections and chapters
# 2.1 Find keys that contain a dictionary with a key "type" and value "section" or "chapter"

section_chapter_keys = {}
for edition, d in data.items():
    section_chapter_keys[edition] = []
    for k, v in d.items():
        if isinstance(v, dict) and v.get('type') in ['lab', 'section', 'chapter']:
            print(f"hash: {v.get('hash')}, type: {v.get('type')}, sec: {v.get('sec')}")
            section_chapter_keys[edition].append(k)
            # fix chapter sec values
            if v.get('type') == 'chapter':  # Both labs and chapter sec values start with 'L'
                v['sec'] = v['sec'].replace('L', '') + '.000'

# 2.2 Iterate through the section and chapter keys to order them by their v['sec'] values

def pad_version(version):
    """Pad version parts with leading zeros to ensure correct sorting."""
    version_parts = version.split('.')
    return '.'.join([part.zfill(3) for part in version_parts])

def handle_lab(version):
    if version.startswith('L'):
        # strip the 'L' and add '.999' to ensure labs are sorted after other sections
        version = version[1:] + '.999'
    return version
    

ordered_section_chapter_keys = {}
for edition, sck in section_chapter_keys.items():
    ordered_section_chapter_keys[edition] = sorted(
        sck, 
        key=lambda k: pad_version(handle_lab(data[edition][k].get('sec', 0)))
    )
# print(f"Ordered section and chapter keys: {ordered_section_chapter_keys}")

# 3.3 Write the ordered section and chapter keys to the hash_mappings dictionary

hash_mappings = {}
for edition, sck in ordered_section_chapter_keys.items():
    hash_mappings[edition] = {}
    hash_mappings[edition]['next'] = {}
    hash_mappings[edition]['prev'] = {}
    for i, key in enumerate(sck):
        hash_mappings[edition]['next'][key] = sck[i+1] if i+1 < len(sck) else None
        hash_mappings[edition]['prev'][key] = sck[i-1] if i > 0 else None
# print(f"Hash mappings: {hash_mappings}")

# Step 4: Append the 'next' and 'prev' hash_mappings to data

for edition, d in data.items():
    print(f"hash_mappings[edition]['next']: {hash_mappings[edition]['next']}")
    data[edition]['next'] = hash_mappings[edition]['next']
    data[edition]['prev'] = hash_mappings[edition]['prev']
    for k in ordered_section_chapter_keys[edition]:
        data[edition][k]['next'] = hash_mappings[edition]['next'][k]
        data[edition][k]['prev'] = hash_mappings[edition]['prev'][k]

# Step 5: Write the updated JSON files
for edition, d in data.items():
    with open(json_files[edition_numbers.index(edition)], 'w') as file:
        json.dump(d, file, indent=4)
