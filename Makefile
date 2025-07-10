# Remember: this file cannot have any leading spaces before the commands, only tabs.

# Update the flake. Which will update available nix packages and their versions.
update:
	sudo nix flake update --flake ~/repos/personal/dotfiles

build:
	nh os build

# Create a new generation. Must reboot PC to switch to it.
boot:
	nh os boot

# Create a new generation and switch to it. For small changes this is fine, but anything large and nixos might not be able to swap to the new generation without a reboot.
switch:
	nh os switch

# Update system ephemerally, meaning it will not make a new generation in the boot order.
test:
	nh os test

fmt:
	nixpkgs-fmt **/*.nix && nix shell nixpkgs\#statix -c statix fix .

lint:
	nix shell nixpkgs\#statix -c statix check .

# FIXME: error: "error loading config: no matching creation rules found"
edit-secrets:
	nix shell nixpkgs\#sops -c sops ~/repos/personal/dotfiles/secrets/secrets.yaml

list-generations:
	nixos-rebuild list-generations

# This will remove all generations except the latest one. Use with caution.
clean:
	nh clean all -a --keep 1

# This is ran automatically via our config, but we can run it manually like this.
gc:
	nix-collect-garbage -d
