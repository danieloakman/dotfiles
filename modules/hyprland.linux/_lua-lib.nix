# Thin helpers over Home Manager's Hyprland Lua settings API (`_args`, `_var`, mkLuaInline).
{ lib }:
let
  inherit (lib.generators) mkLuaInline toLua;
  toLuaExpr = toLua { };

  args = list: { _args = list; };
in
rec {
  inherit args;

  var = value: { _var = value; };

  # Key chord that prefixes the Lua `mod` local, e.g. mod .. " + Q"
  key = k: mkLuaInline "mod .. \" + ${k}\"";
  keyShift = k: mkLuaInline "mod .. \" + SHIFT + ${k}\"";

  bind = keyChord: handler: args [ keyChord handler ];
  bindFlags = keyChord: handler: flags: args [ keyChord handler flags ];
  bindl = keyChord: handler: bindFlags keyChord handler { locked = true; };
  bindr = keyChord: handler: bindFlags keyChord handler { release = true; };
  bindm = keyChord: handler: bindFlags keyChord handler { mouse = true; };

  exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${toLuaExpr cmd})";
  execRules = cmd: rules: mkLuaInline "hl.dsp.exec_cmd(${toLuaExpr cmd}, ${toLuaExpr rules})";

  close = mkLuaInline "hl.dsp.window.close()";
  kill = mkLuaInline "hl.dsp.window.kill()";
  floatToggle = mkLuaInline "hl.dsp.window.float({ action = \"toggle\" })";
  focusDir = dir: mkLuaInline "hl.dsp.focus({ direction = ${toLuaExpr dir} })";
  focusWs = ws: mkLuaInline "hl.dsp.focus({ workspace = ${toLuaExpr ws} })";
  moveToWs = ws: mkLuaInline "hl.dsp.window.move({ workspace = ${toLuaExpr ws} })";
  toggleSpecial = name: mkLuaInline "hl.dsp.workspace.toggle_special(${toLuaExpr name})";
  drag = mkLuaInline "hl.dsp.window.drag()";
  resize = mkLuaInline "hl.dsp.window.resize()";

  # One `hl.on("hyprland.start", ...)` entry that runs the given shell commands.
  onStart = cmds: args [
    "hyprland.start"
    (mkLuaInline (
      ''
        function()
      ''
      + lib.concatMapStrings (cmd: "  hl.exec_cmd(${toLuaExpr cmd})\n") cmds
      + "end"
    ))
  ];
}
