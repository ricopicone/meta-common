--- Pandoc Lua filter to include other Markdown files
---
--- Usage: Use a special code block with class `include` to
--- include Markdown files. Each code line is treated as the
--- filename of a Markdown file, parsed as Markdown, and
--- included. Metadata from include files is discarded.
---
--- Example:
---
---     ``` {.include}
---     chapters/introduction.md
---     chapters/methods.md
---     chapters/results.md
---     chapters/discussion.md
---     ```

local List = require 'pandoc.List'

function CodeBlock(cb)
  if cb.classes:includes'include' then
    local blocks = List:new()
    for line in cb.text:gmatch('[^\n]+') do
      if line:sub(1,1)~='#' then
        local fh = io.open(line)
        blocks:extend(pandoc.read (fh:read '*a').blocks)
        fh:close()
      end
    end
    return blocks
  end
end