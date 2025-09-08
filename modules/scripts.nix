# See: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/writers/scripts.nix for more script writers.
{ pkgs, ... }: {
  environment.systemPackages = [
    (pkgs.writers.writePython3Bin "move-mouse"
      {
        libraries = with pkgs; [ python3Packages.pyautogui ];
      } ''
      import pyautogui
      import argparse


      def main():
          parser = argparse.ArgumentParser(prog="Move-mouse", description="Moves the mouse.")
          parser.add_argument("x", type=int, help="x coordinate")
          parser.add_argument("y", type=int, help="y coordinate")
          parser.add_argument(
              "--duration", "-d", type=float, default=1, help="duration of the movement"
          )
          parser.add_argument(
              "--relative",
              "-r",
              action="store_true",
              help="move relative to the current position of the mouse",
          )
          args = parser.parse_args()

          if args.relative:
              pyautogui.move(args.x, args.y, duration=args.duration)
          else:
              pyautogui.moveTo(args.x, args.y, duration=args.duration)


      main()

    '')

    (pkgs.writers.writeJSBin "test-js-script" { } ''
      console.log("Hello, world!")
    '')
  ];
}
