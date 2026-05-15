import QtQuick
import qs.Commons
import Quickshell
import Quickshell.Io
import qs.Services.UI

Item {
  id: root

  // `Process.onExited` can run before `StdioCollector.onStreamFinished` (waitForEnd buffers
  // until EOF). Clearing loading there made `getResults` see empty stdout, fall through to
  // browse mode, and re-trigger `pass show` in a tight loop. Finish from stdout + a fallback.
  Timer {
    id: passShowLoadFallback
    interval: 150
    repeat: false
    onTriggered: {
      if (!root.passShowLoading)
        return
      root.passShowLoading = false
      root.launcher.updateResults()
    }
  }

  // Required properties
  property var pluginApi: null
  property var launcher: null

  readonly property var mainInst: pluginApi?.mainInstance
  readonly property string supportedLayouts: "list" 
  // readonly property var emptyBrowsingMessage: "No password entries found."
  readonly property bool ignoreDensity: false
  readonly property bool supportsAutoPaste: true // Allows auto pasting results into focused text inputs
  property string name: "Pass Menu"
  property string cmd: ">pass"
  property string passShowQuery: ""
  property string passShowStdout: ""
  property string passShowStderr: ""
  property bool passShowLoading: false

  function init() {
    mainInst.refreshEntries();
  }

  // Check if this provider handles the command
  function handleCommand(searchText) {
    return searchText.startsWith(cmd)
  }

  // Return available commands when user types ">"
  function commands() {
    return [{
      "name": cmd,
      "description": "Search pass entries",
      "icon": "search",
      "isTablerIcon": true,
      "onActivate": function() {
        launcher.setSearchText(`${cmd} `)
      }
    }]
  }

  // Get search results
  function getResults(searchText) {
    if (!searchText.startsWith(cmd)) {
      return []
    }
    var parts = searchText.slice(cmd.length).trim().split("|")
    var query = parts[0]?.trim() || ""
    var args = parts[1]?.trim()

    if (typeof args === "string" && query.length > 0) {
      const loadingResult = {
        name: "Loading...",
        hideIcon: true,
      }
      if (passShowQuery !== query) {
        runPassShow(query)
        return [loadingResult]
      }

      if (passShowLoading) return [loadingResult]
      if (passShowStderr.length) return [{
        name: passShowStderr,
        displayText: '🔴'
      }]
      if (passShowStdout.length) {
        const [pwd, ...results] = passShowStdout.trim().split("\n").filter(Boolean)
        return [
          {
            name: '*'.repeat(20),
            description: `Password for ${query}`,
            hideIcon: true,
            onActivate: function() {
              copyPassword(query)
              launcher.close()
            }
          },
          ...fuzzySearch(args, results)
            .map(line => {
              const colonIdx = line.indexOf(":")
              const key = line.slice(0, colonIdx).trim()
              const value = line.slice(colonIdx + 1).trim()
              return {
                name: value,
                description: key,
                hideIcon: true,
                provider: root,
                autoPasteText: value,
                onActivate: function() {
                  copyToClipboard(value)
                  launcher.close()
                }
              }
            })
        ]
      }

      if (passShowProc.running)
        return [loadingResult]
      return [{
        name: "No output from pass show",
        description: passShowStderr.length ? passShowStderr : query,
        hideIcon: true,
      }]
    }

    return fuzzySearch(query || "", mainInst.passEntries)
      .map(entry => ({
        name: entry,
        description: `Copy ${entry} to clipboard`,
        icon: "star",
        isTablerIcon: true,
        onActivate: function() {
          launcher.setSearchText(`${cmd} ${entry} | `)
        }
      }))
  }

  function fuzzySearch (query, list) {
    const queryWords = query.trim().split(' ').filter(Boolean)
    return list.filter((item) => {
      const itemWords = item.split(' ').filter(Boolean)
      return queryWords.every((word) => itemWords.some((e) => e.includes(word)))
    })
  }

  function copyPassword(name) {
    if (!name || name.length === 0) {
      return
    }
    Quickshell.execDetached([
      "zsh", "-c",
      `pass ${name.startsWith('otp') ? "otp" : ""} -c ${name}`,
    ])
    // Couldn't get to work:
    // Quickshell.execDetached(["zsh", "-c", `wtype ${name}`])
    ToastService.showNotice(pluginApi.tr("toast.title"), `${name} ` + pluginApi.tr("toast.copied"), 'key')
  }

  function copyToClipboard(text) {
    Quickshell.execDetached([
      "zsh", "-c",
      `wl-copy ${text}`,
    ])
  }

  function runPassShow(query) {
    if (passShowQuery === query) return
    if (passShowLoading) return

    passShowQuery = query
    passShowStdout = ""
    passShowStderr = ""
    passShowLoadFallback.stop()
    passShowLoading = true
    passShowProc.exec(["zsh", "-c", `pass show ${query}`])
  }

  Process {
    id: passShowProc
    running: false
    onExited: {
      if (root.passShowLoading)
        passShowLoadFallback.restart()
    }
    stdout: StdioCollector {
      onStreamFinished: {
        passShowLoadFallback.stop()
        root.passShowStdout = (this.text || "").trim()
        root.passShowLoading = false
        root.launcher.updateResults()
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        root.passShowStderr = (this.text || "").trim()
        root.launcher.updateResults()
      }
    }
  }
}
