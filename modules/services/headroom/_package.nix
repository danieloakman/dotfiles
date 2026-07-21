# Headroom CLI via pinned uvx (PyPI). Avoids packaging the full Python/Rust tree
# in Nix; first run caches the tool under the user's uv cache.
{
  lib,
  writeShellApplication,
  uv,
  python313,
  ...
}:
let
  # PyPI CLI version; independent of the Docker image tag in headroom.linux.nix.
  version = "0.32.1";
  extras = "proxy,code,mcp";
in
writeShellApplication {
  name = "headroom";
  runtimeInputs = [
    uv
    python313
  ];
  text = ''
    export UV_PYTHON=${python313}/bin/python3
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
