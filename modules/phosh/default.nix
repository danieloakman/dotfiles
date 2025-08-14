{ env, ... }:
{
  services.xserver.desktopManager.phosh = {
    enable = true;
    user = env.user;
    group = "users";
  };
}
