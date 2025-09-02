# 'Darwin' or 'Linux'
OS := $(shell uname -s)
ifeq ($(OS),Darwin)
  MAKEFILE_PATH = ~/repos/personal/dotfiles/darwin
else
  MAKEFILE_PATH = ~/repos/personal/dotfiles/linux
endif

fmt:
	nixpkgs-fmt . && nix shell nixpkgs\#statix -c statix fix .

lint:
	nix shell nixpkgs\#statix -c statix check .

edit-secrets:
	nix shell nixpkgs\#sops -c sops ~/repos/personal/dotfiles/secrets/secrets.yaml

# This is ran automatically via our config, but we can run it manually like this.
gc:
	nix-collect-garbage -d

# TODO: look into just using `nh` for both nix-darwin and linux.
# Delegate to the appropriate Makefile based on the OS.
%:
	$(MAKE) -C $(MAKEFILE_PATH) $@
