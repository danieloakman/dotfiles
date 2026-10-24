{ rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "telegram-bot";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  meta.mainProgram = "telegram-bot";
}
