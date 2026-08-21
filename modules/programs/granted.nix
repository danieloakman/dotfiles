# AWS Granted / assume. Always on.
#
# On servers (no local browser), DefaultBrowser=STDOUT so `assume -c` / console
# flows print a URL you can open on the machine you're SSHing from. Elsewhere
# default to Vivaldi. SSO login already uses device code in headless/SSH
# sessions (prints a URL + user code).
#
# Config must be a mutable file: Granted opens ~/.granted/config with O_RDWR, so
# a home-manager store symlink fails with "permission denied".
{ env, lib, pkgs, ... }:
let
  isServer = env.deviceType == "server";

  vivaldiPath = env.selectPlatform {
    linux = lib.getExe pkgs.vivaldi;
    darwin = "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi";
  };

  grantedConfig =
    if isServer then
      ''
        DefaultBrowser = "STDOUT"
        CustomBrowserPath = ""
        CustomSSOBrowserPath = ""
        Ordering = ""
      ''
    else
      ''
        DefaultBrowser = "VIVALDI"
        CustomBrowserPath = "${vivaldiPath}"
        CustomSSOBrowserPath = "${vivaldiPath}"
        Ordering = ""
      '';
in
{
  home-manager.users.${env.user} =
    { lib, ... }:
    {
      home = {
        sessionVariables.GRANTED_ALIAS_CONFIGURED = "true";

        activation.grantedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p ${env.home}/.granted
          $DRY_RUN_CMD rm -f ${env.home}/.granted/config
          $DRY_RUN_CMD printf '%s' ${lib.escapeShellArg grantedConfig} > ${env.home}/.granted/config
          $DRY_RUN_CMD chmod 600 ${env.home}/.granted/config
        '';
      };

      programs = {
        zsh = {
          envExtra = ''
            fpath=(${env.home}/.dgranted/zsh_autocomplete/assume/ $fpath)
            fpath=(${env.home}/.dgranted/zsh_autocomplete/granted/ $fpath)
          '';
        };

        granted = {
          enable = true;
          enableZshIntegration = true;
        };
      };
    };
}
