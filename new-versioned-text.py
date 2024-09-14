import os
import argparse

# Parse arguments 

parser = argparse.ArgumentParser(description='Get version info')
parser.add_argument(
	'hash', 
	type=str,
	help='a short hash like 8r identifying the document'
)
args = parser.parse_args()

# Create directory/ies

h = args.hash
ph = f'versioned/{h}'


if os.path.isdir(ph):
	populate = input(f'Directory {pv} exists, would you like to populate it with the default source.md file? y/n: ')
	if populate=='y':
		pop = True
	else:
		pop = False
		print(f'Nothing written to existing directory {ph}')
else:
	pop = True
	os.makedirs(ph)

# Write template.md and source.md files

fsource = ph+'/source.md'

if pop:
	# open templates
	with open("_template-blank.md") as f:
	    template_blank = f.read()
	# write source.md file
	if os.path.isfile(fsource):
		overwrite = input(f'File {fsource} exists, would you like to OVERWRITE it with the default source.md file? y/n: ')
		if populate=='y':
			with open(fsource, 'w') as f:
			    f.write(template_blank.format(hash=h))
			print(f'File {fsource} overwritten with the default source.md file.')
		else:
			print(f'Nothing written to {fsource}')
	else:
		with open(fsource, 'w') as f:
		    f.write(template_blank.format(hash=h))
		print(f'File {fsource} written with the default source.md file.')

