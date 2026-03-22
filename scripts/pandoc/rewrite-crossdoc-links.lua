-- Rewrite in-repo cross-links between architecture.md and standards.md so a
-- merged pandoc run produces working in-document links (e.g. PDF).

local TOP_ID = {
  ["architecture.md"] = "digital-badges-architecture",
  ["standards.md"] = "standards-and-interoperability-profile",
}

local function basename(path)
  local name = path:match("([^/]+)$")
  return name or path
end

local function normalize_filename(target)
  local path = target
  local q = path:find("?", 1, true)
  if q then
    path = path:sub(1, q - 1)
  end
  local hash = path:find("#", 1, true)
  if hash then
    path = path:sub(1, hash - 1)
  end
  path = path:gsub("^%./", "")
  return basename(path)
end

local function split_fragment(target)
  local hash = target:find("#", 1, true)
  if not hash then
    return target, ""
  end
  return target:sub(1, hash - 1), target:sub(hash + 1)
end

function Link(el)
  local path_part, frag = split_fragment(el.target)
  local name = normalize_filename(path_part)
  local top = TOP_ID[name]
  if not top then
    return el
  end
  if frag ~= "" then
    el.target = "#" .. frag
  else
    el.target = "#" .. top
  end
  return el
end
