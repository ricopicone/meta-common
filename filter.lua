-- load utilities
local system = require 'pandoc.system'
local string = require 'string'
pandoc.utils = require 'pandoc.utils'
pandoc.List = require 'pandoc.List'
local flatten = require('common.lua-modules.flatten')
local dump = require('common.lua-modules.dump') 
-- lunajson
local lunajson = require('lunajson')
-- local lunajson = require 'common.lua-modules.lunajson.lunajson'
-- local lunajson.encoder = require 'common.lua-modules.lunajson.lunajson.encoder'
-- local lunajson.decoder = require 'common.lua-modules.lunajson.lunajson.decoder'
-- local lunajson.sax = require 'common.lua-modules.lunajson.lunajson.sax'
local lfs = require('lfs')

-- functions 

--- reading book-defs.json and book-processed.json

---- functions

function split_filename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  if lfs.attributes(strFilename,"mode") == "directory" then
    local strPath = strFilename:gsub("[\\/]$","")
    return strPath.."\\","",""
  end
  strFilename = strFilename.."."
  return strFilename:match("^(.-)([^\\/]-%.([^\\/%.]-))%.?$")
end

local function get_keys(tbl)
  local keyset={}
  local n=0
  for k,v in pairs(tbl) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end

local function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end

local function get_parent(str)
    return str:match("(.*[/\\])")
end

local function read_value_from_file(file)
  -- will read only first non-empty line
  local value
  for line in file:lines() do
    if line ~= '' then
      value = tostring(line)
    end
  end
  return value
end

--------- Define a function to split a string into a table of strings based on a delimiter
local function split(s, delimiter)
  local result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match)
  end
  return result
end

---- read book-def.json
filter_dir = get_parent(script_path())
local open = io.open
local file_def = open(filter_dir .. "/book-defs.json", "rb")
if not file_def then return nil end
jsonString_def = file_def:read "*a"
file_def:close()
---- parse book-def.json with lunajson
book_def = lunajson.decode(jsonString_def)

-- print('\nkeys in book_def["editions"]: '..dump(get_keys(book_def['editions'])))

---- read book*.json for each def
book = {}
for k,ed in pairs(get_keys(book_def['editions'])) do
  -- print('ed: '..ed)
  -- print('k = '..k)
  -- print('jsonfile: '..book_def['editions'][k]['json-file-cleaned'])
  local jsonfile = filter_dir .. '../' .. book_def['editions'][ed]['json-file-cleaned']
  local file = open(jsonfile, "rb")
  if file ~= nil then
    jsonString = file:read "*a"
    file:close()
    -- print(jsonString)
    if jsonString ~= nil then
      -- print(jsonString)
      book[ed] = lunajson.decode(jsonString)
    end
  end
end

---- read video.json, which contains a dictionary of video links with keys corresponding to hashes, one dictionary for each book edition
local videofile = filter_dir .. 'book-json/videos.json'
local file = open(videofile, "rb")
if file~= nil then
  jsonString = file:read "*a"
  file:close()
  videos = lunajson.decode(jsonString)
else
  videos = {}
end

---- read apocrypha.json - the apocrypha are sections that don't appear in a book but we still need their versioning info for aggregating tocs on the website
local apocryphafile = filter_dir .. '../' .. book_def['apocrypha']
local file = open(apocryphafile, "rb")
-- print('apocryphafile: '..apocryphafile)
if file then
  jsonString = file:read "*a"
  file:close()
  -- print(jsonString)
  apocrypha = lunajson.decode(jsonString)
else
  apocrypha = {}
end

local function apocrypha_writer(apocrypha)
  local apocrypha_string = lunajson.encode(apocrypha)
  -- print(apocrypha_string)
  local file = io.open(apocryphafile,"w")
  io.output(file)
  io.write(apocrypha_string)
  io.close(file)
end

---- read versions-inherited-flat.json
local file_versions = open(filter_dir .. "/versions-inherited-flat.json", "rb")
if not file_versions then return nil end
jsonString = file_versions:read "*a"
file_versions:close()
---- parse versions-inherited-flat.json with lunajson
version_params = lunajson.decode(jsonString)
version_params_flat = flatten(version_params,0)

-- print('\nkeys in versions: '..dump(get_keys(version_params_flat)))

--- read tex-text-version-tmp.json
local file = open(filter_dir .. "/tex-text-version-tmp.json", "rb")
if file then
  text_version = tostring(read_value_from_file(file))
  file:close()
else
  error()
end

--- other functions

local function isempty(s)
  return s == nil or s == '' or next(s) == nil
end

