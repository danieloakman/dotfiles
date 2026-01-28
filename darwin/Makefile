update:
	sudo nix flake update --flake .

build:
	sudo darwin-rebuild build --flake .

switch:
	sudo darwin-rebuild switch --flake .

boot:
	@echo "darwin-rebuild does not have a boot command, use switch instead" && exit 1

list-generations:
	sudo darwin-rebuild --list-generations --flake .
