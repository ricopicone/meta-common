import os
import yaml
import json
from collections.abc import MutableMapping
import argparse
from pathlib import Path
from collections import OrderedDict

parser = argparse.ArgumentParser(description="Process versions-inherited-flat.json into versions-list-XXX.json for typesetting hardware lists. Also uses the raw versions.json.")
parser.add_argument(
    'file_versions_json', 
    metavar='file_versions_json filename', 
    type=str, 
    help='the file_versions_json JSON file name string ... versions-inherited-flat.json'
)
parser.add_argument(
    'file_versions_json_raw', 
    metavar='file_versions_json_raw filename', 
    type=str, 
    help='the file_versions_json_raw JSON file name string ... versions.json'
)
parser.add_argument(
    'book_defs_json', 
    metavar='book_defs_json filename', 
    type=str, 
    help='the book_defs_json JSON file name string ... book-defs.json'
)
args = parser.parse_args()

fin = Path(args.file_versions_json)
fin_raw = Path(args.file_versions_json_raw)
book_defs_json = Path(args.book_defs_json)
fdir = fin.parents[0]
f_list_base = str(fdir) + '/versions-list-'

print(f_list_base)

# load versions-inherited-flat.json
with open(str(fin)) as f:
    versions = yaml.safe_load(f)

# load versions.json
with open(str(fin_raw)) as f:
    versions_raw = yaml.safe_load(f)

# load book-defs.json
with open(str(book_defs_json)) as f:
    bookdefs = yaml.safe_load(f)

def capfirst(s):
    return s[:1].upper() + s[1:]

def is_key_nested(d, keys):
    if not keys:
        return True
    return keys[0] in d and f(d[keys[0]], keys[1:])

def enumerater_general_md(versions_here,lines,lines_key,edition,depth=0,old_depth=0,skip=[],general=False,ts_version=''):
    lines[edition][lines_key].append(f'\n')
    # indent = '    '*depth
    indent = ''
    for k,v in versions_here.items():
        if k not in skip:
            if type(v) is str:
                if (k == 'hash'):
                    h = versions_here['hash']
                    # lines[edition][lines_key].append(f'{indent}#. For suppliers, see: [{bookdefs["url-companion"].replace("https://","").replace("http://","")}/{h}]({bookdefs["url-companion"]}/{h}){{.myurl .inline h="{h}"}}.\n')
                elif (k == 'quantity'):
                    lines[edition][lines_key].append(f'{indent}#. Total quantity: {v}\n')
                elif (k == 'emulation'):
                    continue # just info, signifying elsewhere
                elif (k == 'general'):
                    continue # just info, signifying elsewhere
                elif not (k == 'name') and not (k == 'kind') and not (k == 'description') and not (k == 'hash') and not (k == 'variants') and not (k == 'url'):
                    lines[edition][lines_key].append(f'{indent}<div class="version-list-item">{capfirst(k)}')
                    lines[edition][lines_key].append(f': {capfirst(v)}</div>\n')
            elif type(v) is list and len(v) > 0:
                if k == 'variables':
                    if len(ts_version) > 0:
                        summary = f'Variables (different for each [specific {ts_version} system](#specific-target-systems-{ts_version}))'
                    else:
                        summary = f'Variables (different for each [specific target system](#specific-target-systems))'
                else:
                    summary = k
                lines[edition][lines_key].append(f'{indent}<details open><summary>{capfirst(summary)}</summary>')
                item_end = ''
                for li in v:
                    lines[edition][lines_key].append(f'\n{indent}<div class="version-list-item">{capfirst(li)}</div>')
                lines[edition][lines_key].append(f'\n</details>\n')
            elif (type(v) is dict) and not (k == 'variants'):
                if k not in skip:
                    # ok = False
                    # if general: # was being selective about general but was too hard to explain
                    #     if 'general' in v:
                    #         if v['general']:
                    #             ok = True
                    # else:
                    #     ok = True
                    ok = True
                    if ok:
                        if 'hash' in v:
                            label = ''
                            # label = f'(ID: [{v["hash"]}]{{.label}})'
                        else:
                            label = ''
                        em = ''
                        if 'emulation' in v:
                            if (v['emulation'] == 'yes'):
                                em = '<div class="tooltip"><div data-md-tooltip="has software emulation support"><span class="fa-solid fa-laptop-code"></span></div></div>'
                                # em = '<div class="tooltip"><div data-md-tooltip="has software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-check"></span></div></div>'
                            else:
                                em = ''
                                # em = '<div class="tooltip"><div data-md-tooltip="no software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-xmark"></span></div></div>'
                        else:
                            em = ''
                            # em = '<div class="tooltip"><div data-md-tooltip="no software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-xmark"></span></div></div>'
                        if (k == 'specific'):
                            lines[edition][lines_key].append(f'{indent}#. Devices to choose from that satisfy the general requirements:')
                        # check if any sub-elements will make the cut and use class="empty" if so (this needs refactored)
                        else:
                            sub_elements = list(set(v) - set(['hash','emulation','name','kind','unspecific','specific','quantity','general']))
                            print(f'\n{sub_elements}\n')
                            if len(sub_elements) > 0:
                                if 'name' in v:
                                    if 'kind' in v:
                                        if 'description' in v:
                                            lines[edition][lines_key].append(f'{indent}<details><summary>{capfirst(v["kind"])}: {capfirst(v["name"])} {label} {em}</summary> {v["description"]}')
                                        else:
                                            lines[edition][lines_key].append(f'{indent}<details><summary>{capfirst(v["kind"])}: {capfirst(v["name"])} {label} {em}</summary>')
                                    else:
                                        lines[edition][lines_key].append(f'{indent}<details><summary>{capfirst(v["name"])} {label} {em}</summary>')
                                else:
                                    if 'url' in v:
                                        lines[edition][lines_key].append(f'{indent}<details><summary><a href="{v["url"]}" target="_blank">{capfirst(k)}</a> {em}</summary>')
                                    else:
                                        lines[edition][lines_key].append(f'{indent}<details><summary>{capfirst(k)} {em}</summary>')
                                enumerater_general_md(v,lines,lines_key,edition,depth+1,old_depth=depth,skip=skip,general=general,ts_version=ts_version)
                            else:
                                if 'name' in v:
                                    if 'kind' in v:
                                        if 'description' in v:
                                            lines[edition][lines_key].append(f'{indent}<details class="empty"><summary>{capfirst(v["kind"])}: {capfirst(v["name"])} {label} {em}</summary> {v["description"]}</details>')
                                        else:
                                            lines[edition][lines_key].append(f'{indent}<details class="empty"><summary>{capfirst(v["kind"])}: {capfirst(v["name"])} {label} {em}</summary></details>')
                                    else:
                                        lines[edition][lines_key].append(f'{indent}<details class="empty"><summary>{capfirst(v["name"])} {label} {em}</summary></details>')
                                else:
                                    lines[edition][lines_key].append(f'{indent}<details class="empty"><summary>{capfirst(k)} {label} {em}</summary></details>')
        if k == next(reversed(versions_here)) and not depth == 0:
            lines[edition][lines_key].append(f'</details>\n')
    return lines

