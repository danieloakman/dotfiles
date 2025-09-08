{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    comma # Can be used to run commands not installed in the system, on the fly, e.g. `, cowsay neat`
  ];

  # Enable nix-index which is required for comma commands to work:
  programs.nix-index.enable = true;
}
