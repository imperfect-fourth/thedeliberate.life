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

        hugoBuild = pkgs.writeShellApplication {
          name = "build";
          runtimeInputs = [ pkgs.hugo pkgs.dart-sass ];
          text = "hugo build";
        };

        hugoServe = pkgs.writeShellApplication {
          name = "serve";
          runtimeInputs = [ pkgs.hugo pkgs.dart-sass ];
          text = "hugo serve --buildDrafts";
        };
      in {
        apps = {
          build = flake-utils.lib.mkApp { drv = hugoBuild; };
          serve = flake-utils.lib.mkApp { drv = hugoServe; };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hugo
            dart-sass
          ];

          shellHook = ''
            echo "Hugo: $(hugo version)"
            echo "Sass: $(sass --version)"
            alias build="${hugoBuild}/bin/build"
            alias serve="${hugoServe}/bin/serve"
          '';
        };
      }
    );
}