def enumerater_general_tex(versions_here,lines,lines_key,edition,depth=0,old_depth=0,skip=[],general=False,ts_version=''):
    lines[edition][lines_key].append(f'\n')
    # indent = '    '*depth
    indent = ''
    dd = depth - old_depth
    enum_shift = ''
    for d in range(0,abs(dd)):
        if dd > 0:
            enum_shift = enum_shift+'\n\\begin{enumerate}\n'
        elif dd < 0:
            enum_shift = enum_shift+'\n\\end{enumerate}\n'
    lines[edition][lines_key].append(enum_shift)
    for k,v in versions_here.items():
        if k not in skip:
            if type(v) is str:
                if (k == 'hash'):
                    h = versions_here['hash']
                    # lines[edition][lines_key].append(f'{indent}#. For suppliers, see: [{bookdefs["url-companion"].replace("https://","").replace("http://","")}/{h}]({bookdefs["url-companion"]}/{h}){{.myurl .inline h="{h}"}}.\n')
                elif (k == 'quantity'):
                    lines[edition][lines_key].append(f'{indent}\\item Total quantity: {v}\n')
                elif (k == 'emulation'):
                    continue # just info, signifying elsewhere
                elif (k == 'general'):
                    continue # just info, signifying elsewhere
                elif not (k == 'name') and not (k == 'kind') and not (k == 'description') and not (k == 'hash') and not (k == 'variants') and not (k == 'url'):
                    lines[edition][lines_key].append(f'{indent}\\item {capfirst(k)}')
                    lines[edition][lines_key].append(f': {capfirst(v)}\n')
            elif type(v) is list and len(v) > 0:
                if k == 'variables':
                    if len(ts_version) > 0:
                        summary = f'Variables (different for each specific {ts_version} system—see \\cref{{ef}})'
                    else:
                        summary = f'Variables (different for each specific system—see \\cref{{ef}})'
                else:
                    summary = k
                lines[edition][lines_key].append(f'{indent}\\item {capfirst(summary)}')
                if v:
                    lines[edition][lines_key].append(f'{indent}\\begin{{enumerate}}\n')
                for li in v:
                    lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(li)}')
                if v:
                    lines[edition][lines_key].append(f'{indent}\\end{{enumerate}}\n')
            elif (type(v) is dict) and not (k == 'variants'):
                if k not in skip:
                    if depth == 0:
                        itlabel_tf = True
                    else:
                        itlabel_tf = False
                    ok = True
                    if ok:
                        if 'hash' in v:
                            # label = ''
                            label = f'\\label{{component-{v["hash"]}}}'
                        else:
                            label = ''
                        em = ''
                        if 'emulation' in v:
                            if (v['emulation'] == 'yes'):
                                em = '(software emulation support)'
                                # em = '<div class="tooltip"><div data-md-tooltip="has software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-check"></span></div></div>'
                            else:
                                em = ''
                                # em = '<div class="tooltip"><div data-md-tooltip="no software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-xmark"></span></div></div>'
                        else:
                            em = ''
                            # em = '<div class="tooltip"><div data-md-tooltip="no software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-xmark"></span></div></div>'
                        if (k == 'specific'):
                            lines[edition][lines_key].append(f'{indent}\\item Devices to choose from that satisfy the general requirements:')
                        # check if any sub-elements will make the cut and use class="empty" if so (this needs refactored)
                        else:
                            sub_elements = list(set(v) - set(['hash','emulation','name','kind','unspecific','specific','quantity','general']))
                            print(f'\n{sub_elements}\n')
                            if len(sub_elements) > 0:
                                if 'name' in v:
                                    if 'kind' in v:
                                        if 'description' in v:
                                            lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["kind"])}: {capfirst(v["name"])} {em} {label}\\\\ {v["description"]}')
                                        else:
                                            lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["kind"])}: {capfirst(v["name"])} {em} {label}')
                                    else:
                                        lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["name"])} {label} {em}')
                                else:
                                    if 'url' in v:
                                        lines[edition][lines_key].append(f'\n{indent}{capfirst(k)}\\myurlinline{{{v["url"]}}}{{{v["hash"]}}} ({em}) {label}')
                                    else:
                                        lines[edition][lines_key].append(f'\n{indent}{capfirst(k)} ({em})')
                                enumerater_general_tex(v,lines,lines_key,edition,depth+1,old_depth=depth,skip=skip,general=general,ts_version=ts_version)
                            else:
                                if 'name' in v:
                                    if 'kind' in v:
                                        if 'description' in v:
                                            lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["kind"])}: {capfirst(v["name"])} {em} {label}\\\\ {v["description"]}')
                                        else:
                                            lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["kind"])}: {capfirst(v["name"])} {em} {label}')
                                    else:
                                        lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(v["name"])} {em} {label}')
                                else:
                                    lines[edition][lines_key].append(f'\n{indent}\\item {capfirst(k)} {em} {label}')
        if k == next(reversed(versions_here)):
            lines[edition][lines_key].append(f'\\end{{enumerate}}\n')
    return lines

