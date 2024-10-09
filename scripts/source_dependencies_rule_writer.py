import json
import os
import pathlib
import argparse

# Parse command line arguments (input file source-dependencies.json and output file source_dependencies.mk)
parser = argparse.ArgumentParser(description='Generate source dependencies rule file.')
parser.add_argument('source_dependencies_json', type=pathlib.Path, help='source-dependencies.json file')
parser.add_argument('source_dependencies_mk', type=pathlib.Path, help='source_dependencies.mk file')
args = parser.parse_args()
source_dependencies_json = args.source_dependencies_json
source_dependencies_mk = args.source_dependencies_mk

# Process source-dependencies.json into data dict
with source_dependencies_json.open() as f:
    data = json.load(f)

# Write the source dependencies rule Makefile include file source_dependencies.mk
with source_dependencies_mk.open('w') as f:
    f.write('# Source dependencies\n')
    for target, dep in data.items():
        if type(dep) == str:
            dep = [dep]
        for d in dep:
            target_tex = f'$(commondir)/versioned/{target}/index.tex'
            target_html = f'$(commondir)/versioned/{target}/index.html'
            dependencies = f'source/{d}/main.py source/{d}/main.md'
            f.write(f'{target_tex}: {dependencies}\n')
            f.write(f'{target_html}: {dependencies}\n')