local function starts_with(start, str)
  return str:sub(1, #start) == start
end

local function has_value(tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return true
      end
  end
  return false
end

local function has_key(tab, key)
  for index, value in ipairs(tab) do
      if index == key then
          return true
      end
  end
  return false
end

local inline_filter = {
  {Math = Math},
  {Code = Code},
  {RawInline = RawInline},
  {Cite = Cite},
  {Span = Span},
  {Link = Link}
}

local function inline_filter_function(el_inline)
  return pandoc.walk_inline(el_inline,inline_filter)
end

local interior_filter = {
  Math = function(el)
    return Math(el)
  end,
  RawInline = function(el)
    return RawInline(el)
  end,
  RawBlock = function(el)
    return RawBlock(el)
  end,
  Span = function(el)
    return Span(el)
  end,
  Link = function(el)
    return Link(el)
  end,
  Code = function(el)
    if FORMAT:match 'latex' or FORMAT:match 'beamer' then
      return coder_latex(el)
    else
      return Code(el)
    end
  end,
  CodeBlock = function(el)
    if FORMAT:match 'latex' or FORMAT:match 'beamer' then
      return coder_latex(el)
    else
      return CodeBlock(el)
    end
  end,
  Cite = function(el)
    local first_id = el.citations[1].id
    if FORMAT:match 'latex' or FORMAT:match 'beamer' then
      if starts_with('sec:',first_id) or starts_with('Sec:',first_id) or starts_with('eq:',first_id) or starts_with('Eq:',first_id) or starts_with('tbl:',first_id) or starts_with('Tbl:',first_id) or starts_with('fig:',first_id) or starts_with('Fig:',first_id) or starts_with('lst:',first_id) or starts_with('Lst:',first_id) then
        return pandoccrossrefer(el)
      else
        return Cite(el)
      end
    else
      return Cite(el)
    end
  end,
  OrderedList = function(el)
    return interior_ordered_lister(el)
  end,
  Table = function(el)
    Table(el)
  end,
  Figure = function(el)
    return Figure(el)
  end
  -- Image = function(el)
  --   print(el)
  --   print(el.classes)
  --   if el.caption then
  --     return el
  --   else
  --     el.caption = "cap"
  --     return imager(el)
  --   end
  -- end,
}

local function delimiter_dollar(text)
  -- print(text)
  text = string.gsub(text,"\\%(","$")
  text = string.gsub(text,"\\%)","$")
  return text
end

local function subsection_titler(el,h)
  local start_text
  if book[h]['v-ts'] == book['text-ts'] then
    start_text = "from"
  else
    start_text = "a version of section " .. 
      book[h]['subsec'] .. " of "
  end
  return pandoc.Div({
    pandoc.RawInline('html',
      start_text .. 
      " <a href='/'><em>" .. 
      book_def["book-short-name"] ..
      -- "</em></a>, p. " .. 
      -- book[h]['p']
      "</em></a>"
    )
  },{class="subsection-subtitle"})
end

local function book_appearances(h)
  local appearances = {}
  local hh = tostring(h)
  for k,v in pairs(book_def['editions']) do
    local kk = tostring(k)
    -- print('\nkeys in book: '..dump(get_keys(book)))
    -- print('checking if hash '..hh..' appears in book '..kk..'')
    if book[tostring(kk)] then
      -- print('checking if hash '..hh..' appears in book '..kk)
      if book[tostring(kk)][tostring(hh)] then
        -- print('hash '..hh..' appears in book '..kk..' with value '..dump(book[kk][hh])..'\n')
        appearances[tostring(kk)] = book[tostring(kk)][tostring(hh)]
      end
    end
  end
  return appearances
end

local function book_ap_s(h,key)
  local appearances = {}
  for k,v in pairs(book_def['editions']) do
    if book[k] then
      if book[k][h] then
        appearances[k] = book[k][h][key]
      end
    end
  end
  return appearances
end

local function book_ap_keys(h)
  local book_keys = {}
  i = 0
  for k,v in pairs(book_def['editions']) do
    -- print('k: '..k,'v: '..dump(v))
    -- print('book[k]: '..dump(book[k]))
    if book[k] then
      -- print('looking for hash '..h..'in ..')
      -- print('book[k]: '..dump(book[k]))
      if book[k][tostring(h)] then
        -- print('book[k][h]: '..dump(book[k][tostring(h)]))
        book_keys[i] = k
        i = i + 1
      end
    end
  end
  return book_keys
end

local function versioned(el)
  local ts = el.classes:includes('ts')
  local ds = el.classes:includes('ds')
  -- print('el has ts classes: '..dump(ts))
  -- print('el has ds classes: '..dump(ds))
  if ts and not ds then
    return 'ts'
  elseif not ts and ds then
    return 'ds'
  elseif ts and ds then
    return 'both'
  else
    return false
  end
end

local function versions_ts(el)
  local versions = {}
  local j = 1
  -- print('classes : '..dump(el.classes))
  for i,c in ipairs(el.classes) do
    if starts_with("T",c) then
      versions[j] = c
      j = j + 1
    end
  end
  return versions
end

local function versions_ds(el)
  local versions = {}
  local j = 1
  -- print('classes : '..dump(el.classes))
  for i,c in ipairs(el.classes) do
    if starts_with("D",c) then
      versions[j] = c
      j = j + 1
    end
  end
  return versions
end

local function versions_string(vs)
  local vs_string = ''
  for i,ver in ipairs(vs) do
    if i == 1 then
      sep = ''
    else
      sep = ','
    end
    vs_string = vs_string .. sep .. tostring(ver)
  end
  return vs_string
end

local function replace_key_dots(t)
  -- replaces dots . in keys
  local oldkeys = {}
  local tt = {}
  local knew
  for k,v in pairs(t) do
    oldkeys[tostring(k)] = tostring(k)
    local knew = tostring(k)
    local knew = string.gsub(knew,'%.','-')
    tt[knew] = tostring(t[tostring(k)])
  end
  -- for k,v in pairs(oldkeys) do
  --   t[tostring(k)] = nil
  -- end
  return tt
end

local function apocryphaer(el)
  h = el.attr.attributes['h']
  if not h then return 1 end
  -- each hash in apocrypha can have a subhash TXTY...DXDY..., a pseudo-book-edition
  local vs_ts = versions_ts(el)
  local vs_ds = versions_ds(el)
  local ver = versioned(el)
  local subhash = ''
  for i,v in ipairs(vs_ts) do
    subhash = subhash..v
  end
  for i,v in ipairs(vs_ds) do
    subhash = subhash..v
  end
  if subhash=='' then subhash = 'unversioned' end
  if not apocrypha[h] then
    apocrypha[h] = {}
  end
  if not apocrypha[h][subhash] then
    apocrypha[h][subhash] = {}
  end
  -- print('for hash '..h..' and subhash '..subhash)
  -- print('apocrypha before: '..dump(apocrypha))
  if not ver then ver = 'no' end
  apocrypha[h][subhash]['hash'] = h
  apocrypha[h][subhash]['title'] = pandoc.utils.stringify(el.content)
  apocrypha[h][subhash]['id'] = pandoc.utils.stringify(el.identifier)
  apocrypha[h][subhash]['v-specific'] = ver
  apocrypha[h][subhash]['v-ts'] = vs_ts[1] -- this misses multiple versions
  apocrypha[h][subhash]['v-ds'] = vs_ds[1] -- this misses multiple versions
  if el.level == 1 then
    if el.classes:includes('lab') then
      apocrypha[h][subhash]['type'] = 'lab'
    else
      apocrypha[h][subhash]['type'] = 'section'
    end
  elseif el.level == 2 then
    if el.classes:includes('resource') then
      apocrypha[h][subhash]['type'] = 'resource'
    else
      apocrypha[h][subhash]['type'] = 'subsection'
    end
  end
  -- print('apocrypha after: '..dump(apocrypha))
  apocrypha_writer(apocrypha) -- write to file
  return 0
end

function getTableSize(t)
  local count = 0
  for _, __ in pairs(t) do
      count = count + 1
  end
  return count
end

local function headerer_html(el)
  -- 1. add book appearances to attributes
  local h = el.attr.attributes['h']
  local content = pandoc.utils.stringify(el.content)
  local at
  if not h then
    print('Warning: no hash h for section: ' .. content)
    at = {}
  else
    local books = book_ap_keys(h)
    -- print('book appearance keys - '..dump(books))
    if (getTableSize(books) > 0) then
      -- put it in book attributes
      local book_aps = book_appearances(h)
      local at = flatten(book_aps,0)
      -- print('at: ' .. dump(at))
      -- local at = replace_key_dots(at)
      -- print('at: ' .. dump(at))
      if at then
        for k,v in pairs(at) do
          el.attributes[k] = v
        end
      end
      -- see if it also belongs in the apocrypha (shares hash with an element in the book but with different versioning)
      local ver = versioned(el)
      local vs_ts = versions_ts(el)
      local vs_ds = versions_ds(el)
      for i,b in pairs(book_aps) do
        local vspecific = b['v-specific']
        -- print('vspecific: '..vspecific)
        -- print('ver: '..ver)
        if not ver == vspecific then
          -- print('add to apocrypha!')
          apocryphaer(el)
        else
          local bts = b['v-ts']
          local bds = b['v-ds']
          -- print('vs_ts: '..dump(vs_ts),'vs_ds: '..dump(vs_ds),'bts: '..bts,'bds: '..bds)
          if not has_value(vs_ts,bts) and not has_value(vs_ds,bds) then
            -- print('add to apocrypha!')
            apocryphaer(el)
          else
            -- print('this element is cannon')
          end
        end
      end
    else -- add it to the apocrypha!
      -- print('add to apocrypha!')
      apocryphaer(el)
    end
  end
  -- 2. add wherein div
  local wherein = el.attr.attributes['wherein']
  if wherein then 
    wherein = pandoc.read(wherein,'markdown').blocks[1]
    -- print('wherein: '..dump(wherein))
    if wherein then
      wherein = pandoc.walk_block(wherein,{Span=Span,Code=Code})
      wherein = pandoc.utils.stringify(wherein)
      whereindiv = pandoc.Div({pandoc.RawInline('html',wherein)},{class='wherein'..el.level})
      r = {el,whereindiv}
    else
      r = {el}
    end
  else
    r = {el}
  end
  -- 3. add versioned div
  local v = versioned(el)
  local vs_ts = versions_ts(el)
  local vs_ds = versions_ds(el)
  if v == false then
    -- return r
  elseif v == 'ts' then
    r[#r+1] = pandoc.Div({
      pandoc.Div({pandoc.RawInline('html','TX')},{class='ts-tag'})
    },{class='vtag-container'})
    -- return r
  elseif v == 'ds' then
    r[#r+1] = pandoc.Div({
      pandoc.Div({pandoc.RawInline('html','DX')},{class='ds-tag'})
    },{class='vtag-container'})
    -- return r
  elseif v == 'both' then
    r[#r+1] = pandoc.Div({
      pandoc.Div({pandoc.RawInline('html','TX')},{class='ts-tag'}),
      pandoc.Div({pandoc.RawInline('html','DX')},{class='ds-tag'})
    },{class='vtag-container'})
    -- return r
  else
    error()
  end
  -- 4. add video container div
  if videos[text_version] then
    local playlist = videos[text_version]['playlist']
    local index = videos[text_version]['indices'][h]
    -- if playlist and index then
    -- r[#r+1] = pandoc.Div({pandoc.RawInline('html','<iframe class="hiddeniframe" src="https://www.youtube.com/embed?listType=playlist&list=PL'..playlist..'&index='..index..'" frameborder="0" allowfullscreen="" allow="encrypted-media"></iframe>')},{class='videopdf-container hiddenvideopdf-container'})
    local novideo = false
    if not playlist or not index then
      novideo = true
    end
    local button
    if novideo then
      button = ''
    else
      button = '<button class="button1" onclick="toggle_video_visibility(this)"> <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 29"><defs><style>.a{fill:#fff;}</style></defs><rect width="36" height="29" rx="2.19"/><polygon class="a" points="24.17 14.5 14.17 8.73 14.17 20.27 24.17 14.5"/><rect class="a" x="17" y="1" width="2" height="4"/><rect class="a" x="20" y="1" width="2" height="4"/><rect class="a" x="23" y="1" width="2" height="4"/><rect class="a" x="26" y="1" width="2" height="4"/><rect class="a" x="29" y="1" width="2" height="4"/><rect class="a" x="32" y="1" width="2" height="4"/><rect class="a" x="14" y="1" width="2" height="4"/><rect class="a" x="11" y="1" width="2" height="4"/><rect class="a" x="8" y="1" width="2" height="4"/><rect class="a" x="5" y="1" width="2" height="4"/><rect class="a" x="2" y="1" width="2" height="4"/><rect class="a" x="17" y="24" width="2" height="4"/><rect class="a" x="20" y="24" width="2" height="4"/><rect class="a" x="23" y="24" width="2" height="4"/><rect class="a" x="26" y="24" width="2" height="4"/><rect class="a" x="29" y="24" width="2" height="4"/><rect class="a" x="32" y="24" width="2" height="4"/><rect class="a" x="14" y="24" width="2" height="4"/><rect class="a" x="11" y="24" width="2" height="4"/><rect class="a" x="8" y="24" width="2" height="4"/><rect class="a" x="5" y="24" width="2" height="4"/><rect class="a" x="2" y="24" width="2" height="4"/></svg> <span class="video-hover-text">Watch Lecture Video</span> </button>'
    end
    local buttons = ''
    if type(index) == 'table' then
      for i, idx in ipairs(index) do
        buttons = buttons .. button
      end
    else
      buttons = button
    end
    r[#r+1] = pandoc.Div({pandoc.RawInline('html',buttons)},{class='videopdf-container hiddenvideopdf-container'})
    r[#r].attr.attributes['data-embedplaylist'] = playlist
    local count = 0
    if type(index) == 'table' then
      for i, idx in ipairs(index) do
        r[#r].attr.attributes['data-embedindex'..i] = idx
        count = count + 1
      end
      r[#r].attr.attributes['data-embedcount'] = count
    else
      r[#r].attr.attributes['data-embedindex1'] = index
      r[#r].attr.attributes['data-embedcount'] = 1
    end
  end
  -- end
  -- 5. add a real-section class (this simplifies the css and js)
  r[1].classes:insert('real-section')
  return r
end

local function headerer_latex(el)
  local l = el.level
  local section_cmd
  local content
  local v = versioned(el)
  -- print('v: '..tostring(v))
  local sec_tex
  local starred
  if l == 1 or l == 2 or l == 3 then
    if el.content then 
      content = pandoc.walk_block(el.content,inline_filter)
      local content_doc = pandoc.Pandoc(content)
      content = pandoc.write(content_doc,'latex')
    else
      content = '' 
    end
    if el.classes:includes('unnumbered') then
      if l == 1 then
        error('A top-level section cannot be unnumbered.\n')
      elseif l == 2 then
        sec_tex = "\\oldsubsection*{"..content.."}"
      elseif l == 3 then
        sec_tex = "\\subsubsection*{"..content.."}"
      end
    else -- numbered sections
      if l == 3 then
        local shortid = el.attr.attributes['shortid']
        if not shortid then shortid = '' end
        sec_tex = "\\subsubsection{" .. 
          content .. 
          "}\n\\label{" ..
          shortid ..
          "}"
        return {
          pandoc.RawBlock('latex', sec_tex)
        }
      elseif l == 1 then
        if el.classes:includes('lab') then
          section_cmd = "\\lab[]["
        else
          section_cmd = "\\section[]["
        end
      else -- l == 2
        if el.classes:includes('resource') then
          if el.classes:includes('digital') then
            section_cmd = "\\resource[][digital]["
          else
            section_cmd = "\\resource[][]["
          end
        else
          section_cmd = "\\subsection[]["
        end
      end
      if not v then v = '' end
      local hash = el.attr.attributes['h']
      local hash_alt = el.attr.attributes['hash']
      if not hash then if not hash_alt then hash = '' else hash=hash_alt end end
      local shortid = el.attr.attributes['shortid']
      if not shortid then shortid = '' end
      local wherein = el.attr.attributes['wherein']
      if wherein then 
        wherein = pandoc.read(wherein,'markdown').blocks[1]
        -- print('wherein: '..dump(wherein))
        if wherein then
          wherein = pandoc.walk_block(wherein,inline_filter)
          local wherein_doc = pandoc.Pandoc(wherein)
          wherein = pandoc.write(wherein_doc,'latex')
        else
          wherein = ''
        end
      else
        wherein = '' 
      end
      local labbackground
      if el.classes:includes('labbackground') then
        labbackgroundarg = "[labbackground]"
      else
        labbackgroundarg = ''
      end
      sec_tex = section_cmd .. 
        v .. 
        "][".. 
        wherein ..
        "]".. 
        labbackgroundarg ..
        "{" .. 
        shortid .. 
        "}{" .. 
        hash .. 
        "}{" .. 
        content .. 
        "}"
    end
    -- print('section header: '..sec_tex)
    return {
      pandoc.RawBlock('latex', sec_tex)
    }
  else
    return el
  end
end

local function key_text_html(el)
  local text
  if el.classes:includes('folder') then
    text = '<span class="material-icons">folder</span>'
  elseif el.classes:includes('windows') then
    text = '<span class="key"><i class="fa-brands fa-windows"></i></span>'
  elseif el.classes:includes('enter') then
    text = '<span class="key">ENTR</span>'
  elseif el.classes:includes('return') then
    text = '<span class="key"><span class="material-icons">keyboard_return</span></span>'
  elseif el.classes:includes('leftarrow') or  el.classes:includes('left') or el.classes:includes('backspace') then
    text = '<span class="key"><span class="material-icons">keyboard_backspace</span></span>'
  elseif el.classes:includes('uparrow') or el.classes:includes('up') then
    text = '<span class="key">UP</span>'
  elseif el.classes:includes('downarrow') or el.classes:includes('down') then
    text = '<span class="key">DWN</span>'
  elseif el.classes:includes('play') then
    text = '<span class="key"><span class="material-icons">play_arrow</span></span>'
  else
    text = "<span class='key'>"..pandoc.utils.stringify(el.content).."</span>"
  end
  return text
end

local function keyer(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local text
    if el.content then
      text = pandoc.walk_block(el.content,inline_filter)
      local text_doc = pandoc.Pandoc(text)
      text = pandoc.write(text_doc,'latex')
      text = pandoc.utils.stringify(text)
    else
      text = ''
    end
    if el.classes:includes('folder') then
      text = '\\faFolder'
    elseif el.classes:includes('windows') then
      text = '\\faWindows'
    elseif el.classes:includes('enter') then
      text = 'ENTR' -- keypad
    elseif el.classes:includes('return') then
      text = '\\return' -- keyboard
    elseif el.classes:includes('leftarrow') or  el.classes:includes('left') or el.classes:includes('backspace') then
      text = '$\\leftarrow$'
    elseif el.classes:includes('uparrow') or el.classes:includes('up') then
      text = 'UP'
    elseif el.classes:includes('downarrow') or el.classes:includes('down') then
      text = 'DWN'
    elseif el.classes:includes('play') then
      text = '\\faPlay'
    end
    return pandoc.RawInline('latex', "\\mykeys{" .. text .. "}")
  elseif FORMAT:match 'html' then
    -- Separate at + signs (if any are detected)
    local keys
    local nokeys = false
    if isempty(el.content) then
      keys = {}
      nokeys = true
    else
      keys = pandoc.utils.stringify(el.content)
      keys = split(keys, '+')
    end
    if not nokeys then
      -- Loop through each part
      for i, key in ipairs(keys) do
        -- If it's the first part, don't add a plus sign
        if i == 1 then
          text = "<span class='key'>" .. key .. "</span>"
        else
          text = text .. " + " .. "<span class='key'>" .. key .. "</span>"
        end
      end
      return pandoc.RawInline('html', text)
    else
      return pandoc.RawInline('html', key_text_html(el))
    end
  else
    return el 
  end
end

local function citer(el)
  local citeraw
  local citesuffix
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    citeraw = "\\autocite["
    for i, c in ipairs(el.citations) do
      citekey = c.id
      citesuffix = pandoc.utils.stringify(c.suffix)
      citesuffix = string.gsub(citesuffix,',','',1) -- strip first comma
      if not citesuffix then citesuffix = '' end
      if i==1 then
        citeraw = citeraw .. citesuffix ..']{' .. citekey
      else
        citeraw = citeraw .. "," .. citekey
      end
    end
    citeraw = citeraw .. "}"
    return pandoc.RawInline('latex', citeraw)
  else
    return el 
  end
end

-- Define a function that returns a value from a book json file given the edition, hash, and key
local function book_value(ed,h,key)
  if book[ed] then
    if book[ed][h] then
      return book[ed][h][key]
    end
  end
  return ""
end

-- Define a function that returns a formatted hash from its type from a book json file given the edition and hash
local function formatted_hashref(ed,h,cap)
  local type = book_value(ed,h,'type')
  local hashref
  if type == 'chapter' then
    hashref = 'chapter ' .. book_value(ed,h,'ch')
  elseif type == 'appendix' then
    hashref = 'appendix ' .. book_value(ed,h,'ch')
  elseif type == 'section' then
    hashref = 'section ' .. book_value(ed,h,'sec')
  elseif type == 'subsection' then
    hashref = 'subsection ' .. book_value(ed,h,'subsec')
  elseif type == 'lab' then
    hashref = 'lab ' .. book_value(ed,h,'ch')
  elseif type == 'resource' then
    hashref = 'resource ' .. book_value(ed,h,'sec')
  elseif type == 'example' then
    hashref = 'example'
  elseif type == 'figure' then
    hashref = 'figure ' .. book_value(ed,h,'number')
  elseif type == 'table' then
    hashref = 'table ' .. book_value(ed,h,'number')
  elseif type == 'problem' then
    hashref = 'problem ' .. book_value(ed,h,'problem-num')
  elseif type == 'labproblem' then
    hashref = 'problem ' .. book_value(ed,h,'problem-num')
  elseif type == 'listing' then
    hashref = 'listing ' .. book_value(ed,h,'listing-num')
  else
    hashref = ''
  end
  if cap then -- capitalize the first letter
    hashref = hashref:sub(1,1):upper()..hashref:sub(2)
  end
  return hashref
end

-- Define a function to split a string into a table of strings based on a delimiter
local function split(s, delimiter)
  local result = {}
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match)
  end
  return result
end

-- Define a function to handle the case where a hashref is a list of hashes
local function multihashref(el, cap)
  -- Really, a more involved function should be written to elegantly handle the case where the hashes are of different types
  -- If they're the same type, we should state the type once and then list the numbers
  -- We would also want to handle multiple with dashes from first -- to last
  -- Finally, we'd also want to handle the case of two connected by "and" and the case of three or more connected by commas and "and"
  -- For now, we'll just list them all
  local content = el.content
  local text = pandoc.utils.stringify(content)
  local hashes = split(text, ',')
  if #hashes == 1 then
    if starts_with('fig:',hashes[1]) or starts_with('Fig:',hashes[1]) or starts_with('tbl:',hashes[1]) or starts_with('Tbl:',hashes[1]) or starts_with('lst:',hashes[1]) or starts_with('Lst:',hashes[1]) then
      return pandoc.Span(formatted_hashref("0",hashes[1],cap))
    else
      return pandoc.Link(formatted_hashref("0",hashes[1],cap),"/" .. hashes[1])
    end
  else
    local formatted_hashes = {}
    local j = 1
    for i, hash in ipairs(hashes) do -- comma separated list of hashes
      if i == 1 and cap then
        if starts_with('fig:',hash) or starts_with('Fig:',hash) or starts_with('tbl:',hash) or starts_with('Tbl:',hash) or starts_with('lst:',hashes[1]) or starts_with('Lst:',hashes[1]) then
          formatted_hashes[i] = pandoc.Span(formatted_hashref("0",hash,cap))
        else
          formatted_hashes[i] = pandoc.Link(formatted_hashref("0",hash,cap),"/" .. hash)
        end
      else
        if starts_with('fig:',hash) or starts_with('Fig:',hash) or starts_with('tbl:',hash) or starts_with('Tbl:',hash) or starts_with('lst:',hashes[1]) or starts_with('Lst:',hashes[1]) then
          formatted_hashes[j] = pandoc.Span(formatted_hashref("0",hash,false))
        else
          formatted_hashes[j] = pandoc.Link(formatted_hashref("0",hash,false),"/" .. hash)
        end
      end
      j = j + 1
      if i < #hashes then
        formatted_hashes[j] = pandoc.Str(", ")
        j = j + 1
      end
    end
    print(formatted_hashes)
    return pandoc.Span(formatted_hashes)
  end
end

local function hashrefer(el)
  local content = el.content
  local text = pandoc.utils.stringify(content)
  local cap = false
  if el.classes:includes('Hashref') then
    print('Hashref')
    cap = true
  end
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if cap then
      return pandoc.RawInline('latex', "\\Cref{" .. text .. "}")
    else
      return pandoc.RawInline('latex', "\\cref{" .. text .. "}")
    end
  else
    return multihashref(el, cap)
  end
end

local function linerefer(el)
  local content = el.content
  local text = pandoc.utils.stringify(content)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return pandoc.RawInline('latex', "\\lref{" .. text .. "}")
  else
    return pandoc.Link(text,"/" .. text)
  end
end

local function labeler(el)
  local content = el.content
  local text = pandoc.utils.stringify(content)
  local component = el.classes:includes('component')
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if component then
      return pandoc.RawInline('latex', "\\label[componentitem]{" .. text .. "}")
    else
      return pandoc.RawInline('latex', "\\label{" .. text .. "}")
    end
  else
    -- return pandoc.Link(text,"/" .. text)
    return el
  end
end

local function plainciter(el)
  local content = el.content
  if not content then content = '' end
  local text = pandoc.utils.stringify(content)
  if not text then text = '' end
  local pre = el.attr.attributes['pre']
  local post = el.attr.attributes['post']
  local postpost = el.attr.attributes['postpost'] -- after the parentheses
  if not pre then pre = '' end
  if not post then post = '' end
  if postpost then
    postpost = ", "..postpost
  else 
    postpost = ''
  end
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return pandoc.RawInline(
      'latex', "{\\textcite[{"..pre.."}][{"..post.."}]{" .. text .. "}"..postpost.."}")
  else
    -- return pandoc.Cite({},{content})
    return el
  end
end

function pandoccrossrefer(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local citeid
    local citeids = ''
    for index, value in ipairs(el.citations) do
      citeid = value.id 
      citeids = citeids..citeid
      if not (index == #el.citations) then
        citeids = citeids..','
      end
    end
    local cref 
    local citeids_upper = citeids:sub(1,1):upper()..citeids:sub(2)
    if citeids_upper == citeids then
      cref = "\\Cref{"
    else
      cref = "\\cref{"
    end
    local citeids_lower = citeids:sub(1,1):lower()..citeids:sub(2)
    return pandoc.RawInline('latex', cref .. citeids_lower .. "}")
  else
    -- In html, we'll just return the text looked up from the book json. Use type then number
    local text = ''
    for index, value in ipairs(el.citations) do
      citeid = value.id
      if index == 1 then
        text = formatted_hashref("0",citeid,true)
      else
        text = text..', '..formatted_hashref("0",citeid,true)
      end
    end
    return pandoc.Span(text)
  end
end

local function infoboxer(el)
  -- local text
  local el_walked
  el_walked = pandoc.walk_block(el,interior_filter)
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'latex')
  -- if text then
  --   text = pandoc.walk_block(content[1],{Span=Span,Code=Code})
  --   text = pandoc.utils.stringify(text)
  -- else
  --   text = ""
  -- end
  local title = el.attr.attributes['title']
  local identifier = el.identifier
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if title == nil then
      title = "{}"
    else
      title = "{" .. title .. "}"
    end
    if identifier == nil then
      identifier = ""
    else
      identifier = "[label=" .. el.identifier .. "]"
    end
    return pandoc.RawBlock('latex', "\\begin{infobox}"  .. identifier .. title .. "\n" .. content .. "\n\\end{infobox}")
  elseif FORMAT:match 'html' then
    if title == nil then
      title = ""
    end
    if identifier == nil then
      identifier = ""
    else
      identifier = el.identifier
    end
    return pandoc.Div({
        pandoc.Div({
          pandoc.Header(3,title,{class="mdl-card__title-text"})
        },{class="mdl-card__title"}),
        pandoc.Div(el.content,{class="mdl-card__supporting-text"})
    },{class="infobox mdl-card mdl-shadow--2dp through mdl-shadow--4dp"})
    -- el.classes:insert('mdc-card')
    -- return el
  else
    return el 
  end
end

local function theoremer(el)
  -- local text
  local el_walked
  el_walked = pandoc.walk_block(el,interior_filter)
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'latex')
  local title = el.attr.attributes['title']
  local identifier = el.identifier
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if title == nil then
      title = ""
    end
    if identifier == nil then
      identifier = ""
    end
    local type
    if el.classes:includes('theorem') then
      type = 'theorem'
    elseif el.classes:includes('definition') then
      type = 'definition'
    elseif el.classes:includes('lemma') then
      type = 'lemma'
    elseif el.classes:includes('corollary') then
      type = 'corollary'
    elseif el.classes:includes('proposition') then
      type = 'proposition'
    end
    return pandoc.RawBlock('latex', "\\begin{"..type.."}{"..title.."}{"..identifier.."}\n"..content.."\n\\end{"..type.."}\n")
  elseif FORMAT:match 'html' then
    if title == nil then
      title = ""
    end
    if identifier == nil then
      identifier = ""
    else
      identifier = el.identifier
    end
    return pandoc.Div({
        pandoc.Div({
          pandoc.Header(3,title,{class="mdl-card__title-text"})
        },{class="mdl-card__title"}),
        pandoc.Div(el.content,{class="mdl-card__supporting-text"})
    },{class="theorem mdl-card mdl-shadow--2dp through mdl-shadow--4dp"})
    -- el.classes:insert('mdc-card')
    -- return el
  else
    return el 
  end
end

local function definitioner(el)
  -- local text
  local el_walked
  el_walked = pandoc.walk_block(el,interior_filter)
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'latex')
  local title = el.attr.attributes['title']
  local identifier = el.identifier
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if title == nil then
      title = ""
    end
    if identifier == nil then
      identifier = ""
    end
    return pandoc.RawBlock('latex', "\\begin{definition}{"..title.."}{"..identifier.."}\n"..content.."\n\\end{definition}\n")
  elseif FORMAT:match 'html' then
    if title == nil then
      title = "Definition"
    end
    if identifier == nil then
      identifier = ""
    else
      identifier = el.identifier
    end
    return pandoc.Div({
        pandoc.Div({
          pandoc.Header(3,title,{class="mdl-card__title-text"})
        },{class="mdl-card__title"}),
        pandoc.Div(el.content,{class="mdl-card__supporting-text"})
    },{class="definition mdl-card mdl-shadow--2dp through mdl-shadow--4dp"})
    -- el.classes:insert('mdc-card')
    -- return el
  else
    return el 
  end
end

local function section_diver_html(el)
  return el
end

local function section_diver_latex(el)
  local h = el.attr.attributes['h']
  local h_alt = el.attr.attributes['hash']
  if not h then if not h_alt then h = '' else h=h_alt end end
  if not h then 
    -- print(dump(el))
    if el.classes:includes('level1') or el.classes:includes('level2') then
      -- print(dump(el))
      error('The section/subsection/whatever must have a hash!\n')
    else
      h = '(no hash)'
    end
  end
  -- local book_ap_keys = book_appearances(h)
  -- if not book_ap_keys then return {} end -- no editions contain this sub/section's hash -- this test doesn't work because it's circular reasoning!
  -- if not book_ap_keys[text_version] then return {} end -- this text edition lacks this section's hash -- this test doesn't work because it's circular reasoning!
  local text_ts = book_def['editions'][text_version]['v-ts']
  local text_ds = book_def['editions'][text_version]['v-ds']
  -- figure out this sub/section's versioned status in source
  local v = versioned(el)
  local vs_ts = versions_ts(el)
  local vs_ds = versions_ds(el)
  local reason = 'NO REASON'
  local exclude = false -- exclude section?
  local header_only = false -- include only header?
  -- print('text is '..text_ts..' and '..text_ds)
  -- print('element has '..dump(vs_ts)..' and '..dump(vs_ds))
  if el.classes:includes('online-only') or (el.classes:includes('resource') and el.classes:includes('digital')) then
    header_only = true -- explicitly online-only
  end
  if v == false then
    reason = 'because it is non-versioned'
  elseif v == 'ts' then
    if has_value(vs_ts,text_ts) then
      reason = 'because it has version '..text_ts
    else
      exclude = true
    end
  elseif v == 'ds' then
    if has_value(vs_ds,text_ds) then
      reason = 'because it has version '..text_ds
    else
      exclude = true
    end
  elseif v == 'both' then
    if has_value(vs_ts,text_ts) and has_value(vs_ds,text_ds) then
      reason = 'because it has versions '..text_ts..' and '..text_ds
    else
      exclude = true
    end
  end
  -- print('v: '..tostring(v))
  local dont_include_msg = 'excluding section with hash '..h..' - non-matching version(s)'
  local include_msg = 'including section with hash '..h..' '..reason
  if exclude then
    -- print(dont_include_msg)
    return {}
  else
    -- print(include_msg)
    if header_only then
      -- print('including header only of section with hash '..h..' because it is explicitly online-only')
      return {el.content[1],pandoc.RawInline('latex','This section is available on the companion website at \\myurlinline*{https://engineering-computing.ricopic.one/'..h..'}{'..h..'}.')}
    else
      return el
    end
  end
end

local function myurler_html(el)
  -- return {pandoc.LineBreak(),el,pandoc.LineBreak()}
  -- don't need line breaks when we use display block instead
  el.attr.attributes['target'] = '_blank'
  return el
end

local function myurler(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local url = pandoc.utils.stringify(el.target)
    local hash = el.attr.attributes['h']
    local hash_alt = el.attr.attributes['hash']
    if not hash then if not hash_alt then hash = '' else hash=hash_alt end end
    local punctuation = el.attr.attributes['punctuation']
    if not punctuation then punctuation = '' end
    local safety = el.attr.attributes['safe']
    if not safety then safety = '' end
    local noid
    if el.classes:includes('noid') or el.classes:includes('star') then
      noid = '*' -- starred version
    else
      noid = ''
    end
    if not el.classes:includes('inline') then 
      if el.classes:includes('bottom') then
      return pandoc.RawInline('latex', "\\myurlbottom"..noid.."["..punctuation.."]["..safety.."]{" .. url .. "}{" .. hash .. "}")  
      else
      return pandoc.RawInline('latex', "\\myurl"..noid.."["..punctuation.."]["..safety.."]{" .. url .. "}{" .. hash .. "}")        
      end
    else
      return pandoc.RawInline('latex', "\\myurlinline"..noid.."{" .. url .. "}{" .. hash .. "}")
    end
  elseif FORMAT:match 'html' then
    if isempty(el.content) then
      el.content = {pandoc.Str(el.target)}
    end
    return myurler_html(el)
  else
    return el
  end
end

local function pather(el) -- handles Span and Code inputs
  local path
  if el.t=='Code' then
    path = pandoc.utils.stringify(el.text)
  else
    path = pandoc.utils.stringify(el.content)
  end
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if path==nil then
      return el
    else
      return pandoc.RawInline('latex', "\\path{" .. path .. "}")
    end
  else
    return el
  end
end

local function menuer_html(el)
  local content = el.content
  content = pandoc.utils.stringify(content)
  local items = {}
  local i = 0
  for item in string.gmatch(content, '([^,]+)') do
    i = i + 1
    local image = ''
    if string.match(item,'eresume') then
      image = '<img src="/assets/figures/eclipse-icons/resume_co.svg" alt="eresume" class="menu-icon">'
    elseif string.match(item,'estepover') then
      image = '<img src="/assets/figures/eclipse-icons/stepover_co.svg" alt="estepover" class="menu-icon">'
    elseif string.match(item,'estepinto') then
      image = '<img src="/assets/figures/eclipse-icons/stepinto_co.svg" alt="estepinto" class="menu-icon">'
    elseif string.match(item,'estepreturn') then
      image = '<img src="/assets/figures/eclipse-icons/stepreturn_co.svg" alt="estepreturn" class="menu-icon">'
    elseif string.match(item,'eterminate') then
      image = '<img src="/assets/figures/eclipse-icons/terminate_co.svg" alt="eterminate" class="menu-icon">'
    elseif string.match(item,'enrc') then
      image = '<img src="/assets/figures/eclipse-icons/new_con.svg" alt="enrc" class="menu-icon">'
    elseif string.match(item,'mouser') then
      image = '<img src="/assets/figures/mouse-right.svg" alt="mouser" class="menu-icon" style="width: 1em;">'
    elseif string.match(item,'mousel') then
      image = '<img src="/assets/figures/mouse-left.svg" alt="mousel" class="menu-icon" style="width: 1em;">'
    else
      image = item -- just text
    end
    -- items[i] = pandoc.Span(item,{class='menu-item'})
    items[i] = pandoc.Span(pandoc.RawInline('html',image),{class='menu-item'})
  end
  items[1].classes = {'menu-item','menu-item-first'}
  items[i].classes = {'menu-item','menu-item-last'}
  return items
end

local function menuer_latex(el)
  local content = el.content
  content = pandoc.utils.stringify(content)
  content = string.gsub(content,'mouser','\\mouser')
  content = string.gsub(content,'mousel','\\mousel')
  content = string.gsub(content,'enrc','\\enrc')
  content = string.gsub(content,'eresume','\\eresume')
  content = string.gsub(content,'estepover','\\estepover')
  content = string.gsub(content,'estepinto','\\estepinto')
  content = string.gsub(content,'estepreturn','\\estepreturn')
  content = string.gsub(content,'eterminate','\\eterminate')
  local menu = pandoc.RawInline('latex',
    '\\menu{'..content..'}'
  )
  return menu
end

function imager(el)
  local i
  local e
  local options
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    -- width
    local width = el.attr.attributes['figwidth']
    if width==nil then
      width = ""
    else
      width = pandoc.utils.stringify(width)
      width = "width=" .. width
    end
    -- graphics command
    local graphics_command
    if el.classes:includes('standalone') then
      graphics_command = "\\noindent\\includestandalone[".. 
        width.."]{"..el.src.."}"
    elseif el.classes:includes('pgf') then
      graphics_command = "\\noindent\\inputpgf{"..el.src.."}"
    else
      graphics_command = "\\noindent\\includegraphics[".. 
        width.."]{"..el.src.."}"
    end
    -- return
    return pandoc.RawInline('latex', graphics_command)
  else
    return el
  end
end

function figurer(el,nofloat)
  local image = el.content[1].content[1]
  local i
  local e
  local options
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local fig_tex
    -- content, essentially Image
    local el_walked = pandoc.walk_block(el,{
      Image = function(el)
        return imager(el)
      end,
    })
    local content_doc = pandoc.Pandoc(el_walked.content)
    local content = pandoc.write(content_doc,'latex')
    -- reset \graphicslist{}
    graphics_list_reset = "\\gdef\\graphicslist{}%\n"
    -- nofloat option
    local fig_begin
    local fig_end
    -- local nofloat_text
    if nofloat then
      fig_begin = "\\begin{figure}[H]%\n" ..
        "\\centering\n"
      fig_end = "\\end{figure}%\n\n"
      -- nofloat_text = "nofloat"
    else
      if el.attr.attributes['position'] then
        position = el.attr.attributes['position']
      else
        position = 'H'
      end
      fig_begin = "\\begin{figure}["..position.."]\n" ..
        "\\centering\n"
      fig_end = "\\end{figure}\n"
      -- nofloat_text = "float"
    end
    -- get figcaption options
    local caption = image.caption
    local attributes = el.content[1].content[1].attr.attributes -- Now nested down inside Image
    figcaption_keys = {"color","format","credit","permission","reprint","territory","language","edition","fair","publicity","size","permissioncomment","layoutcomment"}
    options = "["
    i = 0
    for key, value in pairs(attributes) do
      if has_value(figcaption_keys,key) then -- for markdown
        if i==0 then
          sep = ""
        else
          sep = ","
        end
        options = options .. sep .. key .. "={" .. value .. "}"
        i = i + 1
      end
    end
    options = options .. "]"
    -- caption
    local caption = image.caption
    if caption==nil then
      caption = ""
    else
      caption = pandoc.Para(caption)
      caption = pandoc.walk_block(caption,inline_filter)
      local caption_doc = pandoc.Pandoc(caption)
      caption = pandoc.write(caption_doc,'latex')
    end
    -- construct latex figure
    local fig_tex = graphics_list_reset ..
      fig_begin ..
      content ..
      "\n\\figcaption"..options..
      "[".."]{".. -- deprecated nofloat
      el.identifier.."}{" .. 
      caption.."}\n"..
      fig_end
    return pandoc.RawInline('latex', fig_tex)
  elseif FORMAT:match 'html' then
    -- deal with filename stuff
    local stripped = string.gsub(image.src,"common/",'')
    local path
    local file
    local ext
    path,file,ext = split_filename(stripped)
    local fname
    if (ext == nil or ext == '') then
      fname = path..file..'svg'
    elseif (ext == 'pdf' or ext == 'pgf') then
      fname = string.gsub(path..file,'%.pdf','.svg')
      fname = string.gsub(fname,'%.pgf','.svg')
    else -- already has extension
      fname = stripped
    end
    image.src = '/assets/' .. fname -- because relative src is to page in html
    -- normalize svg width because it looks small on the site
    -- if ext == 'svg' then
    -- image.attr.attributes['width'] = "120%"
    -- end
    -- get figcaption options
    local attributes = el.content[1].content[1].attr.attributes -- Now nested down inside Image
    figcaption_keys = {"color","format","credit","permission","reprint","territory","language","edition","fair","publicity","size","permissioncomment","layoutcomment"}
    local options = ""
    i = 0
    for key, value in pairs(attributes) do
      if has_value(figcaption_keys,key) then -- for markdown
        if i==0 then
          sep = ""
        else
          sep = " "
        end
        options = options .. sep .. "data-" .. key .. "=\"" .. value .. "\""
        i = i + 1
      end
    end
    -- caption
    local caption = image.caption
    if caption==nil then
      caption = ""
    else
      caption = pandoc.Para(caption)
      caption = pandoc.walk_block(caption,inline_filter)
      local caption_doc = pandoc.Pandoc(caption)
      caption = pandoc.write(caption_doc,'html')
      caption = string.gsub(caption,'<p>','')
      caption = string.gsub(caption,'</p>','')
      caption = string.gsub(caption,'\n',' ')
    end
    -- construct html figure
    local el_id = el.identifier
    if el_id == nil then
      el_id = ""
    end
    local fig_begin = "<figure class=\"real-figure\" id=\""..el_id.."\">"
    local fig_end = "</figure>"
    local img_classes = ""
    for i, c in ipairs(image.classes) do
      img_classes = img_classes .. c .. " "
    end
    -- get the figure number from the book json
    local fig_number = book_value("0",el_id,"number")
    if fig_number == nil then fig_number = "" end
    caption = "Figure "..fig_number..": "..caption
    local img_content = "<img src=\""..image.src.."\" class=\""..img_classes.."\" alt=\" Figure "..fig_number.."\" "..options..">"
    local fig_caption = "<figcaption>"..caption.."</figcaption>"
    local fig_html = 
      fig_begin .."\n"..
      img_content .."\n"..
      fig_caption .."\n"..
      fig_end
    return pandoc.RawInline('html',fig_html)
  else
    return el
  end
end

local function figurediver(el)
  -- For subfigure Divs
  -- Process the Image objects and the caption.
  --
  -- The source for these Divs looks like this:
  -- ::: {#fig:foo .figure .subfigures h="fig:foo" rows=2 caption_plain="A plain text version of the caption."}
  -- ![A subfigure caption.](figures/foo-1/main){#fig:foo-1 .subfigure .figure .standalone}
  --
  -- ![Another subfigure caption.](figures/foo-1/main){#fig:foo-2 .subfigure .figure .standalone}
  --
  -- A caption.
  -- :::
  -- The caption is the last element in the Div.
  -- The `rows` attribute is the number of rows of subfigures.
  -- Given `N` subfigures, `ceil(N/rows)` is the number of columns.
  -- If `rows` is not given, it defaults to 1.
  if FORMAT:match 'latex' then
    -- Use the following output format (continued from the example above):
    -- \begin{figure}[H]
    -- \centering
    -- % Row 1
    -- \hspace*{\fill}%
    -- \subcaptionbox{A subfigure caption.\label{fig:foo-1}}
    -- {\includegraphics{figures/foo-1/main}}
    -- \hspace*{\fill}\\%
    -- % Row 2
    -- \hspace*{\fill}%
    -- \subcaptionbox{Another subfigure caption.\label{fig:foo-2}}
    -- {\includegraphics{figures/foo-2/main}}
    -- \hspace*{\fill}%
    -- \figcaption[color=color]{fig:foo}{A caption.}
    -- \end{figure}
    -- Get the number of rows
    local rows = el.attr.attributes['rows']
    if not rows then
      rows = 1
    else
      rows = tonumber(rows)
    end
    -- Get the caption
    -- See if the last element is an Image object (otherwise, it's a caption)
    local last_el = el.content[#el.content].content[1]
    local n_subfigures
    local caption
    local caption_plain
    if last_el.t == 'Image' then
      n_subfigures = #el.content
      caption = pandoc.Para{}
    else
      n_subfigures = #el.content-1
      caption = el.content[#el.content]
    end
    caption_plain = el.attr.attributes['caption_plain']
    -- Get the subfigures
    local subfigures = {}
    for i = 1, n_subfigures do
      subfigures[i] = el.content[i].content[1]
    end
    -- Extract the source file name, caption, and label from each subfigure
    local subfigure_captions = {}
    local subfigure_srcs = {}
    local subfigure_labels = {}
    local subfigure_classes = {}
    for i = 1, #subfigures do
      local subfigure_image
      if subfigures[i].t == 'Image' then
        subfigure_image = subfigures[i]
      else -- Plain (not sure why this happens)
        subfigure_image = subfigures[i].content[1]
      end
      -- Subfigure caption
      subfigure_captions[i] = subfigure_image.caption
      if subfigure_captions[i] == nil or isempty(subfigure_captions[i]) then
        subfigure_captions[i] = ""
      end
      --- Parse subfigure caption as latex
      local subfigure_caption_doc = pandoc.Pandoc(subfigure_captions[i])
      subfigure_captions[i] = pandoc.write(subfigure_caption_doc,'latex')
      --- Now stringify the caption
      subfigure_captions[i] = pandoc.utils.stringify(subfigure_captions[i])
      -- Image source
      subfigure_srcs[i] = subfigure_image.src
      if subfigure_srcs[i] == nil then
        subfigure_srcs[i] = ""
      end
      -- Label
      subfigure_labels[i] = subfigure_image.identifier
      if subfigure_labels[i] == nil then
        random_number = math.random(1000000)
        subfigure_labels[i] = "fig:auto-" .. random_number
      end
      -- Classes
      subfigure_classes[i] = subfigure_image.classes
      if subfigure_classes[i] == nil then
        subfigure_classes[i] = {}
      end
    end
    -- Construct the LaTeX code
    local fig_tex = "\\begin{figure}[H]\n" ..
      "\\centering\n"
    -- Construct the subfigures
    local cols = math.ceil(n_subfigures/rows)
    local current_row = 1
    local subcaption_width = 1/cols - 0.05
    fig_tex = fig_tex .. "% Row 1\n"
    for i = 1, #subfigures do
      if math.fmod(i-1,cols) == 0 and i ~= 1 then
        current_row = current_row + 1
        fig_tex = fig_tex .. "\\\\\n% Row " .. current_row .. "\n"
      end
      -- Determine which graphics command to use
      if subfigure_classes[i]:includes('standalone') then
        graphics_command = "\\noindent\\includegraphics{"..subfigure_srcs[i].."}" -- \includestandalone has issues with spacing subfigures
      elseif subfigure_classes[i]:includes('pgf') then
        graphics_command = "\\noindent\\inputpgf{"..subfigure_srcs[i].."}"
      else
        graphics_command = "\\noindent\\includegraphics{"..subfigure_srcs[i].."}"
      end
      local filler_before = "\\hspace*{\\fill}%\n"
      local filler_after = ""
      if math.fmod(i,cols) == 0 then
        filler_after = "\\hspace*{\\fill}%\n"
      end
      -- Append the subfigure
      fig_tex = fig_tex .. filler_before ..
        "\\subcaptionbox{" .. subfigure_captions[i] .. "\\label{" .. subfigure_labels[i] .. "}}" ..
        "[".. subcaption_width .."\\linewidth]\n" ..
        "{" .. graphics_command .."}\n" ..
        filler_after
    end
    -- Construct the caption
    local caption_doc = pandoc.Pandoc(caption)
    local caption_tex = pandoc.write(caption_doc,'latex')
    fig_tex = fig_tex .. "\\figcaption{" .. el.identifier .. "}{" .. caption_tex .. "}\n" ..
      "\\end{figure}\n"
    return pandoc.RawBlock('latex', fig_tex)

  elseif FORMAT:match 'html' then
    return el 
  else
    return el 
  end
end

local function algorithmerHTML(el)
  -- return pandoc.RawBlock('html',"<pre class='algorithm'>\n" .. el.text .. "\n</pre>")
  -- deal with filename stuff
  -- print(el)
  local image = el.content[1].content[1]
  local stripped = string.gsub(image.src,"common/",'')
  local path
  local file
  local ext
  path,file,ext = split_filename(stripped)
  local fname
  if (ext == nil or ext == '') then
    fname = path..file..'svg'
  elseif (ext == 'pdf' or ext == 'pgf') then
    fname = string.gsub(path..file,'%.pdf','.svg')
    fname = string.gsub(fname,'%.pgf','.svg')
  else -- already has extension
    fname = stripped
  end
  image.src = '/assets/' .. fname -- because relative src is to page in html
  -- caption
  local caption = image.caption
  if caption==nil then
    caption = ""
  else
    caption = pandoc.Para(caption)
    caption = pandoc.walk_block(caption,inline_filter)
    local caption_doc = pandoc.Pandoc(caption)
    caption = pandoc.write(caption_doc,'html')
    caption = string.gsub(caption,'<p>','')
    caption = string.gsub(caption,'</p>','')
    caption = string.gsub(caption,'\n',' ')
  end
  -- construct html figure
  local el_id = el.identifier
  if el_id == nil then
    el_id = ""
  end
  local fig_begin = "<figure class=\"real-figure algorithm\" id=\""..el_id.."\">"
  local fig_end = "</figure>"
  local img_classes = ""
  for i, c in ipairs(image.classes) do
    img_classes = img_classes .. c .. " "
  end
  -- get the algorithm number from the book json
  local alg_number = book_value("0",el_id,"number")
  if alg_number == nil then alg_number = "" end
  caption = "Algorithm "..alg_number..": "..caption
  local img_content = "<img src=\""..image.src.."\" class=\""..img_classes.."\" alt=\"Algorithm\">"
  local fig_caption = "<figcaption>"..caption.."</figcaption>"
  local fig_html = 
    fig_begin .."\n"..
    fig_caption .."\n"..
    img_content .."\n"..
    fig_end
  return pandoc.RawInline('html',fig_html)
end

local function algorithmerLATEX(el)
  -- include content from the src file
  local image = el.content[1].content[1]
  local stripped = string.gsub(image.src,"common/",'')
  local path
  local file
  local ext
  path,file,ext = split_filename(stripped)
  print(path)
  print(file)
  if FORMAT:match 'beamer' then
    -- Remove the leading editable/ from the path
    path = string.gsub(path,'editable/','')
    -- Remove first two characters from path (hash ... this assumes two-character hashes, which have been conventional thus far)
    path = string.sub(path,3)
  end
  local fname = "common/"..path..file..'tex'
  -- read file as raw latex
  print('fname: '..fname)
  local f = io.open(fname, "r")
  local content = f:read("*all")
  f:close()
  -- filter out everthing prior to and including `\begin{document}` and after and including `\end{document}`
  content = string.gsub(content,'.*\\begin{document}','')
  content = string.gsub(content,'\\end{document}.*','')
  -- caption
  local caption = image.caption
  if caption==nil then
    caption = ""
  else
    caption = pandoc.Para(caption)
    caption = pandoc.walk_block(caption,inline_filter)
    local caption_doc = pandoc.Pandoc(caption)
    caption = pandoc.write(caption_doc,'latex')
  end
  -- get the label from the identifier
  local id = el.identifier
  if id == nil then id = '' end
  local label = "\\label{"..id.."}"
  -- start with the width attribute
  local width = el.content[1].content[1].attr.attributes["width"] -- Now nested down inside Image
  local start = "\\begin{algorithmcenter}\n\\begin{minipage}{"..width.."}\n\\begin{algorithm}[H]\n"
  -- construct latex algorithm environment
  local fig_tex = start ..
  "\\algcaption{"..id.."}{"..caption.."}\n"..
    content ..
  "\\end{algorithm}\n\\end{minipage}\n\\end{algorithmcenter}"
  return pandoc.RawBlock('latex', fig_tex)
end

local function version_params_subber(el)
  -- print('version params: '..version_params_flat[el.classes[1]])
  return pandoc.Span(
    pandoc.RawInline('latex',
      version_params_flat[el.classes[1]]
    )
  )
end

-- local function exerciser(el)
--   if FORMAT:match 'latex' or FORMAT:match 'beamer' then
--     local el_walked = pandoc.walk_block(el,{
--       Code = function(el)
--         return coder_latex(el)
--       end 
--     })
--     local content_doc = pandoc.Pandoc(el_walked.content)
--     local content = pandoc.write(content_doc,'latex')
--     -- if text == nil then text = "" end
--     local hash = el.attr.attributes['h']
--     local hash_alt = el.attr.attributes['hash']
--     if not hash then if not hash_alt then hash = '' else hash=hash_alt end end
--     return pandoc.RawBlock('latex',
--       "\\begin{exercise}[ID="..hash..",hash="..hash.."]\n"..
--       content..
--       "\n\\end{exercise}"
--     )
--   else
--     return el 
--   end
-- end

function coder_latex(el)
  local language
  if not isempty(el.classes) then
    language = el.classes[1]
  else
    language = 'text'
  end
  if el.t == 'CodeBlock' then
    local code_block = el.text
    local content = pandoc.utils.stringify(code_block)
    local samepage
    if el.classes:includes('nosamepage') then
      samepage = ''
    else
      samepage = ',samepage'
    end
    local linenos
    if el.classes:includes('linenos') then
      linenos = ',linenos'
    else
      linenos = ''
    end
    return pandoc.RawBlock('latex',
      '\\begin{mintedwrapper}\\nointerlineskip\\nointerlineskip\\begin{minted}[autogobble'..samepage..linenos..']{'..language..'}\n'.. 
      content..'\n'..
      '\\end{minted}\n\\end{mintedwrapper}\n'
    )
  elseif el.t == 'Code' then
    local content = pandoc.utils.stringify(el.text)
    return pandoc.RawInline('latex',
      '\\mintinline{'..language..'}|'..content..'|'
    )
  else
    return el
  end
end

function interior_ordered_lister(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    -- Walk with interior_filter
    el = pandoc.walk_block(el,interior_filter)
    return el -- going to make alpha in environments.sty
  elseif FORMAT:match 'html' then
    -- el.classes[#el.classes+1] = 'alpha-ol' -- Apparently OrderedList elements don't have classes anymore? Getting "attempt to index a nil value (field 'classes')" error
    return el 
  else
    return el 
  end
end

local function exercise_solution(el)
  local el_walked = pandoc.walk_block(el,interior_filter)
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'latex')
  content = delimiter_dollar(content)
  if el.classes:includes('lab') then
    return pandoc.RawBlock('latex',
      "\\end{labexercise}\n".. 
      "\\begin{labsolution}\n".. 
      content.."\n"..
      "\\end{labsolution}"
    )
  else
    return pandoc.RawBlock('latex',
      "\\end{exercise}\n".. 
      "\\begin{solution}\n".. 
      content.."\n"..
      "\\end{solution}"
    )
  end
end

local function exerciser(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local el_walked = pandoc.walk_block(el,{
      Div = function(el)
        if el.classes:includes('exercise-solution') or el.classes:includes('solution') then
          return exercise_solution(el)
        else
          return el
        end
      end,
      Header = function(el) -- Demote and unnumber all headers
        el.level = el.level + 2
        el.classes[#el.classes+1] = 'unnumbered'
        return el
      end
    })
    el_walked = pandoc.walk_block(el_walked,interior_filter)
    local content_doc = pandoc.Pandoc(el_walked.content)
    local content = pandoc.write(content_doc,'latex')
    content = delimiter_dollar(content)
    local title = el.attr.attributes['title']
    local hash = el.attr.attributes['h']
    local hash_alt = el.attr.attributes['hash']
    if not hash then if not hash_alt then hash = '' else hash=hash_alt end end
    if not title then title = '' end
    if el.classes:includes('lab') then
      return pandoc.RawBlock('latex',
        "\\begin{labexercise}[ID="..hash..",hash="..hash.."]\n"..
        content
      )
    else
      return pandoc.RawBlock('latex',
        "\\begin{exercise}[ID="..hash..",hash="..hash.."]\n"..
        content
      )
    end
  else
    -- Add data attributes to the div from the book json by looking up the hash
    local hash = el.attr.attributes['h']
    local hash_alt = el.attr.attributes['hash']
    if not hash then if not hash_alt then hash = '' else hash=hash_alt end end
    local data = book_value("0",hash,"problem-num")
    if data == nil then data = "" end
    el.attr.attributes['data-problem-num'] = data
    return el
  end
end

local function listinger(el)
  local code_block = el.content[1]
  local id = pandoc.utils.stringify(el.identifier)
  local caption = el.attr.attributes['caption']
  local language = code_block.classes[1]
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.attr.attributes['caption'] then
      local caption_pre = pandoc.read(caption,'markdown').blocks[1]
      local caption_walked = pandoc.walk_block(caption_pre,interior_filter)
      local caption_doc = pandoc.Pandoc(caption_walked)
      caption = pandoc.write(caption_doc,'latex')
    else
      caption = ''
    end
    local content = pandoc.utils.stringify(code_block.text)
    local mynewminted
    local language
    if code_block.classes then
      language = code_block.classes[1]
    else
      language = ''
    end
    if language == 'c' then
      if el.classes:includes('long') and el.classes:includes('texcomments') then
        mynewminted = 'clistinglongtexcomments'
      elseif el.classes:includes('linenos') then
        if el.classes:includes('long') then
          mynewminted = 'clistinglonglinenos'
        else
          mynewminted = 'clistinglinenos'
        end
      elseif el.classes:includes('long') and not el.classes:includes('texcomments') then
        mynewminted = 'clistinglong'
      elseif not el.classes:includes('long') and el.classes:includes('texcomments') then
        mynewminted = 'clistingtexcomments'
      else
        mynewminted = 'clisting'
      end
    elseif language == 'arm' then
      mynewminted = 'armlisting'
    else
      mynewminted = 'textlisting'
    end
    local list_tex
    local texcomments
    local position
    if el.classes:includes('nofloat') then
      position = 'nofloat'
    else -- float
      if el.attr.attributes['position'] then
        position = el.attr.attributes['position'] -- untested ... idea is could pass attribute position=h or similar
      else
        position = 'htbp'
      end
    end
    local ifsolution_beg = ''
    local ifsolution_end = ''
    if el.classes:includes('solutions-only') then
      ifsolution_beg = '\n\\ifdefined\\issolution\n'
      ifsolution_end = '\n\\fi\n'
    end
    if position == 'nofloat' then
      list_tex = pandoc.RawInline('latex',
        ifsolution_beg..'\\begin{listingsbox}{'..mynewminted..'}{'..caption..'}{'..id..'}\n'..
        content..'\n'..
        '\\end{listingsbox}'..ifsolution_end
      )
    else -- float
      list_tex = pandoc.RawInline('latex',
        ifsolution_beg..'\\begin{listingsboxfloat}{'..mynewminted..'}{'..caption..'}{'..id..'}{'..position..'}\n'..
        content..'\n'..
        '\\end{listingsboxfloat}'..ifsolution_end
      )
    end
    return list_tex
  elseif FORMAT:match 'html' then
    -- Look up listing number from book json
    if el.classes:includes('solutions-only') then
      return {}  -- don't include solutions in html (website)
    end
    local listing_number = book_value("0",id,"listing-num")
    return pandoc.Div({
      pandoc.CodeBlock(
        code_block.text,
        {identifier=id,class=language}
      )},{class='listing', number=listing_number, caption=caption})
  else
    return el
  end
end

local function bgreadinglister(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local content = el.content
    content = pandoc.utils.stringify(content)
    return pandoc.RawInline('latex',
      '\\bgreadinglist{'.. 
      content.. 
      '}\n'
    )
  elseif FORMAT:match 'html' then
    return el -- TODO
  end
end

local function freadinglister(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    el_walked = pandoc.walk_block(el,interior_filter)
    local content_doc = pandoc.Pandoc(el_walked.content)
    local content = pandoc.write(content_doc,'latex')
    local identifier = el.identifier
    if identifier == nil then
      identifier = ""
    else
      identifier = "[label=" .. el.identifier .. "]"
    end
    return pandoc.RawInline('latex',
      '\\freadinglist'..identifier..'{'.. 
      content.. 
      '}\n'
    )
  elseif FORMAT:match 'html' then
    return el -- TODO
  end
end

local function example_solution(el)
  local el_walked = pandoc.walk_block(el,interior_filter)
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'latex')
  content = delimiter_dollar(content)
  if el.classes:includes('example-solution') then
    return pandoc.RawBlock('latex',
      "\\tcblower\n".. 
      content
    )
  else
    return pandoc.RawBlock('latex',
      content
    )
  end
end

local function example_solution_html(el)
  print(dump(el))
  local el_walked = pandoc.walk_block(el,interior_filter)
  print(dump(el_walked))
  local content_doc = pandoc.Pandoc(el_walked.content)
  local content = pandoc.write(content_doc,'html')
  content = delimiter_dollar(content)
  if el.classes:includes('example-solution') then
    return pandoc.Div(
      pandoc.RawBlock('html',
        content
      ),
      {class='example-solution'}
    )
  else
    return pandoc.RawBlock('html',
      content
    )
  end
end

local function exampler(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local identifier = el.identifier
    local el_walked = pandoc.walk_block(el,{
      Div = function(el)
        return example_solution(el)
      end
    })
    el_walked = pandoc.walk_block(el_walked,interior_filter)
    local content_doc = pandoc.Pandoc(el_walked.content)
    local content = pandoc.write(content_doc,'latex')
    content = delimiter_dollar(content)
    local hash = el.attr.attributes['h']
    local v = versioned(el)
    if not v then v = '' end
    return pandoc.RawBlock('latex',
      "\\begin{myexample}["..v.."]{"..identifier.."}{"..hash.."}\n\\noindent "..
      content..
      "\n\\end{myexample}"
    )
  elseif FORMAT:match 'html' then
    local identifier = el.identifier
    local el_walked = pandoc.walk_block(el,interior_filter)
    el_walked = pandoc.walk_block(el_walked,{
      Div = function(el)
        return example_solution_html(el)
      end
    })
    local content_doc = pandoc.Pandoc(el_walked.content)
    local content = pandoc.write(content_doc,'html')
    content = delimiter_dollar(content)
    local hash = el.attr.attributes['h']
    local v = versioned(el)
    if not v then v = '' end
    -- Get the example number from the book json
    local example_number = book_value(text_version,hash,"example-num")
    if example_number == nil then example_number = "" end
    new = pandoc.Div(
      pandoc.RawBlock('html',
        "<div class='example-title'>\n"..
        "<span class='example-number'>Example "..example_number.."</span>\n"..
        "</div>\n"..
        content
      ),
      {class='example',id=identifier}
    )
    new.attr.attributes['data-hash'] = hash
    new.attr.attributes['data-version'] = v
    return new
  else
    return el 
  end
end

local function keyworder(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local content = pandoc.utils.stringify(el.content)
    return pandoc.RawInline('latex', "\\keyword{" .. content .. "}")
  else
    return el
  end
end

local function vspaner(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.classes:includes('ts') then
      return pandoc.RawInline('latex', "\\ts{}")
    elseif el.classes:includes('ds') then
      return pandoc.RawInline('latex', "\\ds{}")
    else
      return el
    end
  elseif FORMAT:match 'html' then
    if el.classes:includes('ts') then
      el.content = book_def['editions'][text_version]['v-ts']
    elseif el.classes:includes('ds') then
      el.content = book_def['editions'][text_version]['v-ds']
    end
    return el
  else
    return el
  end
end

local function vsiconer(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.classes:includes('tsicon') then
      return pandoc.RawInline('latex', "\\tsicon{\\ts}")
    elseif el.classes:includes('dsicon') then
      return pandoc.RawInline('latex', "\\dsicon{\\ds}")
    else
      return el
    end
  elseif FORMAT:match 'html' then
    if el.classes:includes('tsicon') then
      el.content = book_def['editions'][text_version]['v-ts']
    elseif el.classes:includes('dsicon') then
      el.content = book_def['editions'][text_version]['v-ds']
    end
    return el
  else
    return el
  end
end

function mathspaner(el) -- for interior math
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    -- print(dump(el))
    if el.content[1].mathtype == 'InlineMath' then
      return pandoc.RawInline('tex', '$' .. el.text .. '$')
    else
      -- print(dump(el))
      local identifier = el.identifier
      local content = el.content[1].text
      if not identifier then identifier='' end
      if not content then content='' end
      return pandoc.RawInline('latex', -- this only numbers the last equation
        "\n\\begin{align*}"..
        content.."\\numberthis \\label{"..identifier.."}\n"..
        "\\end{align*}\n"
      )
    end
  else
    return el
  end
end

local function indexer(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local ss = '[]'
    local fun = '[]'
    local primary = ''
    local code = false
    local show = '[]'
    local lang = ''
    local lab = '[]'
    local post = '[]'
    local under = '[]'
    local special = {
      [1] = "cop",
      [2] = "ccon",
      [3] = "cfun",
      [4] = "ctype",
      [5] = "cmacro",
      [6] = "cheader",
      [7] = "cstruct",
      [8] = "myriocon",
      [9] = "myrioheader",
      [10] = "myriofun",
      [11] = "myriotype",
      [12] = "myriostruct",
      [13] = "myriomacro",
      [14] = "tcon",
      [15] = "ttype",
      [16] = "tmacro",
      [17] = "tstruct",
      [18] = "theader",
      [19] = "tfun",
      [20] = "ucon",
      [21] = "utype",
      [22] = "umacro",
      [23] = "ustruct",
      [24] = "uheader",
      [25] = "ufunl0",
      [26] = "ufunl1",
      [27] = "ufunl2",
      [28] = "ufunl3",
      [29] = "ufunl4",
      [30] = "ufunl5",
      [31] = "ufunl6",
      [32] = "ufunl7",
      [33] = "ufunl8",
      [34] = "matlab",
      [35] = "cqual",
      [36] = "cspec",
      [37] = "ufun",
      [38] = "linuxheader",
      [39] = "posixfun",
    }
    -- pre-parse for probably missed options
    --- missed function
    if el.classes:includes('cfun') or el.classes:includes('myriofun') or el.classes:includes('ufun') or el.classes:includes('ufunl0') or el.classes:includes('ufunl1') or el.classes:includes('ufunl2') or el.classes:includes('ufunl3') or el.classes:includes('ufunl4') or el.classes:includes('ufunl5') or el.classes:includes('ufunl6') or el.classes:includes('ufunl7') or el.classes:includes('ufunl8') then -- or el.classes:includes('tfun') removed because of redundancy with ufunlX
      el.classes:insert('function')
    end
    --- missed code
    local missed_code = false 
    for _, item in ipairs(special) do
      if el.classes:includes(item) then
        missed_code = true
      end
    end
    if missed_code or el.classes:includes('c') or el.classes:includes('matlab') or el.classes:includes('bash') or el.classes:includes('function') then
      el.classes:insert('code')
    end
    --- missed c
    local missed_c = false 
    for _, item in ipairs(special) do
      if el.classes:includes(item) then
        missed_c = true
      end
    end
    if missed_c and not el.classes:includes('matlab') and not el.classes:includes('bash') then
      el.classes:insert('c')
    end
    -- parse
    if el.classes:includes('start') then
      ss = '[start]'
    elseif el.classes:includes('stop') then
      ss = '[stop]'
    end
    if el.classes:includes('function') then
      fun = "[true]"
    end
    if el.attr.attributes['under'] then
      under = "["..el.attr.attributes['under'].."]"
    end
    if el.classes:includes('lab') then
      lab = "[L]"
    end
    if el.classes:includes('primary') or el.classes:includes('bold') then
      primary = '*'
    end
    if el.classes:includes('code') or el.classes:includes('c') or el.classes:includes('matlab') or el.classes:includes('bash') then
      code = true -- for \indexc
    end
    if el.classes:includes('c') then
      lang = 'c'
    elseif el.classes:includes('matlab') then
      lang = 'matlab'
    elseif el.classes:includes('bash') then
      lang = 'bash'
    end
    for _, posti in ipairs(special) do
      if el.classes:includes(posti) then
        post = '['..posti..']'
      end
    end
    if el.attr.attributes['show'] then
      show = "["..el.attr.attributes['show'].."]"
    end
    local content = pandoc.utils.stringify(el.content)
    if not code then
      return pandoc.RawInline('latex',
        "\\myindex"..primary..ss..lab..show..under.."{"..content.."}"
      )
    else -- code
      return pandoc.RawInline('latex',
        "\\indexc"..primary..ss..lab..post..fun..under.."{"..lang.."}{"..content.."}"
      )
    end
  elseif FORMAT:match 'html' then
    return pandoc.RawInline('html',"") -- not using the index online
  end
  return ""
end

local function code_shorthand(el)
  if el.classes:includes('py') then
    el.classes[#el.classes+1] = 'python'
  end
  return el
end

local function unicoder(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    local content = el.content
    local text = pandoc.utils.stringify(content)
    return pandoc.RawInline('latex',"\\unicoder{"..text.."}")
  else
    return el
  end
end

local function outputer(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.classes:includes('output') and el.classes:includes('execute_result') then
      local el_walked = pandoc.walk_block(el,interior_filter)
      el_walked = pandoc.walk_block(el_walked,interior_filter)
      local content_doc = pandoc.Pandoc(el_walked.content)
      local content = pandoc.write(content_doc,'latex')
      return pandoc.RawBlock(
        'latex',
        "\\begin{formattedoutput}\n"..content.."\n\\end{formattedoutput}\n"
      )
    else
      return el
    end
  else
    return el
  end
end

local function only_htmler(el)
  if FORMAT:match 'html' then
    return el
  else
    return pandoc.RawBlock(FORMAT,"")
  end
end

------------

function Code(el)
  -- if el.classes:includes('path') then
  --   return pather(el)
  -- else
  el = code_shorthand(el)
  if FORMAT:match 'html' then
    el.classes[#el.classes+1] = 'sourceCode'
    return el
  elseif FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return coder_latex(el)
  else
    -- print('\nELSE\n')
    return el
  end
  -- end
end

function CodeBlock(el)
  -- local id = pandoc.utils.stringify(el.identifier)
  -- print('lst id: '..id)
  -- if starts_with('lst:',id) then
  --   return lstify(el)
  el = code_shorthand(el)
  if FORMAT:match 'html' then
    el.classes[#el.classes+1] = 'sourceCode'
    return el
  elseif FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return coder_latex(el)
  else
    return el
  end
end

-- function Image(el)
--   if el.classes:includes('nofloat') then
--     return figurer(el,true)
--   elseif el.classes:includes('figure') then
--     return figurer(el,false)
--   else
--     return figurer(el,false)
--   end
-- end

function Link(el)
  if el.classes:includes('myurl') then
    return myurler(el)
  else
    return el
  end
end

function RawBlock(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.format:match 'html' then -- process html tables (and other html)
      local html_read = pandoc.read(el.text, 'html+tex_math_dollars').blocks
      -- walk each block
      local html_reads = {}
      for i = 1, #html_read do
        html_reads[i] = pandoc.walk_block(html_read[i], interior_filter) -- this isn't converting the tables
        -- convert tables
        html_reads[i] = pandoc.walk_block(html_reads[i],{
          Table = function(el)
            return pandoc.RawBlock('latex',pandoc.write(el,'latex'))
          end
        })
      end
      return html_reads
    elseif el.format:match 'algorithm' then
      return algorithmerLATEX(el)
    else
      return el
    end
  elseif FORMAT:match 'html' then
    if el.format:match 'algorithm' then
      -- return algorithmerHTML(el)
      return pandoc.RawBlock('html',"<pre class='algorithm'>\n" .. el.text .. "\n</pre>")
    else
      return el
    end
  else
    return el
  end
end

function RawInline(el)
  -- if FORMAT:match 'html', check for inline math. If so, wrap in $$ and return as RawInline 'html'
  if FORMAT:match 'html' then
    if el.format:match 'tex' then
      -- Check if it's inline math by checking if it's surrounded by $ or if it includes \begin{equation or \begin{align or \begin{eqnarray or \begin{cases
      if el.text:match('^%$.*%$$') then
        return pandoc.RawInline('html',el.text)
      elseif el.text:match('\\begin{equation') or el.text:match('\\begin{align') or el.text:match('\\begin{eqnarray') or el.text:match('\\begin{cases') then
        return pandoc.RawInline('html','$$'..el.text..'$$')
      else
        return el
      end
    else
      return el
    end
  else
    return el
  end
end

function Div(el)
  if el.classes:includes('section') then
    -- these are the section-including <div>/<section>s
    if FORMAT:match 'html' then
      return section_diver_html(el)
    elseif FORMAT:match 'latex' then
      return section_diver_latex(el)
    else
      return el 
    end
  else -- regular divs
    if el.classes:includes('infobox') then
      return infoboxer(el)
    elseif el.classes:includes('listing') then
      print("HI")
      return listinger(el)
    elseif el.classes:includes('output') then
      return outputer(el)
    elseif el.classes:includes('exercise') then
      return exerciser(el)
    elseif el.classes:includes('bgreadinglist') then
      return bgreadinglister(el)
    elseif el.classes:includes('freadinglist') then
      return freadinglister(el)
    elseif el.classes:includes('figure') then
      return figurediver(el)
    elseif el.classes:includes('example') then
      return exampler(el)
    elseif el.classes:includes('theorem') or el.classes:includes('lemma') or el.classes:includes('corollary') or el.classes:includes('proposition') then
      return theoremer(el)
    elseif el.classes:includes('definition') then
      return definitioner(el)
    elseif el.classes:includes('only-html') then
      return only_htmler(el)
    else
      return el
    end
  end
end

function Span(el)
  if el.classes:includes('key') or el.classes:includes('keys') then
    return keyer(el)
  elseif el.classes:includes('menu') then
    if FORMAT:match 'html' then
      return menuer_html(el)
    elseif FORMAT:match 'latex' or FORMAT:match 'beamer' then
      return menuer_latex(el)
    else
      return el
    end
  elseif el.classes:includes('unicode') then
    return unicoder(el)
  elseif el.classes:includes('path') then
    return pather(el)
  elseif el.classes:includes('hashref') or el.classes:includes('Hashref') or el.classes:includes('href') or el.classes:includes('Href') then
    return hashrefer(el)
  elseif el.classes:includes('lref') then
    return linerefer(el)
  elseif el.classes:includes('label') then
    return labeler(el)
  elseif el.classes:includes('plaincite') then
    return plainciter(el)
  elseif el.classes:includes('keyword') then
    return keyworder(el)
  elseif el.classes:includes('index') then
    return indexer(el)
  elseif el.classes:includes('ts') or el.classes:includes('ds') then
    return vspaner(el)
  elseif el.classes:includes('tsicon') or el.classes:includes('dsicon') then
    return vsiconer(el)
  elseif version_params_flat[el.classes[1]] then
    return version_params_subber(el)
  elseif starts_with('eq:',el.identifier) then -- display math inside environments like examples should have a tag wrapped arond with identifier starting with eq:
    return mathspaner(el)
  else
    return el
  end
end

function Cite(el)
  first_id = el.citations[1].id
  if starts_with('sec:',first_id) or starts_with('Sec:',first_id) or starts_with('eq:',first_id) or starts_with('Eq:',first_id) or starts_with('tbl:',first_id) or starts_with('Tbl:',first_id) or starts_with('fig:',first_id) or starts_with('Fig:',first_id) or starts_with('lst:',first_id) or starts_with('Lst:',first_id) then
    -- pandoc-crossref
    return el
  else
    return citer(el)
  end
end

function Header(el)
  if FORMAT:match 'latex' then
    return headerer_latex(el)
  elseif FORMAT:match 'beamer' then
    return el
  elseif FORMAT:match 'html' then
    -- if el.classes:includes('v') then
    --   el.classes:insert('hide')
    -- end
    return headerer_html(el)
  else
    return el
  end
end

function Math(el)
  -- print('\nmath\n')
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    if el.mathtype == 'InlineMath' then
      return pandoc.RawInline('tex', '$' .. el.text .. '$')
    else
      return el
    end
  else
    return el
  end
end

function Figure(el)
  if el.content[1].content[1].classes:includes('algorithm') then
    if FORMAT:match 'latex' or FORMAT:match 'beamer' then
      return algorithmerLATEX(el)
    elseif FORMAT:match 'html' then
      return algorithmerHTML(el)
    else
      return el
    end
  elseif el.classes:includes('nofloat') then
    return figurer(el,true) -- making all figures nofloat
  elseif el.classes:includes('figure') then
    return figurer(el,true) -- making all figures nofloat
  else
    return figurer(el,true) -- making all figures nofloat
  end
end

function get_table_id(el)
  -- Get the identifier from the caption (don't know why it's not in the identifier field)
  -- Convert to SimpleTable if necessary
  if el.t == 'Table' then
    el = pandoc.utils.to_simple_table(el)
  end
  local caption = pandoc.utils.stringify(el.caption)
  local id = string.match(caption, "%{.*%}$")
  -- Remove the leading {# and trailing } from the id
  if id == nil then id = '' end
  id = string.sub(id, 3, -2)
  return id
end

function get_table_caption(el)
  -- Get the caption by converting to a SimpleTable
  -- Convert to SimpleTable if necessary
  if el.t == 'Table' then
    el = pandoc.utils.to_simple_table(el)
  end
  -- local caption = pandoc.utils.stringify(el.caption)
  -- Instead of stringifying caption, filter it with inline_filter
  local caption = el.caption
  -- Convert the caption to a Pandoc document
  caption = pandoc.walk_block(caption, interior_filter)
  caption_doc = pandoc.Pandoc(caption)
  if FORMAT:match 'html' then
    caption = pandoc.write(caption_doc, 'html')
    -- Remove the identifier from the caption, which is in the form {#identifier} at the end
    id = get_table_id(el)
    caption = string.gsub(caption, "%s*{#.*}$", "")
    caption = {pandoc.RawBlock('html', caption)}
  else
    caption = pandoc.write(caption_doc, 'latex')
    caption = string.gsub(caption, "%s*{#.*}$", "")
    caption = {pandoc.RawBlock('latex', caption)}
  end
  return caption
end

function tabler_html(el)
  -- Add data attributes for table number and caption from the book json
  local id = get_table_id(el)
  -- local caption = get_table_caption(el)
  -- Get the number from the book json
  local number = book_value("0",id,"number")
  if number == nil then number = "" end
  -- Convert to SimpleTable
  el = pandoc.utils.to_simple_table(el)
  -- Update the caption to include the number
  local old_caption = el.caption
  -- Walk the caption with inline_filter
  local new_caption = pandoc.walk_block(old_caption, interior_filter)
  -- Convert the caption to a Pandoc document
  new_caption = pandoc.Pandoc(new_caption)
  -- Convert the caption to HTML
  new_caption = pandoc.write(new_caption, 'html+raw_tex')
  new_caption = string.gsub(new_caption, "%s*{#.*}$", "")
  new_caption = pandoc.RawInline('html', new_caption)
  -- Add the number to the caption
  local new_caption = {pandoc.Str("Table "), pandoc.Str(number), pandoc.Str(": "), new_caption}
  el.caption = new_caption
  -- Convert the table back to a Table element
  el = pandoc.utils.from_simple_table(el)
  -- Add the number as data attribute
  el.attr.attributes["number"] = number
  return el
end

function tabler_latex(el)
  local identifier = get_table_id(el)
  el = pandoc.utils.to_simple_table(el)

  local function render_row(row)
    local cells = {}
    for _, cell in ipairs(row) do
      doc = pandoc.Pandoc(cell)
      local cell_text = pandoc.write(doc, 'latex+raw_tex')
      cells[#cells + 1] = cell_text
    end
    return table.concat(cells, " & ").." \\\\"
  end

  local function render_header(row)
    local cells = {}
    for _, cell in ipairs(row) do
      doc = pandoc.Pandoc(cell)
      local cell_text = pandoc.write(doc, 'latex+raw_tex')
      cells[#cells + 1] = cell_text
    end
    return table.concat(cells, " & ").." \\\\"
  end

  local function render_tabular(header, rows)
    if rows == nil then return '' end
    local lines = {}
    lines[1] = "\\toprule"
    lines[2] = render_header(header)
    lines[3] = "\\midrule"
    for i, row in ipairs(rows) do
      lines[#lines + 1] = render_row(row)
    end
    lines[#lines + 1] = "\\bottomrule"
    return "\\begin{tabular}{"..string.rep("l", #rows[1]).."}\n"..table.concat(lines, "\n").."\n\\end{tabular}"
  end

  local function render_table(tbl)
    local caption = get_table_caption(tbl)
    local identifier = get_table_id(tbl)
    print('table identifier: '..identifier)
    print(dump(tbl))
    local caption_text
    if caption then
      caption_text = pandoc.utils.stringify(caption)
    else
      caption_text = ''
    end
    local caption_latex
    if caption then
      -- filter out the trailing {#identifier} from the caption
      caption_text = string.gsub(caption_text, "%s*{#.*}$", "")
      caption_latex = "\\tabcaption[][nofloat]{"..identifier.."}{"..caption_text.."}"
    else
      caption_latex = ''
    end
    local header = tbl.headers
    local rows = tbl.rows
    local content_latex = render_tabular(header, rows)
    return "\\begin{table}\n"..caption_latex.."\n"..content_latex.."\n\\end{table}"
  end

  local cap = pandoc.utils.stringify(el.caption)
  if string.len(cap) > 0 then
    return pandoc.RawBlock('latex', render_table(el))
  else
    return pandoc.RawBlock('latex', render_tabular(el.rows))
  end
end

function Table(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return tabler_latex(el)
  elseif FORMAT:match 'html' then
    return tabler_html(el)
  else
    return el
  end
end

function OrderedList(el)
  if FORMAT:match 'latex' or FORMAT:match 'beamer' then
    return interior_ordered_lister(el)
  else
    return el
  end
end

return {
  {Div = Div},
  {Header = Header},
  {RawBlock = RawBlock},
  {OrderedList = OrderedList},
  {Code = Code},
  {CodeBlock = CodeBlock},
  {RawInline = RawInline},
  {Cite = Cite},
  {Span = Span},
  {Link = Link},
  {Math = Math},
  {Figure = Figure},
  {Table = Table}
  -- {Div = Div, Header = Header,
  -- RawBlock = RawBlock,
  -- Code = Code,
  -- RawInline = RawInline,
  -- Cite = Cite,
  -- Span = Span,
  -- Link = Link,
  -- Image = Image}
}