import json
import argparse
from pathlib import Path
import requests

parser = argparse.ArgumentParser(
    description = 'Checks all links for 404 errors.',
)

default_file = Path(__file__).parent / "book-json" / "book-hp1-cleaned.json"
parser.add_argument('filename', nargs="?", default=default_file, help="the file to check links in")
parser.add_argument('-v', '--verbose', action="store_true", help="show verbose info")

args = parser.parse_args()

hashes = []
duplicated = 0

with open(args.filename) as f:
    data = json.load(f)

for hash, hash_data in data.items():
    if args.verbose:
        print("Inspecting hash {}".format(hash))
    if isinstance(hash_data, dict) and "url" in hash_data:
        if len(hash_data["url"]) == 0:
            if args.verbose:
                print("Hash {} has empty URL".format(hash))
            continue
        if args.verbose:
            print("Hash {} has URL: {} checking...".format(hash, hash_data["url"]))
        try:
            req = requests.get(hash_data["url"], timeout=1)
            if req.status_code != 200 or args.verbose:
                print("Hash {} URL: {} returned status code {}".format(hash, hash_data["url"], req.status_code))
        except requests.Timeout:
            print("Hash {} URL: {} timeout".format(hash, hash_data["url"]))
