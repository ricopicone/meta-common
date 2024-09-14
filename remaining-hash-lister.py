import json
import itertools
import random
import os
from os.path import exists
import sys
from pathlib import Path, PurePosixPath
sys.path.append(Path(__file__).parent.parent)
common_dir = Path(__file__).parent
working_dir = Path(os.getcwd())

def convert_tuple(tup):
    s = ''.join(tup)
    return s

def print_hashes(lst):
	print('\t'.join(lst))
	print(f'({len(lst)} remaining)')
	print(f'Here is one: {convert_tuple(random.choice(lst))}')

h_possible_tuples = list(itertools.permutations('abcdefghijklmnpqrstuvwxyz123456789',2))
h_possible = map(convert_tuple,h_possible_tuples)

with open(f'{common_dir}/book-defs.json') as f:
    book_defs = json.load(f)

h_used = []
for ed,details in book_defs['editions'].items():
    clean_json = details['json-file-cleaned']
    json_file = PurePosixPath(clean_json)
    if str(json_file.parent.parent) == str(working_dir.stem):
        json_file = json_file.parent.stem + '/' + json_file.name
    if exists(json_file):
        with open(json_file) as f:
            edition = json.load(f)
            h_used = h_used + list(edition.keys())

h_remaining = list(set(h_possible) - set(h_used))

print_hashes(h_remaining)
