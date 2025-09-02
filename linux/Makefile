# Update the flake. Which will update available nix packages and their versions.
update:
	sudo nix flake update --flake .

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

list-generations:
	nixos-rebuild list-generations

# This will remove all generations except the latest one. Use with caution.
clean:
	nh clean all -a --keep 1