headings = OrderedDict()
headings = {
    'target-computer': {
        'name': 'Target computer',
        'hash': 'a6'
    },
    'ui': {
        'name': 'User interface (UI) subsystem',
        'hash': 'y6'
    },
    'electromechanical-subsystem': {
        'name': 'Electromechanical subsystem',
        'hash': 'lf'
    },
    'prototyping': {
        'name': 'Prototyping and testing hardware',
        'hash': 'wi'
    }
}

# TS

## Just general T1, T2, etc., no specifics (e.g. no T1a, T1b, T2a)
lines = {}
edition = 'all'
lines[edition] = {}
tss = [] # specific versions
for k,v in versions.items(): # gather the specific version keys
    if 'ts-specific' in v:
        if v['ts-specific']:
            tss.append(k)

# markdown/html version
for k1,v1 in versions.items():
    if k1[0] == 'T' and k1 not in tss: # is it a ts version and is it not specific?
        lines[edition][k1] = ['\n\n```{=latex}\n\\myindex{Target system!specific} \n```\n\n```{=markdown}\n']
        # lead-in including header
        lines[edition][k1].append(f'''
## General {k1} target system {{#general-target-system-{k1} .ts .{k1} h="wp"}}\n
This section includes a definition of the general {k1} target system. 
For specific hardware instances, see 
[Specific {k1} target systems](#specific-target-systems-{k1}) below. 
The general {k1} target system diagram is shown in [@fig:system-diagram-0-target-system-{k1}].\n
![The general {k1} target system diagram. Subsystems are in bold-face.](figures/system-diagram-target-{k1}/system-diagram-target-{k1}){{#fig:system-diagram-0-target-system-{k1} .figure .standalone}}\n
We define the general {k1} target system as follows.''')
        for h,hv in headings.items():
            if h in versions[k1].keys():
                if 'hash' in versions[k1][h]:
                    label = ''
                    # label = f'(ID: [{versions[k1][h]["hash"]}]{{.label .component}})'
                else:
                    label = ''
                if type(versions[k1][h]) is str:
                    lines[edition][k1].append(f'\n\n### {hv["name"]} {{#{h} .ts .{k1} h="{hv["hash"]}"}}\n\n{label}')
                    lines[edition][k1].append(f'{versions[k1][h]}.\n\n')
                elif type(versions[k1][h]) is dict:
                    if h == 'target-computer':
                        deets = '<details><summary>Details</summary>'
                    else:
                        deets = ''
                    if 'name' in versions[k1][h]:
                                if 'description' in versions[k1][h]:
                                    if 'kind' in versions[k1][h]:
                                        lines[edition][k1].append(f'\n\n### {hv["name"]}: {versions[k1][h]["kind"]}, {versions[k1][h]["name"]} {label} {{#{h} .ts .{k1} h="{hv["hash"]}"}}\n<p>{versions[k1][h]["description"]}</p>\n{deets}\n\n')
                                    else:
                                        lines[edition][k1].append(f'\n\n### {hv["name"]}: {versions[k1][h]["name"]} {label} {{#{h} .ts .{k1} h="{hv["hash"]}"}}\n<p>{versions[k1][h]["description"]}</p>\n{deets}\n\n')
                                else:
                                    lines[edition][k1].append(f'\n\n### {hv["name"]}: {versions[k1][h]["name"]} {label} {{#{h} .ts .{k1} h="{hv["hash"]}"\n\n{deets}')
                    else:
                        lines[edition][k1].append(f'\n\n### {hv["name"]} {{#{h} .ts .{k1} h="{hv["hash"]}"}}\n\n{deets}\n\n')
                    lines = enumerater_general_md(versions[k1][h],lines,k1,edition,depth=0,skip=["specific","suppliers","quantity","unspecific"],general=True,ts_version=k1)
                    if h == 'target-computer':
                        lines[edition][k1].append(f'\n</details>')
        lines[edition][k1].append('\n```')

