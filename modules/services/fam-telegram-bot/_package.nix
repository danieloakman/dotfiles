{ rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "fam-telegram-bot";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  meta.mainProgram = "fam-telegram-bot";
}
