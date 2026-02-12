{
  description = "thedeliberate.life";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hugo
            dart-sass
          ];

          # optional sanity check
          shellHook = ''
            echo "Hugo: $(hugo version)"
            echo "Sass: $(sass --version)"
          '';
        };
      }
    );
}
