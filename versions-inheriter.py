import os
import yaml
import json
from collections.abc import MutableMapping
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description="Process versions.json into versions-inherited-flat.json")
parser.add_argument(
    'file_versions_json', 
    metavar='filename', 
    type=str, 
    help='the JSON file name string'
)
args = parser.parse_args()

fin = Path(args.file_versions_json)
fdir = fin.parents[0]
f_flat = str(fdir) + '/' + fin.stem + '-inherited-flat.json'

print(f_flat)

# load versions.json
with open(str(fin)) as f:
    versions = yaml.safe_load(f)

def propagate(adict,adict_flat={},parent_key=''):
    # recursive propagation with flattening option
    if 'variants' in adict: # if it has variants key
        if adict['variants']: # if variants exist
            print(f'- propagating dict: {adict}')
            to_inherit = {}
            for k1,v1 in adict.items(): # get keys to propagate
                if not k1 == 'variants' and not k1 == 'children':
                    to_inherit[k1] = v1
            for k2,v2 in adict['variants'].items(): # variants
                for k1,v1 in to_inherit.items(): # propagate
                    if not k1 in adict['variants'][k2]:
                        adict['variants'][k2][k1] = v1
                # keep track:
                adict_flat[k2] = adict['variants'][k2].copy()
                hanging_variants = adict_flat[k2].pop('variants',{})
                adict_flat[k2]['children'] = list(hanging_variants.keys())
                adict_flat[k2]['parent'] = parent_key
                # propagate:
                adict['variants'][k2],flat_versions_here = propagate(adict['variants'][k2],adict_flat=adict_flat,parent_key=k2)
                # keep track:
                flat_versions_here.pop('variants',None)
                adict_flat.update(flat_versions_here)
    return adict, adict_flat

# propagate and flatten
flat_versions = {}
for k0,v0 in versions.items(): # ts and ds
    for k1,v1 in versions[k0].items(): # major versions
        v1_copy = v1.copy()
        v1_copy['children'] = list(v1_copy['variants'].keys())
        v1_copy['parent'] = None # none for major versions
        v1_copy.pop('variants',None)
        flat_versions[k1] = v1_copy # save major versions
        versions[k0][k1],flat_versions_here = propagate(v1,adict_flat=flat_versions,parent_key=k1) # propagate to minor versions, recursively
        flat_versions.update(flat_versions_here) # save other versions

# # duplicate ts's ds-compatibility to ds ... now specifying in specific DS version
# for k1,v1 in flat_versions.items():
#     if 'ds-compatibility' in v1:
#         for ver in v1['ds-compatibility']:
#             if 'ts-compatibility' in flat_versions[ver]:
#                 flat_versions[ver]['ts-compatibility'].append(k1)
#             else:
#                 flat_versions[ver]['ts-compatibility'] = [k1]

# save
# with open('versions-inherited.json','w') as f:
#     json.dump(versions,f,indent=2)

with open(f_flat,'w') as f:
    json.dump(flat_versions,f,indent=2)

