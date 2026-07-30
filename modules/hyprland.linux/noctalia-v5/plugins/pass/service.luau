--!nonstrict
-- Index password-store via async `find` so we stay under noctalia's update CPU budget.

local entries = {}
local scanning = false
local scanGeneration = 0

local function publish()
  noctalia.state.set("entries", entries)
end

local function shellEscape(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function passwordStoreDir()
  local dir = noctalia.getenv("PASSWORD_STORE_DIR")

  if dir and dir ~= "" then
    return noctalia.expandPath(dir)
  end

  return noctalia.expandPath("~/.password-store")
end

local function entryFromRelativePath(rel)
  -- find -printf '%P' yields paths like "otp/github.gpg" relative to the store root.
  if rel:sub(-4) ~= ".gpg" then
    return nil
  end

  local path = rel:sub(1, -5)
  local title = path
  local subtitle = ""
  local lastSlash = path:match("^.*()/")

  if lastSlash then
    subtitle = path:sub(1, lastSlash - 1)
    title = path:sub(lastSlash + 1)
  end

  return {
    id = path,
    path = path,
    title = title,
    subtitle = subtitle,
  }
end

local function parseFindStdout(stdout)
  local nextEntries = {}

  for line in stdout:gmatch("[^\r\n]+") do
    local entry = entryFromRelativePath(line)
    if entry then
      table.insert(nextEntries, entry)
    end
  end

  table.sort(nextEntries, function(a, b)
    return a.title:lower() < b.title:lower()
  end)

  return nextEntries
end

local function requestScan()
  if scanning then
    return
  end

  local root = passwordStoreDir()

  if not noctalia.fileExists(root) then
    entries = {}
    publish()
    noctalia.notifyError("Pass", noctalia.tr("notification.store_not_found"))
    return
  end

  scanning = true
  scanGeneration = scanGeneration + 1
  local generation = scanGeneration

  -- Resolve symlinks (e.g. ~/.password-store -> …/pwd-store). Plain `find` does not
  -- descend into a symlink root, and `-name '.*' -prune` would also match `.password-store`.
  local command = "root=$(readlink -f -- "
    .. shellEscape(root)
    .. ") && find \"$root\" -name '.*' -prune -o -type f -name '*.gpg' -printf '%P\\n'"

  noctalia.runAsync(command, function(result)
    if generation ~= scanGeneration then
      return
    end

    scanning = false

    if result.exitCode ~= 0 then
      noctalia.log("Pass scan failed: " .. tostring(result.stderr or result.exitCode))
      return
    end

    entries = parseFindStdout(result.stdout or "")
    noctalia.log("Pass indexed " .. tostring(#entries) .. " entries")
    publish()
  end)
end

function update()
  requestScan()
end

function onConfigChanged()
  local refresh = noctalia.getConfig("refresh_interval") or 60
  noctalia.setUpdateInterval(refresh * 1000)
  requestScan()
end

local refresh = noctalia.getConfig("refresh_interval") or 60

noctalia.setUpdateInterval(refresh * 1000)
requestScan()
