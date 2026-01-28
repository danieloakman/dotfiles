# Reverse proxy:
_:
let
  user = "caddy";
in
{
  services = {
    caddy = {
      inherit user;
      enable = true;
    };

    tailscale.permitCertUid = user;
  };
}