### save markdown/html general version
iv = 0;
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-TS-general.md')
        if iv == 0:
            write_mode = 'w'
        else:
            write_mode = 'a'
        iv = iv + 1
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-TS-general.md', write_mode) as f:
            for item in v:
                f.write("%s" % item)

# latex version (by book edition, straight to latex for explicit include)
for edition,vedition in bookdefs['editions'].items():
    for k1,v1 in versions.items():
        if k1[0] == 'T' and k1 not in tss: # is it a ts version and is it not specific?
            if vedition['v-ts'] == k1: # does this edition have this ts version?
                lines[edition] = {}
                lines[edition][k1] = []
                lines[edition][k1].append('\n\n')
                # lead-in including header
                lines[edition][k1].append(f'''
        \\section[][ts][]{{general-target-system{k1}}}{{wp}}{{General {k1} target system}}\n\n
        \\myindex[start]{{Target system!general}}\n
        This section includes a definition of the general {k1} target system. 
        For specific hardware instances, see \\cref{{ef}} below. 
        The general {k1} target system diagram is shown in \\cref{{fig:system-diagram-0-target-system-{k1}}}.\n\n
        \\begin{{figure}}\n
        \\centering\n
        \\includestandalone{{figures/system-diagram-target-{k1}/system-diagram-target-{k1}}}\n
        \\figcaption[color=color][nofloat]{{fig:system-diagram-0-target-system-{k1}}}{{The general {k1} target system diagram. Subsystems are in bold-face.}}\n
        \\end{{figure}}\n\n
        We define the general {k1} target system as follows.''')
                for h,hv in headings.items():
                    if h in versions[k1].keys():
                        if 'hash' in versions[k1][h]:
                            label = ''
                            # label = f'(ID: [{versions[k1][h]["hash"]}]{{.label .component}})'
                        else:
                            label = ''
                        if type(versions[k1][h]) is str:
                            lines[edition][k1].append(f'\n\n\\subsection[][ts][]{{{h}}}{{{hv["hash"]}}}{{{hv["name"]}}} \n\n{label}\n\n\\begin{{enumerate}}\n')
                            lines[edition][k1].append(f'{versions[k1][h]}.\n\n')
                        elif type(versions[k1][h]) is dict:
                            if h == 'target-computer':
                                # deets = f'\\label{{component-{headings["target-computer"]["hash"]}}}'
                                deets = ''
                            else:
                                deets = ''
                            if 'name' in versions[k1][h]:
                                if 'description' in versions[k1][h]:
                                    if 'kind' in versions[k1][h]:
                                        lines[edition][k1].append(f'\n\n\\subsection[][ts][]{{{h}}}{{{hv["hash"]}}}{{{hv["name"]}: {versions[k1][h]["kind"]}, {versions[k1][h]["name"]} {label}}}\n\n{versions[k1][h]["description"]}\n\n{deets}\n\n\\begin{{enumerate}}\n')
                                    else:
                                        lines[edition][k1].append(f'\n\n\\subsection[][ts][]{{{h}}}{{{hv["hash"]}}}{{{hv["name"]}: {versions[k1][h]["name"]} {label}}}\n\n{versions[k1][h]["description"]}\n\n{deets}\n\n\\begin{{enumerate}}\n')
                                else:
                                    lines[edition][k1].append(f'\n\n\\subsection[][ts][]{{{h}}}{{{hv["hash"]}}}{{{hv["name"]}: {versions[k1][h]["name"]} {label}}}\n\n{deets}\n\n\\begin{{enumerate}}\n')
                            else:
                                lines[edition][k1].append(f'\n\n\\subsection[][ts][]{{{h}}}{{{hv["hash"]}}}{{{hv["name"]} {label}}}\n\n{deets}\n\n\\begin{{enumerate}}\n')
                            lines = enumerater_general_tex(versions[k1][h],lines,k1,edition,depth=0,skip=["specific","suppliers","quantity","unspecific"],general=True,ts_version=k1)
                            # if h == 'target-computer':
                            #     lines[edition][k1].append('\n\\end{enumerate}\n')
                lines[edition][k1].append('\n\n\\myindex[stop]{Target system!general}\n\n\\myindex{Target system!specific}\n')

