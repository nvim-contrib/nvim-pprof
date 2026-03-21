{
  description = "nvim-pprof - Go pprof profiler integration for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        plugins = with pkgs.vimPlugins; [
          plenary-nvim
        ];

        luaPathEntries = pkgs.lib.concatStringsSep ";" (
          pkgs.lib.flatten (map (p: [ "${p}/lua/?.lua" "${p}/lua/?/init.lua" ]) plugins)
        );

        neovimForTests = pkgs.writeShellScriptBin "nvim" ''
          export LUA_PATH="${luaPathEntries};''${LUA_PATH:-}"
          exec ${pkgs.neovim}/bin/nvim \
            ${pkgs.lib.concatMapStringsSep " \\\n            "
              (p: "--cmd \"set runtimepath^=${p}\"")
              plugins} \
            "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "nvim-pprof";
          packages = [
            neovimForTests
          ];
        };
      });
}
