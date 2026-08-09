# Bun scripts package (formerly a nested flake). Consumed via pkgs.callPackage.
{ lib
, stdenv
, bun
, makeWrapper
, poppler-utils
, fzf
, playwright-driver
, bun2nix
, ...
}:
let
  system = stdenv.hostPlatform.system;
  fetchBunDeps = bun2nix.packages.${system}.default.fetchBunDeps;
  hook = bun2nix.packages.${system}.default.hook;
  otherPackages = [
    poppler-utils # Provides `pdftotext`
    fzf
  ];
in
stdenv.mkDerivation {
  pname = "bun-scripts";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ hook bun makeWrapper ] ++ otherPackages;

  bunDeps = fetchBunDeps { bunNix = ./_bun.nix; };

  buildPhase = ''
    bun run build
  '';

  installPhase = ''
    mkdir -p $out/dist $out/bin $out/src/db $out/src/utils
    cp -R ./dist/* $out/dist/
    cp -rL ./node_modules $out/node_modules
    cp package.json drizzle.config.ts $out/
    cp src/db/schema.ts $out/src/db/
    cp src/utils/env.ts $out/src/utils/
    # Match both flat (dist/foo.js) and nested (dist/src/foo.js) bun build layouts.
    mapfile -t js_files < <(find "$out/dist" -type f -name '*.js' | sort)
    if [ ''${#js_files[@]} -eq 0 ]; then
      echo "error: no JS entrypoints found under $out/dist" >&2
      find "$out/dist" -type f >&2 || true
      exit 1
    fi
    for f in "''${js_files[@]}"; do
      name=$(basename "$f" .js)
      makeWrapper ${lib.getExe bun} $out/bin/$name \
        --add-flags "run" --add-flags "$f" \
        --prefix PATH : ${lib.makeBinPath otherPackages} \
        --set NODE_PATH "$out" \
        --set BUN_SCRIPTS_ROOT "$out" \
        --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true \
        --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
        --argv0 "$name"
    done
  '';

  meta = with lib; {
    description = "Personal bun scripts package";
    platforms = platforms.linux;
  };
}
