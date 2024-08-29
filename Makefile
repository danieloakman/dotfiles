# Remember: this file cannot have any leading spaces before the commands, only tabs.

fmt:
	nixpkgs-fmt **/*.nix && nix shell nixpkgs\#statix -c statix fix .

lint:
	nix shell nixpkgs\#statix -c statix check .

# FIXME: error: "error loading config: no matching creation rules found"
# edit-secrets:
# 	nix shell nixpkgs\#sops -c sops ~/repos/personal/dotfiles/secrets/secret.yaml

update:
	sudo nix flake update ~/repos/personal/dotfiles