### save latex general
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-{kv}-general.tex')
        write_mode = 'w'
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-{kv}-general.tex', write_mode) as f:
            for item in v:
                f.write("%s" % item)

## Just specific, e.g. T1a, T1b, T2a, etc.
subsystems = ["target-computer","ui","electromechanical-subsystem","prototyping"]
lines = {}
edition = 'all'
lines[edition] = {}
tss = [] # specific versions
for k,v in versions.items(): # gather the specific version keys
    if 'ts-specific' in v:
        if v['ts-specific']:
            tss.append(k)

ts_covered = []
for k in tss:
    lines[edition][k] = []
    if not versions[k]["ts"] in ts_covered: # (before) first specific system of this ts-version
        # lead-in for entire section
        if ts_covered:
            supsup = '[^suppliers]'
        else:
            supsup = '<sup>1</sup>'
        lines[edition][k].append(f'''\n\n
# Specific {versions[k]["ts"]} target systems {{#specific-target-systems-{versions[k]["ts"]} id="specific-target-systems-{versions[k]["ts"]}" .online-only .ts .{versions[k]["ts"]} h="ef"}}
This section includes specific hardware instances of the general {versions[k]["ts"]} 
target system above ([General {versions[k]["ts"]} target system](#general-target-system-{versions[k]["ts"]})). 
All hardware is specified, including some suppliers we like.{supsup}''')
        ts_covered.append(versions[k]["ts"])
    ts = versions[k]["ts"]
    lines[edition][k].append(f'\n\n## {k}: a specific {versions[k]["ts"]} hardware system {{ .ts .{versions[k]["ts"]} }}')
    lines[edition][k].append(f'\n\n{versions[k]["description"]}\n\n')
    if 'image' in versions[k]:
        lines[edition][k].append(f'\n\n![Image of a {k} target system.]({versions[k]["image"]})')
    for s in subsystems:
        if s == 'target-computer':
            sname = 'Target computer'
        elif s == 'ui':
            sname = 'User interface (UI) subsystem'
        elif s == 'electromechanical-subsystem':
            sname = 'Electromechanical subsystem'
        elif s == 'prototyping':
            sname = 'Prototyping and testing hardware'
        lines[edition][k].append(f'\n\n### {sname}\n\n')
        sd = versions[k][s]
        if isinstance(sd,str):
            # this should only happen for target-computer
            if "specific" in versions[ts][s]:
                raise(Exception(f'Not implemented, write the code for top-level specifics!'))
                # for spk,spv in versions[ts][s]["specific"].items():
                #     if sd in spv:
            else:
                if sd == versions[ts][s]["hash"]:
                    # there must be only one target computer
                    # print its details
                    lines[edition][k].append(f'\n<details><summary>{versions[ts][s]["name"]}</summary>')
                    for tk,tv in versions[ts][s].items():
                        if tk == 'suppliers':
                            lines[edition][k].append(f'\n<details><summary>Suppliers<sup>1</sup></summary>')
                            for supplier_k,supplier_v in tv.items():
                                lines[edition][k].append(f'\n<div class="version-list-item"><a href="{supplier_v["url"]}">{supplier_k}</a></div>')
                            lines[edition][k].append(f'\n</details>')
                        elif tk == 'description':
                            lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(tv)}</div>')
                        elif tk != 'hash' and tk != 'name':
                            lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(tk)}: {capfirst(tv)}</div>')
                    lines[edition][k].append(f'\n</details>')
        else:
            for sk,sv in versions[ts][s].items():
                if "specific" in versions[ts][s][sk]:
                    spec = "specific"
                elif "unspecific" in versions[ts][s][sk]:
                    spec = "unspecific"
                else:
                    raise(Exception(f'Failed on {sk} because it needs either specific or unspecific dict'))
                for spk,spv in versions[ts][s][sk][spec].items():
                    if sk in versions[k][s]:
                        sksp = versions[k][s][sk]   # specified
                    else:
                        sksp = ''                   # not specified
                    if sksp == spv["hash"] or spec == "unspecific":
                        # title and emulation
                        em = ''
                        if 'emulation' in spv:
                            if (spv['emulation'] == 'yes'):
                                em = '<div class="tooltip"><div data-md-tooltip="has software emulation support"><span class="fa-solid fa-laptop-code"></span></div></div>'
                                # em = '<div class="tooltip"><div data-md-tooltip="has software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-check"></span></div></div>'
                            else:
                                em = ''
                                # em = '<div class="tooltip"><div data-md-tooltip="no software emulation support"><span class="fa-solid fa-laptop-code"></span><span class="fa-solid fa-xmark"></span></div></div>'
                        else:
                            em = ''
                        if "kind" in spv:
                            kind = f'{spv["kind"]}'
                        elif "kind" in versions[ts][s][sk]:
                            kind = f'{versions[ts][s][sk]["kind"]}'
                        elif "name" in versions[ts][s][sk]:
                            kind = f'{versions[ts][s][sk]["name"]}'
                        else:
                            kind = ''
                        if spec == "specific":
                            if len(kind) > 0:
                                name = f': {spv["name"]}'
                            else:
                                name = spv["name"]
                        else:
                            name = ''
                        lines[edition][k].append(f'\n<details><summary>{capfirst(kind)}{name} {em}</summary>')
                        # generic/unspecific
                        if spec == 'unspecific':
                            lines[edition][k].append(f'\n<div class="version-list-item">Generic—this part is generic and can be substituted with a similar part.</div>')
                            if 'name' in spv:
                                lines[edition][k].append(f'\n<div class="version-list-item">Name: {spv["name"]}</div>')
                        # description (want to have at the top and without colon)
                        if 'description' in spv and spec != 'unspecific': # specific description
                            lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(spv["description"])}</div>')
                        elif 'description' in versions[ts][s][sk]: # description from general
                            lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(versions[ts][s][sk]["description"])}</div>')
                        # quantity (it's not at the specifics level, have to get it from the general level)
                        q = versions[ts][s][sk]["quantity"]
                        lines[edition][k].append(f'\n<div class="version-list-item">Quantity: {capfirst(q)}</div>')
                        # details from general
                        for gk,gv in versions[ts][s][sk].items():
                            if isinstance(gv,str):
                                if gk != 'hash' and gk != 'name' and gk != 'description' and gk != 'emulation' and gk != 'kind' and gk != 'quantity':
                                    lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(gk)}: {capfirst(gv)}</div>')
                        # details from specific
                        for spdk,spdv in spv.items():
                            if not spdk == 'suppliers':
                                if spdk != 'hash' and spdk != 'name' and spdk != 'emulation' and (spdk != 'description' or spec == 'unspecific'):
                                    lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(spdk)}: {capfirst(spdv)}</div>')
                            else:
                                lines[edition][k].append(f'\n<details><summary>Suppliers<sup>1</sup></summary>')
                                for supplier_k,supplier_v in spdv.items():
                                    lines[edition][k].append(f'\n<div class="version-list-item"><a href="{supplier_v["url"]}">{supplier_k}</a></div>')
                                lines[edition][k].append(f'\n</details>')
                        lines[edition][k].append(f'\n</details>')
