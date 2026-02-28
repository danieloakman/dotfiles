{ bun2nix, system, pkgs, lib, config, ... }:
let
  # See: https://nix-community.github.io/bun2nix/building-packages
  fetchBunDeps = bun2nix.packages.${system}.default.fetchBunDeps;
  hook = bun2nix.packages.${system}.default.hook;
  builtDerivation = pkgs.stdenv.mkDerivation {
    pname = "bun-scripts";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = with pkgs; [
      hook
      bun
      makeWrapper
      gcalcli
      (writeShellScriptBin "gcalcli" ''
        CLIENT_ID=$(cat ${config.sops.secrets.google_client_id.path})
        CLIENT_SECRET=$(cat ${config.sops.secrets.google_client_secret.path})
        ${lib.getExe gcalcli} --client-id $CLIENT_ID --client-secret $CLIENT_SECRET
      '')
    ];

    bunDeps = fetchBunDeps {
      bunNix = ./bun.nix;
    };

    buildPhase = ''
      bun run build
    '';

    installPhase = ''
      mkdir -p $out/dist $out/bin
      cp -R ./dist/* $out/dist/
      for f in $out/dist/*.js; do
        name=$(basename "$f" .js)
        makeWrapper ${lib.getExe pkgs.bun} $out/bin/$name \
          --add-flags "run" --add-flags "$f" \
          --argv0 "$name"
      done
    '';
  };
in
{
  environment.systemPackages = [
    builtDerivation
  ];
}
