{
  description = "MagicTap – tap-to-click for Apple Magic Mouse";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" ];

      perSystem =
        { pkgs, ... }:
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
        };
    };
}
