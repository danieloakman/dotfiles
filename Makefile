# Remember: this file cannot have any leading spaces before the commands, only tabs.

fmt:
	nixpkgs-fmt **/*.nix && nix shell nixpkgs\#statix -c statix fix .

lint:
	nix shell nixpkgs\#statix -c statix check .

edit-secrets:
	nix shell nixpkgs\#sops -c sops secrets/secret.yaml
