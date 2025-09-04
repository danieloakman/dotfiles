{ env, pkgs, config, ... }:
let
  passwordStorePath = "${env.home}/.local/share/password-store";
in
{
  environment.systemPackages = with pkgs; [
    ((if env.isOnWayland then pass-wayland else pass).withExtensions (ext: with ext; [
      pass-otp
      pass-update
      pass-checkup
      pass-audit
    ]))
    (if env.isOnWayland then pass-wayland else pass)
  ];

  # Enables the `browserpass` extension for chromium, firefox, google-chrome, vivaldi browsers.
  programs.browserpass.enable = true;

  home-manager.users.${env.user} = {
    services.git-sync = {
      enable = true;
      repositories = {
        "password-store" = {
          interval = 60;
          path = passwordStorePath;
          uri = config.sops.secrets.password_store_git_url.path;
        };
      };
    };

    home.sessionVariables = {
      # TODO: Maybe move system level pass to home-manager, and we wouldn't need to do this
      PASSWORD_STORE_DIR = passwordStorePath;
    };
  };
}
