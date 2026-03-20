{
  description = "MagicTap – tap-to-click for Apple Magic Mouse";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "magic-tap";

          packages = with pkgs; [
            # Backend
            zig
            zls # Zig Language Server

            # Tooling
            just
          ];

          shellHook = ''
            echo "MagicTap dev shell"
            echo "  just build       – build backend + client"
            echo "  just run-backend – run Zig backend"
            echo "  just run-client  – run Swift client"
          '';
        };
      }
    );
}
