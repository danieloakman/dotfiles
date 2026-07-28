--!nonstrict
-- Port of the v4 web-search launcher provider.
-- Prefix: /web <query>. Not included in unprefixed (global) launcher search.

local lastQuery = ""
local suggestions = {}

local ENGINES = {
  Google = {
    search = "https://www.google.com/search?q=",
    suggest = "https://suggestqueries.google.com/complete/search?client=chrome&q=",
  },
  DuckDuckGo = {
    search = "https://duckduckgo.com/?q=",
    suggest = "https://duckduckgo.com/ac/?q=",
  },
  Bing = {
    search = "https://www.bing.com/search?q=",
    suggest = "https://www.bing.com/osjson.aspx?query=",
  },
  Brave = {
    search = "https://search.brave.com/search?q=",
    suggest = "https://search.brave.com/api/suggest?q=",
  },
  Yandex = {
    search = "https://yandex.com/search/?text=",
    suggest = "https://suggest.yandex.com/suggest-ya.cgi?v=4&part=",
  },
}

local function engineConfig()
  local name = noctalia.getConfig("search_engine")
  if type(name) ~= "string" or name == "" or not ENGINES[name] then
    name = "Google"
  end
  return name, ENGINES[name]
end

local function shellEscape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function isUrl(text)
  if not text or text:find("%s") then
    return false
  end

  if text:match("^[%w%+%.%-]+://%S+") then
    return true
  end

  if text:match("^localhost(/.*)?$") or text:match("^localhost:") then
    return true
  end

  -- IPv4 with optional port / path
  if text:match("^%d+%.%d+%.%d+%.%d+(:%d+)?(/.*)?$") then
    return true
  end

  -- hostname:port
  if text:match("^[%w%-]+:%d+(/.*)?$") then
    return true
  end

  -- domain.tld...
  if text:match("^[%w%-]+%.[%w%.%-]+(:%d+)?(/.*)?$") then
    return true
  end

  return false
end

local function normalizeUrl(text)
  text = noctalia.string.trim(text)
  if text == "" then
    return ""
  end

  if text:match("^[%w%+%.%-]+://%S+") then
    return text
  end

  if text:match("^localhost") or text:match("^%d+%.%d+%.%d+%.%d+") or text:match("^[%w%-]+:%d+") then
    return "http://" .. text
  end

  return "https://" .. text
end

local function parseSuggestions(body, maxResults)
  local data = noctalia.json.decode(body)
  if type(data) ~= "table" or #data == 0 then
    return {}
  end

  -- DuckDuckGo: [{"phrase":"…"}, …]
  if type(data[1]) == "table" and type(data[1].phrase) == "string" then
    local out = {}
    for i, item in ipairs(data) do
      if i > maxResults then
        break
      end
      if type(item) == "table" and type(item.phrase) == "string" then
        table.insert(out, item.phrase)
      end
    end
    return out
  end

  -- Google / Bing / Brave / Yandex-style: ["query", ["s1", "s2", …], …]
  if type(data[2]) == "table" then
    local out = {}
    for i, item in ipairs(data[2]) do
      if i > maxResults then
        break
      end
      if type(item) == "string" then
        table.insert(out, item)
      elseif type(item) == "table" and type(item[1]) == "string" then
        table.insert(out, item[1])
      end
    end
    return out
  end

  return {}
end

local buildResults

local function fetchSuggestions(originalQuery, text, suggestUrl, maxResults)
  noctalia.http({ url = suggestUrl .. noctalia.string.urlEncode(text) }, function(res)
    if text ~= lastQuery then
      return
    end
    if not res.ok or res.status ~= 200 then
      return
    end

    suggestions = parseSuggestions(res.body or "", maxResults)
    launcher.setResults(originalQuery, buildResults(originalQuery, text))
  end)
end

buildResults = function(query, text)
  local engineName, engine = engineConfig()
  local directUrl = noctalia.getConfig("direct_url")
  if directUrl == nil then
    directUrl = true
  end
  local showSuggestions = noctalia.getConfig("show_suggestions")
  if showSuggestions == nil then
    showSuggestions = true
  end
  local maxResults = noctalia.getConfig("max_results")
  if type(maxResults) ~= "number" then
    maxResults = 5
  end

  local results = {}

  if text == "" then
    table.insert(results, {
      id = "hint",
      title = noctalia.tr("launcher.type_something"),
      subtitle = noctalia.tr("launcher.search_internet", { engine = engineName }),
      glyph = "search",
    })
    return results
  end

  if directUrl and isUrl(text) then
    local url = normalizeUrl(text)
    table.insert(results, {
      id = "open:" .. url,
      title = noctalia.tr("launcher.open_url", { url = url }),
      subtitle = noctalia.tr("launcher.open_url_description"),
      glyph = "link",
      score = 1000,
    })
  end

  table.insert(results, {
    id = "search:" .. text,
    title = noctalia.tr("launcher.search", { query = text }),
    subtitle = noctalia.tr("launcher.open_in", { engine = engineName }),
    glyph = "world",
    score = 999,
  })

  if showSuggestions and text ~= lastQuery and #text > 1 then
    lastQuery = text
    suggestions = {}
    fetchSuggestions(query, text, engine.suggest, maxResults)
  elseif text ~= lastQuery then
    lastQuery = text
    suggestions = {}
  end

  for i, suggestion in ipairs(suggestions) do
    table.insert(results, {
      id = "search:" .. suggestion,
      title = suggestion,
      subtitle = noctalia.tr("launcher.suggestion", { engine = engineName }),
      glyph = "search",
      score = 900 - i,
    })
  end

  return results
end

function onQuery(query)
  local text = noctalia.string.trim(query)
  launcher.setResults(query, buildResults(query, text))
end

function onActivate(id)
  if id == "hint" or id == "" then
    return
  end

  local kind, payload = id:match("^([^:]+):(.*)$")
  if not kind or not payload or payload == "" then
    return
  end

  local _, engine = engineConfig()
  local url

  if kind == "open" then
    url = payload
  elseif kind == "search" then
    url = engine.search .. noctalia.string.urlEncode(payload)
  else
    return
  end

  noctalia.runAsync("xdg-open " .. shellEscape(url))
end
