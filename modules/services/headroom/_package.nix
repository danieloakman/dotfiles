# Headroom CLI via pinned uvx (PyPI). Avoids packaging the full Python/Rust tree
# in Nix; first run caches the tool under the user's uv cache.
{ lib
, writeShellApplication
, uv
, python313
, rtk
, stdenv
, ...
}:
let
  # PyPI CLI version; independent of the Docker image tag in headroom.linux.nix.
  version = "0.32.1";
  extras = "proxy,code,mcp";
  # uvx wheels (onnxruntime) are not Nix-patched; Kompress needs libstdc++ at
  # import time. Without this, `is_kompress_available()` is false, large
  # compressions hit the 30s deadline, and the proxy quarantines forever.
  libPath = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
in
writeShellApplication {
  name = "headroom";
  runtimeInputs = [
    uv
    python313
    # On PATH so the proxy's savings footer detects rtk (shutil.which("rtk")).
    rtk
  ];
  text = ''
    export UV_PYTHON=${python313}/bin/python3
    export LD_LIBRARY_PATH=${libPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec uvx --from "headroom-ai[${extras}]==${version}" headroom "$@"
  '';
  meta = with lib; {
    description = "Headroom CLI — context compression for LLM agents";
    homepage = "https://headroomlabs.ai";
    license = licenses.asl20;
    mainProgram = "headroom";
    platforms = platforms.linux;
  };
}
