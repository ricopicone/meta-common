import yaml
import argparse
from pathlib import Path
import json

parser = argparse.ArgumentParser(description="Clean a JSON file.")
parser.add_argument(
    'input_json', 
    metavar='fin', 
    type=str, 
    help='the input JSON file name string'
)
parser.add_argument(
    'output_json', 
    metavar='fout', 
    type=str, 
    help='the output JSON file name string'
)
args = parser.parse_args()

fin = Path(args.input_json)
fclean = Path(args.output_json)

print(f'Cleaning {fin} and saving to {fclean} ...')

def dict_raise_on_duplicates(ordered_pairs):
    """Reject duplicate keys."""
    d = {}
    for k, v in ordered_pairs:
        if k in d:
            print(f'Warning: Duplicate hash {k}')
            if not(k.startswith('fig:') or k.startswith('tbl:') or k.startswith('alg:') or k.startswith('lst:') or k.startswith('eq:')):
                ValueError("Duplicate hash: %r" % (k,))
        else:
           d[k] = v
    return d

# fix trailing comma in json and escaping escape \ characters

with open(fin, 'r') as file:
    data = file.readlines()

for i,line in enumerate(data):
    data[i] = line.replace("\\","\\\\") # escape \ for valid json
    if line.startswith('}'):
        data[i-1] = data[i-1].rstrip(', \n')

with open(fclean,'w') as file:
    file.writelines(data)

# now that it's valid json, read it in for further procesing

with open(fclean,'r') as f:
    # book = yaml.safe_load(f)
    book = json.load(f, object_pairs_hook=dict_raise_on_duplicates)

## replace characters

for k,v in book.items():
    if isinstance(v,dict):
        if 'hash' in v:
            title = v['title'].replace(':','&#58;') # colons
            book[k]['title'] = title

# write

with open(fclean,'w') as file:
    json.dump(book,file,indent=2)
    print(' ... done.')