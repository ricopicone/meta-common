# meta-common

This repo is for sharing code across different book projects. Specifically, this repo shares code in `common` directory, which is a submodule of both the LaTeX (print book) and HTML (website) source repositories.

This repo manages files scattered throughout the `common` repo by using hard links.

Here are the key files and their descriptions:

- `links.json` This file defines the link paths. It has the structure:
  ```json
    {
        "files":{
            "../file": "file",
        },
        "directories":{
            "../directory": "directory",
        }
    }
  ```
- `link-here.py` This file creates hard links in the **repo** based on `links.json`. The source is from the parent (`common`) and the destination is in the repo. **Caution: This overwrites existing files in the `meta-common` repo.** The functionality essentially corresponds to a "check in" to the `meta-common` repo. However, once the files are linked, there is no need to run this script.
- `link-there.py` This file creates hard links in the **parent** based on `links.json`. The source is from the repo (`meta-common`) and the destination is in the parent (`common`). **Caution: This overwrites existing files in the `common` repo.** The functionality essentially corresponds to a "check out" of the `meta-common` repo.  However, once the files are linked, there is no need to run this script.

The rest of the files are the linked files.