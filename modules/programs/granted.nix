# AWS Granted / assume. Always on.
#
# On servers (no local browser), DefaultBrowser=STDOUT so `assume -c` / console
# flows print a URL you can open on the machine you're SSHing from. Elsewhere
# default to Vivaldi. SSO login already uses device code in headless/SSH
# sessions (prints a URL + user code).
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
  home-manager.users.${env.user} = {
    home = {
      sessionVariables.GRANTED_ALIAS_CONFIGURED = "true";
      file.".granted/config".text = grantedConfig;
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
