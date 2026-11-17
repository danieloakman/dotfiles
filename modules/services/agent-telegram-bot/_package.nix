{ rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "agent-telegram-bot";
  version = "0.1.0";
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  meta.mainProgram = "agent-telegram-bot";
}