lines[edition][tss[-1]].append(f'\n\n[^suppliers]: We try to keep the suppliers lists updated. If you find a broken link, please contact us (the authors). Although we include what in our estimation are quality suppliers, use our recommendations at your own risk. If you would like to add a supplier to a list, please contact us.')

### save specific
iv = 0;
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-TS-specific.md')
        if iv == 0:
            write_mode = 'w'
        else:
            write_mode = 'a'
        iv = iv + 1
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-TS-specific.md', write_mode) as f:
            for item in v:
                f.write("%s" % item)

###################################################
###################################################
###################################################
###################################################
###################################################
###################################################
###################################################
###################################################
###################################################
###################################################
###################################################

# DS

## Just general D1, D2, etc., no specifics (e.g. no D1a, D1b, D2a)
lines = {}
edition = 'all'
lines[edition] = {}
dss = [] # specific versions
for k,v in versions.items(): # gather the specific version keys
    if 'ds-specific' in v:
        if v['ds-specific']:
            dss.append(k)

# markdown/html version
for k1,v1 in versions.items():
    if k1[0] == 'D' and k1 not in dss: # is it a ds version and is it not specific?
        lines[edition][k1] = ['\n\n```{=latex}\n\\myindex{Development system!specific} \n```\n\n```{=markdown}\n']
        # lead-in including header
        lines[edition][k1].append(f'''
## General {k1} development system {{#general-development-system-{k1} .ts .{k1} h="2b"}}\n
This section includes a definition of the general {k1} development system. 
For specific hardware instances, see 
[Specific {k1} development systems](#specific-development-systems-{k1}) below. 
The general {k1} development system diagram is shown in [@fig:system-diagram-0-development-system-{k1}].\n
![The general {k1} development system diagram.](figures/system-diagram-development-{k1}/system-diagram-development-{k1}){{#fig:system-diagram-0-development-system-{k1} .figure .standalone}}\n
We define the general {k1} development system as follows. It consists of a development computer, a virtual machine hypervisor, and the {versions[k1]["ide"]} IDE.\n
For specific instances of the {k1} development system, see 
[Specific {k1} development systems](#specific-development-systems-{k1}) below.''')

