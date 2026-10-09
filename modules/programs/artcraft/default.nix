# ArtCraft crafting apps (storytold / getartcraft.com).
# Not in nixpkgs — packages come from upstream Linux release tarballs.
# The AI IDE (storytold/artcraft) has no Linux release binaries yet.
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.artcraft;

  craftPackages = pkgs.callPackage ./_package.nix { };

  # Crafting apps with Linux release packages (see _package.nix).
  craftApps = {
    photocraft = "PhotoCraft — image editor (Photoshop-style)";
    lightcraft = "LightCraft — photo library / raw developer (Lightroom-style)";
    filmcraft = "FilmCraft — video editor (Premiere-style)";
    pdfcraft = "PDFCraft — PDF viewer and editor (Acrobat-style)";
    vectorcraft = "VectorCraft — vector graphics (Illustrator-style)";
    effectcraft = "EffectCraft — motion graphics / VFX (After Effects-style)";
    designcraft = "DesignCraft — page layout (InDesign-style)";
    wordcraft = "WordCraft — word processor (Word-style)";
    cadcraft = "CADCraft — CAD drafting (AutoCAD-style)";
    gridcraft = "GridCraft — spreadsheet (Excel-style)";
    soundcraft = "SoundCraft — audio workstation (Pro Tools-style)";
    deckcraft = "DeckCraft — presentations (PowerPoint-style)";
  };

  enabledCraftPackages = lib.filterAttrs (name: _: cfg.${name}.enable) craftPackages;

  anyCraftEnabled = enabledCraftPackages != { };
  ideEnabled = cfg.ide.enable;
  anyEnabled = anyCraftEnabled || ideEnabled;
in
{
  options.my.programs.artcraft =
    {
      enable = lib.mkEnableOption ''
        Install every Linux-packaged ArtCraft crafting app (PhotoCraft, LightCraft, …).
        Individual apps can still be toggled; this sets their defaults to true.
      '';

      ide = {
        enable = lib.mkEnableOption ''
          ArtCraft AI IDE (storytold/artcraft). Upstream ships Windows/macOS builds only;
          enabling this on Linux currently fails an assertion (no release tarball yet).
        '';
      };
    }
    // lib.mapAttrs (
      _name: description: {
        enable = lib.mkEnableOption description;
      }
    ) craftApps;

  config = lib.mkMerge [
    {
      # `enable` turns on all crafting apps that have Linux packages.
      my.programs.artcraft = lib.mapAttrs (_: _: {
        enable = lib.mkDefault cfg.enable;
      }) craftApps;
    }
    (lib.mkIf anyEnabled (
      env.selectPlatform {
        linux = {
          assertions = [
            {
              assertion = !ideEnabled;
              message = ''
                my.programs.artcraft.ide.enable: the ArtCraft AI IDE has no Linux release
                binaries yet (Windows/macOS only). Build from source upstream, or disable
                my.programs.artcraft.ide.enable.
              '';
            }
          ];

          environment.systemPackages = lib.attrValues enabledCraftPackages;
        };
        darwin = {
          assertions = [
            {
              assertion = false;
              message = ''
                my.programs.artcraft: crafting-app packages are Linux release tarballs only.
                Disable my.programs.artcraft.* on Darwin, or install the .dmg from GitHub releases.
              '';
            }
          ];
        };
      }
    ))
  ];
}
