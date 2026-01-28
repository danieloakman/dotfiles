_:
let
  port = "9090";
in
{
  services.cockpit = {
    enable = true;
    openFirewall = true;
    # settings = {};
    allowed-origins = [
      "https://mara:${port}"
    ];
  };
}