### save markdown/html general version
iv = 0;
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-DS-general.md')
        if iv == 0:
            write_mode = 'w'
        else:
            write_mode = 'a'
        iv = iv + 1
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-DS-general.md', write_mode) as f:
            for item in v:
                f.write("%s" % item)

# latex version (by book edition, straight to latex for explicit include)
for edition,vedition in bookdefs['editions'].items():
    for k1,v1 in versions.items():
        if k1[0] == 'D' and k1 not in dss: # is it a ds version and is it not specific?
            if vedition['v-ds'] == k1: # does this edition have this ds version?
                lines[edition] = {}
                lines[edition][k1] = []
                lines[edition][k1].append('\n\n')
                # lead-in including header
                lines[edition][k1].append(f'''
        \\section[][ds][]{{general-development-system{k1}}}{{dm}}{{General {k1} development system}}\n
        \\myindex[start]{{Development system!general}}\n
        This section includes a definition of the general {k1} development system. 
        For specific hardware instances, see \\cref{{uh}} below. 
        The general {k1} development system diagram is shown in \\cref{{fig:system-diagram-0-development-system-{k1}}}.\n\n
        \\begin{{center}}\n
        \\includestandalone{{figures/system-diagram-development-{k1}/system-diagram-development-{k1}}}\n
        \\figcaption[color=bw][nofloat]{{fig:system-diagram-0-development-system-{k1}}}{{The general {k1} development system diagram.}}\n
        \\end{{center}}\n\n
        We define the general {k1} development system as follows.
        It consists of a development computer, a virtual machine hypervisor, and the {versions[k1]["ide"]} IDE.\n
        For specific instances of the {k1} development system, see 
        \\cref{{uh}} below.\n\n
        \\myindex[stop]{{Development system!general}}\n\n
        \\myindex{{Development system!specific}}\n
        ''')

### save latex general
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-{kv}-general.tex')
        write_mode = 'w'
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-{kv}-general.tex', write_mode) as f:
            for item in v:
                f.write("%s" % item)

## Just specific, e.g. D1a, D1b, D2a, etc.
lines = {}
edition = 'all'
lines[edition] = {}
dss = [] # specific versions
for k,v in versions.items(): # gather the specific version keys
    if 'ds-specific' in v:
        if v['ds-specific']:
            dss.append(k)

