import yaml
import argparse
import glob
import click
import os

parser = argparse.ArgumentParser(description="Update the structure of the site.")
parser.add_argument('-y', '--yes', action='store_true', help='yes to all prompts.')
parser.add_argument('-a', '--audit', action='store_true', help='no interaction, only audit structure.')
parser.add_argument('-v', '--verbose', action='store_true', help='verbose output.')

args = parser.parse_args()

with open("_config.yml") as f:
    config = yaml.safe_load(f)

whitelist = []
for entry in config['structure_whitelist']:
    whitelist += glob.glob(entry, recursive=True)

## fix trailing comma in json and escaping escape \ characters
with open('book-0.json', 'r') as file:
    data = file.readlines()

for i,line in enumerate(data):
    data[i] = line.replace("\\","\\\\") # escape \ for valid json
    if line.startswith('}'):
        data[i-1] = data[i-1].rstrip(', \n')
        # break

with open('book-processed.json','w') as file:
    file.writelines(data)

with open('book-processed.json') as f:
    book = yaml.safe_load(f)
##

paths = {}

domain = "https://math.ricopic.one"

for id, data in book.items():
    if 'url' in data:
        url = data['url']
        if args.verbose:
            print(url)
        # if url.startswith(domain):
        path = id # slug
        if path:
            data['id'] = id
            if data['v-specific']=='ts':
                path = path + f'/{data["v-ts"]}'
                data['index_path'] = path + "/source.md"
                data['template_path'] = path + "/template.md"
            elif data['v-specific']=='ds':
                path = path + f'/{data["v-ds"].replace(".","-")}'
                data['index_path'] = path + "/source.md"
                data['template_path'] = path + "/template.md"
            elif data['type']=='exturl':
                data['index_path'] = path + "/index.md"
            else:
                data['index_path'] = path + "/.placeholder" # empty placeholder file so git recognizes dir structure
            paths[path] = data
        else:
            print(f'Warning: ID "{id}" listed url as homepage "{url}"')
        # else:
        # print(f'Invalid url "{url}" for ID "{id}"')

pages = glob.glob("**/*.markdown", recursive=True) + glob.glob("**/*.md", recursive=True) + glob.glob("**/.placeholder", recursive=True)

extra = []

for page in pages:
    page_path = page
    if page.startswith("_"):
        continue
    elif page_path.endswith("source.markdown"):
        page_path = page_path[:-14]
    elif page_path.endswith("source.md"):
        page_path = page_path[:-8]
    elif page_path.endswith(".placeholder"):
        page_path = page_path[:-12]
    if page_path.endswith("/"):
        page_path = page_path[:-1]
    if len(page_path) == 0:
        page_path = "."
    if page_path in paths:
        paths.pop(page_path)
        continue
    if page_path in whitelist:
        continue
    extra.append(page)

errors = len(extra) + len(paths)

if len(extra):
    print(" Extra Pages ".center(64, "="))
    for page in extra:
        print(page)
    print()

if len(paths):
    print(" Missing Pages ".center(64, "="))

if args.audit:
    for page in paths.values():
        print(os.path.dirname(page['index_path']))
    exit(errors)
else:
    with open("_template.md") as f:
        template = f.read()
    with open("_template-blank.md") as f:
        template_blank = f.read()
    with open("_template-placeholder.md") as f:
        placeholder = f.read()
    with open("_template-external-url.md") as f:
        external = f.read()

    for path, data in paths.items():
        index_path = data['index_path']
        if not args.yes:
            print("Missing page at: {}".format(data["index_path"]))
            if not click.confirm("Would you like to add it?", default=True):
                continue
        print("Creating page at: {}".format(os.path.dirname(index_path)))
        if not os.path.exists(os.path.dirname(index_path)):
            os.makedirs(os.path.dirname(index_path), exist_ok=True)
            with open(index_path, 'w') as f:
                if (data['v-specific']=='ts' or data['v-specific']=='ds'):
                    f.write(template_blank.format(path=path, **data))
                elif data['type']=='exturl':
                    f.write(external.format(path=path, **data))
                else:
                    f.write(placeholder.format(path=path, **data))
            if (data['v-specific']=='ts' or data['v-specific']=='ds'):
                with open(data['template_path'], 'w') as f:
                    f.write(template.format(path=path, **data))
    exit(0)
