{ copyparty, ... }: {
  imports = [ copyparty.nixosModules.default ];

  services.copyparty = {
    enable = true;
  };
}
