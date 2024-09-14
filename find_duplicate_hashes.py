import json
import sys
import yaml
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(
    description = 'Finds duplicated hashes to prevent errors.',
)

default_file = Path(__file__).parent / "book-json" / "book-0-raw.json"
parser.add_argument('filename', nargs="?", default=default_file, help="the file to parse for duplicates")
parser.add_argument('-v', '--verbose', action="store_true", help="show verbose info")

args = parser.parse_args()

if Path(args.filename) != default_file:
    print("The cleaned JSON files automatically have many duplicate hashes removed. It is recommended to run this script on the raw JSON file for this reason. Furthermore, this script assumes the file format is in the exact format create by LaTeX.")
    
hashes = []
duplicated = 0

with open(args.filename) as f:
    for line in f.readlines():
        if "{" in line and "}" in line:
            line = line.replace("\\", "\\\\")
            data_start = line.find("{")
            data_end = line.rfind("}")
            data = json.loads(line[data_start:data_end+1])
            if "hash" in data and len(data["hash"]):
                hash = data["hash"]
                if hash in hashes:
                    duplicated += 1
                    print('Hash "{}" duplicated!'.format(hash))
                    if args.verbose:
                        print(data)
                else:
                    hashes.append(hash)
                    
print(f"{duplicated} hashes duplicated!")
