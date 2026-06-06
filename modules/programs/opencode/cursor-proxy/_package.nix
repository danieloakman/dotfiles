{
  lib,
  stdenv,
  esbuild,
  typescript,
  fetchurl,
  ...
}:
let
  typesNode = fetchurl {
    url = "https://registry.npmjs.org/@types/node/-/node-25.3.2.tgz";
    hash = "sha512-RpV6r/ij22zRRdyBPcxDeKAzH43phWVKEjL2iksqo1Vz3CuBUrgmPpPhALKiRfU7OMCmeeO9vECBMsV0hMTG8Q==";
  };
  undiciTypes = fetchurl {
    url = "https://registry.npmjs.org/undici-types/-/undici-types-7.18.2.tgz";
    hash = "sha512-AsuCzffGHJybSaRrmr5eHr81mwJU3kjw6M+uprWvCXiNeN9SOGwQ3Jn8jb8m3Z6izVgknn1R0FTCEAP2QrLY/w==";
  };
in
stdenv.mkDerivation {
  pname = "opencode-cursor-proxy";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [
    esbuild
    typescript
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    mkdir -p node_modules/@types/node node_modules/undici-types
    tar -xzf ${typesNode} -C node_modules/@types/node --strip-components=1
    tar -xzf ${undiciTypes} -C node_modules/undici-types --strip-components=1

    tsc -p tsconfig.json --noEmit

    esbuild src/cursor-proxy.ts \
      --bundle --platform=node --format=cjs --target=node20 \
      --outfile=cursor-proxy.cjs --packages=external \
      --banner:js='#!/usr/bin/env node'

    esbuild src/cursor-proxy-plugin.ts \
      --bundle --platform=node --format=esm --target=node20 \
      --outfile=cursor-proxy-plugin.mjs --packages=external

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp cursor-proxy.cjs cursor-proxy-plugin.mjs $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode Cursor ACP proxy (TypeScript, esbuild)";
  };
}