ds_covered = []
for k in dss:
    lines[edition][k] = []
    if not versions[k]["ds"] in ds_covered: # (before) first specific system of this ds-version
        lines[edition][k].append(f'''\n\n
# Specific {versions[k]["ds"]} development systems {{#specific-development-systems-{versions[k]["ds"]} id="specific-development-systems-{versions[k]["ds"]}" .online-only .ds .{versions[k]["ds"]} h="uh"}}
This section includes specific software instances of the general {versions[k]["ds"]} 
development system above ([General {versions[k]["ds"]} development system](../general-development-system-{versions[k]["ds"]})). 
All software is specified.''')
        ds_covered.append(versions[k]["ds"])
    ds = versions[k]["ds"]
    lines[edition][k].append(f'\n\n## {k}: a specific {versions[k]["ds"]} software system {{ .ds .{versions[k]["ds"]} }}')
    lines[edition][k].append(f'\n\n{versions[k]["description"]}\n\n')
    if 'image' in versions[k]:
        lines[edition][k].append(f'\n\n![Image of a {k} development system.]({versions[k]["image"]})')
    sd = versions[k]
    lines[edition][k].append(f'\n<details class=empty><summary>For target system: {versions_raw["ds-specific"][k]["ts"]}</summary></details>\n')
    lines[edition][k].append(f'\n<details class=empty><summary>Setup instructions: [{versions_raw["ds-specific"][k]["setup"]}]({versions_raw["ds-specific"][k]["setup"]})</summary></details>\n')
    lines[edition][k].append(f'\n<details class=empty><summary>Distribution repository: [{versions_raw["ds-specific"][k]["url-dist"]}]({versions_raw["ds-specific"][k]["url-dist"]})</summary></details>\n')
    lines[edition][k].append(f'\n<details class=empty><summary>Source repository (restricted to instructors): [{versions_raw["ds-specific"][k]["url-source"]}]({versions_raw["ds-specific"][k]["url-source"]})</summary></details>\n')
    for sk,sv in versions[ds].items():
        if isinstance(sv,str):
            if sk != 'description':
                print(f'\n\nsv: {sv}\n\n')
                # this should only happen for IDE
                if "specific" in versions[ds]:
                    raise(Exception(f'Not implemented, write the code for top-level specifics!'))
                else:
                    # there must be only one IDE
                    # print its details
                    lines[edition][k].append(f'\n<details class="empty"><summary>IDE: {versions[ds]["ide"]} </summary></details>')
        elif sk not in ['children','parent','ide']:
            print(f'versions[ds][sk]: {versions[ds][sk]}')
            print(f'sk: {sk}')
            if "specific" in versions[ds][sk]:
                spec = "specific"
            elif "unspecific" in versions[ds][sk]:
                spec = "unspecific"
            else:
                raise(Exception(f'Failed on {sk} because it needs either specific or unspecific dict'))
            for spk,spv in versions[ds][sk][spec].items():
                if sk in versions[k]:
                    sksp = versions[k][sk]   # specified
                else:
                    sksp = ''                   # not specified
                if sksp == spv["hash"] or spec == "unspecific":
                    # title and emulation
                    em = ''
                    if "kind" in spv:
                        kind = f'{spv["kind"]}'
                    elif "kind" in versions[ds][sk]:
                        kind = f'{versions[ds][sk]["kind"]}'
                    elif "name" in versions[ds][sk]:
                        kind = f'{versions[ds][sk]["name"]}'
                    else:
                        kind = ''
                    if spec == "specific":
                        if len(kind) > 0:
                            name = f': {spv["name"]}'
                        else:
                            name = spv["name"]
                    else:
                        name = ''
                    lines[edition][k].append(f'\n<details class="empty"><summary>{capfirst(kind)}{name} {em}</summary>')
                    # generic/unspecific
                    if spec == 'unspecific':
                        lines[edition][k].append(f'\n<div class="version-list-item">Generic—this part is generic and can be substituted with a similar part.</div>')
                        if 'name' in spv:
                            lines[edition][k].append(f'\n<div class="version-list-item">Name: {spv["name"]}</div>')
                    # description (want to have at the top and without colon)
                    if 'description' in spv and spec != 'unspecific': # specific description
                        lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(spv["description"])}</div>')
                    elif 'description' in versions[ds][sk]: # description from general
                        lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(versions[ds][sk]["description"])}</div>')
                    # details from general
                    for gk,gv in versions[ds][sk].items():
                        if isinstance(gv,str):
                            if gk != 'hash' and gk != 'name' and gk != 'description' and gk != 'emulation' and gk != 'kind' and gk != 'quantity':
                                lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(gk)}: {capfirst(gv)}</div>')
                    # details from specific
                    for spdk,spdv in spv.items():
                        if not spdk == 'suppliers':
                            if spdk != 'hash' and spdk != 'name' and spdk != 'emulation' and (spdk != 'description' or spec == 'unspecific'):
                                lines[edition][k].append(f'\n<div class="version-list-item">{capfirst(spdk)}: {capfirst(spdv)}</div>')
                        else:
                            lines[edition][k].append(f'\n<details class="empty"><summary>Suppliers<sup>1</sup></summary>')
                            for supplier_k,supplier_v in spdv.items():
                                lines[edition][k].append(f'\n<div class="version-list-item"><a href="{supplier_v["url"]}">{supplier_k}</a></div>')
                            lines[edition][k].append(f'\n</details>')
                    lines[edition][k].append(f'\n</details>')

### save specific
iv = 0;
for edition,vedition in lines.items():
    for kv,v in vedition.items():
        print(f'edition: {edition}')
        print(f'kv: {kv}')
        print(f'writing file {f_list_base}{edition}-DS-specific.md')
        if iv == 0:
            write_mode = 'w'
        else:
            write_mode = 'a'
        iv = iv + 1
        print(f'write_mode: {write_mode}')
        with open(f'{f_list_base}{edition}-DS-specific.md', write_mode) as f:
            for item in v:
                f.write("%s" % item)