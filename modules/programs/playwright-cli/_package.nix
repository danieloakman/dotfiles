# Agent-oriented Playwright CLI (@playwright/cli).
# Pinned to 0.1.19 so the vendored Playwright matches nixpkgs playwright-driver 1.63.x.
{ lib
, buildNpmPackage
, fetchFromGitHub
, makeBinaryWrapper
, playwright-driver
, versionCheckHook
}:

buildNpmPackage (finalAttrs: {
  pname = "playwright-cli";
  version = "0.1.19";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pbv51ybubbjoIpKg0k7lfXfZ9Z+qdZI2lRhQeI+/mFA=";
  };

  npmDepsHash = "sha256-aY3i+sc2p8iQAEpfs+j/ifeBVmMpDDmwctEqOIDmCqI=";

  dontNpmBuild = true;

  # Keep npm-vendored playwright: nixpkgs playwright-test does not export
  # playwright/lib/cli/client/program that this CLI imports.
  nativeBuildInputs = [ makeBinaryWrapper ];

  postInstall = ''
    # Ensure the agent skill tree is present even if npm packing omits it.
    skill_dst="$out/lib/node_modules/@playwright/cli/skills/playwright-cli"
    if [ ! -f "$skill_dst/SKILL.md" ]; then
      mkdir -p "$(dirname "$skill_dst")"
      cp -R ${finalAttrs.src}/skills/playwright-cli "$skill_dst"
    fi
  '';

  postFixup = ''
    wrapProgram $out/bin/playwright-cli \
      --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers} \
      --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true \
      --set-default PLAYWRIGHT_MCP_BROWSER chromium
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.skill = "${finalAttrs.finalPackage}/lib/node_modules/@playwright/cli/skills/playwright-cli";

  meta = {
    description = "Playwright CLI for coding-agent browser automation";
    homepage = "https://github.com/microsoft/playwright-cli";
    changelog = "https://github.com/microsoft/playwright-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "playwright-cli";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})
