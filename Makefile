fmt:
	nixpkgs-fmt **/*.nix

lint:
	nix shell nixpkgs\#statix -c statix check .
