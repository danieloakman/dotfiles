# unoserver is not in nixpkgs (request: NixOS/nixpkgs#386056). Stirling-PDF 1.5.0
# shells out to `unoconvert` and talks to a running `unoserver` on port 2003.
{
  lib,
  python3Packages,
  fetchFromGitHub,
  libreoffice,
  libreoffice-unwrapped,
}:

let
  loProgram = "${libreoffice-unwrapped}/lib/libreoffice/program";
in
python3Packages.buildPythonApplication rec {
  pname = "unoserver";
  version = "3.7";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "unoconv";
    repo = "unoserver";
    tag = version;
    hash = "sha256-vG4RfqdrUjB7vcO6CBr8EjM1wtspzlDFWkfLkgViD+g=";
  };

  build-system = [ python3Packages.setuptools ];

  # Server needs LibreOffice's `uno` module; client (`unoconvert`) is XML-RPC only.
  # `--host-location remote` makes the client send file bytes instead of local
  # paths, so Stirling (DynamicUser) and unoserver can run as different users.
  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ libreoffice ]}"
    "--prefix PYTHONPATH : ${loProgram}"
    "--set-default UNO_PATH ${loProgram}"
    "--set-default URE_BOOTSTRAP vnd.sun.star.pathname:${loProgram}/fundamentalrc"
  ];

  postFixup = ''
    wrapProgram $out/bin/unoconvert --add-flags "--host-location remote"
  '';

  doCheck = false;

  meta = {
    description = "Server for file conversions with LibreOffice";
    homepage = "https://github.com/unoconv/unoserver";
    license = lib.licenses.mit;
    mainProgram = "unoserver";
    platforms = lib.platforms.linux;
  };
}
