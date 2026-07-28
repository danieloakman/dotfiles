--!nonstrict
-- v4 pass-menu port: browse entries, drill into `entry |` for fields, OTP by path.

local entries = {}
local lastQuery = ""
local showState = {
  entry = nil,
  loading = false,
  fetched = false,
  stdout = "",
  stderr = "",
  fields = {},
}

local function shellEscape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function trim(str)
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isOtpPath(path)
  -- v4: name.startsWith("otp")
  return path:sub(1, 3) == "otp"
end

local function wordMatch(query, text)
  if query == nil or query == "" then
    return true
  end

  local haystack = text:lower()

  for word in query:lower():gmatch("%S+") do
    if not haystack:find(word, 1, true) then
      return false
    end
  end

  return true
end

local function pasteClipboard()
  -- TODO: auto-paste after copy isn't reliable yet (launcher focus timing).
  -- noctalia.runAsync("sleep 0.15 && wtype -M ctrl v -m ctrl")
end

local function parseFields(stdout)
  local lines = {}

  for line in stdout:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local fields = {}

  for i = 2, #lines do
    local line = lines[i]
    local colon = line:find(":", 1, true)
    local key = ""
    local value = line

    if colon then
      key = trim(line:sub(1, colon - 1))
      value = trim(line:sub(colon + 1))
    end

    table.insert(fields, {
      raw = line,
      key = key,
      value = value,
    })
  end

  return fields
end

local function splitDrillQuery(query)
  local pipeAt = query:find("|", 1, true)

  if not pipeAt then
    return nil, nil, false
  end

  return trim(query:sub(1, pipeAt - 1)), trim(query:sub(pipeAt + 1)), true
end

local function buildDrillResults(entry, filter)
  local results = {
    {
      id = "password:" .. entry,
      title = string.rep("*", 20),
      subtitle = noctalia.tr("launcher.password_for", { entry = entry }),
      glyph = "key",
      score = 2,
    },
  }

  for i, field in ipairs(showState.fields) do
    if wordMatch(filter, field.raw) then
      table.insert(results, {
        id = "field:" .. tostring(i),
        title = field.value,
        subtitle = field.key ~= "" and field.key or nil,
        glyph = "forms",
        score = 1,
      })
    end
  end

  return results
end

local function publishDrillResults(query, entry, filter)
  if showState.loading then
    launcher.setResults(query, {
      {
        id = "loading",
        title = noctalia.tr("launcher.loading"),
        glyph = "loader",
      },
    })
    return
  end

  if showState.stderr ~= "" then
    launcher.setResults(query, {
      {
        id = "error",
        title = showState.stderr,
        glyph = "alert-triangle",
      },
    })
    return
  end

  launcher.setResults(query, buildDrillResults(entry, filter))
end

local function runPassShow(entry, query)
  showState.entry = entry
  showState.loading = true
  showState.fetched = false
  showState.stdout = ""
  showState.stderr = ""
  showState.fields = {}

  publishDrillResults(query, entry, "")

  noctalia.runAsync("pass show " .. shellEscape(entry), function(result)
    if showState.entry ~= entry then
      return
    end

    showState.loading = false
    showState.fetched = true

    if result.exitCode ~= 0 then
      local err = result.stderr or ""
      if err == "" then
        err = noctalia.tr("notification.show_failed")
      end
      showState.stderr = err
      showState.stdout = ""
      showState.fields = {}
    else
      showState.stderr = ""
      showState.stdout = result.stdout or ""
      showState.fields = parseFields(showState.stdout)
    end

    local currentEntry, filter, isDrill = splitDrillQuery(lastQuery)
    if isDrill and currentEntry == entry then
      publishDrillResults(lastQuery, entry, filter)
    end
  end)
end

noctalia.state.watch("entries", function(value)
  entries = value or {}
end)

function onQuery(query)
  lastQuery = query

  local entry, filter, isDrill = splitDrillQuery(query)

  if isDrill then
    if entry == "" then
      launcher.setResults(query, {
        {
          id = "hint",
          title = noctalia.tr("launcher.pick_entry"),
          glyph = "key",
        },
      })
      return
    end

    if showState.entry ~= entry then
      runPassShow(entry, query)
      return
    end

    if not showState.fetched and not showState.loading then
      runPassShow(entry, query)
      return
    end

    publishDrillResults(query, entry, filter)
    return
  end

  local search = trim(query)
  local results = {}

  for _, item in ipairs(entries) do
    if wordMatch(search, item.path) then
      if isOtpPath(item.path) then
        local subtitle = item.subtitle ~= "" and item.subtitle or nil
        table.insert(results, {
          id = "otp:" .. item.path,
          title = noctalia.tr("launcher.otp_title", { title = item.title }),
          subtitle = subtitle,
          glyph = "123",
          score = 1,
        })
      else
        local subtitle = item.subtitle ~= "" and item.subtitle or nil
        table.insert(results, {
          id = "open:" .. item.path,
          title = item.title,
          subtitle = subtitle,
          glyph = "key",
          score = 1,
        })
      end
    end
  end

  launcher.setResults(query, results)
end

local function copyWithPass(command, path, successMessage)
  local escaped = shellEscape(path)

  noctalia.runAsync(command .. " " .. escaped, function(result)
    if result.exitCode == 0 then
      noctalia.notify("Pass", successMessage)
      pasteClipboard()
      return
    end

    local stderr = result.stderr or ""
    local err = stderr:lower()

    if err:find("gpg") then
      noctalia.notify("Pass", noctalia.tr("notification.unlocking"))
      noctalia.runInTerminal(command .. " " .. escaped)
      return
    end

    if err == "" then
      err = noctalia.tr("notification.copy_failed")
    else
      err = stderr
    end

    noctalia.notifyError("Pass", err)
  end)
end

function onActivate(id)
  if id == "loading" or id == "error" or id == "hint" then
    return
  end

  local action, rest = id:match("^([^:]+):(.+)$")

  if action == "open" then
    -- Host prepends this provider's prefix; stay in drill-in mode.
    launcher.setQuery(rest .. " | ")
    return
  end

  if action == "otp" then
    copyWithPass("pass otp -c", rest, noctalia.tr("notification.otp_copied"))
    return
  end

  if action == "password" then
    if isOtpPath(rest) then
      copyWithPass("pass otp -c", rest, noctalia.tr("notification.otp_copied"))
    else
      copyWithPass("pass -c", rest, noctalia.tr("notification.copied"))
    end
    return
  end

  if action == "field" then
    local index = tonumber(rest)
    local field = index and showState.fields[index]

    if not field then
      noctalia.notifyError("Pass", noctalia.tr("notification.copy_failed"))
      return
    end

    noctalia.copyToClipboard(field.value, "text/plain")
    noctalia.notify("Pass", noctalia.tr("notification.field_copied"))
    pasteClipboard()
  end
end
