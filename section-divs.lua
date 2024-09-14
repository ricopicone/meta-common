-- file: section-divs.lua from https://github.com/jgm/pandoc/issues/5965#issuecomment-563973633
function hierarchicalize (doc)
  return pandoc.Pandoc(
    pandoc.utils.make_sections(true, nil, doc.blocks),
    doc.meta
  )
end

function add_classes (div)
  local header = div.content[1]
  if header and header.t == "Header" then
    div.classes:extend(header.classes)
    div.classes:extend({"section","level" .. header.level})
    -- header.classes = {} -- keep them for versioning
    header.attributes.number = nil
    local id = div.identifier
    header.attributes['shortid'] = id -- move it back to header but as non "identifier" attribute to avoid hypertarget
    div.attributes['shortid'] = id..'-div' -- want to keep the header id but make it unique also non "identifier" attribute to avoid hypertarget
    header.identifier = id -- trying for web side
    div.identifier = ''
    return div
  end
end

return {
  {Pandoc = hierarchicalize},
  {Div = add_classes}
}