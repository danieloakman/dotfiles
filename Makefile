# Remember: this file cannot have any leading spaces before the commands, only tabs.

fmt:
	nixpkgs-fmt **/*.nix

lint:
	nix shell nixpkgs\#statix -c statix check .
