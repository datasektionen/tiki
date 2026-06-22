{
  description = "A Nix-flake-based Elixir development environment for Tiki";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [ inputs.treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      flake = {
        overlays.default =
          final: prev:
          let
            # use latest version of Erlang 28
            erlang = final.beam.interpreters.erlang_28;
            pkgs-beam = final.beam.packagesWith erlang;
          in
          {
            # use latest version of Elixir 1.19
            elixir = pkgs-beam.elixir_1_19;
          };
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          treefmt = {
            programs.nixfmt.enable = true;
            programs.mix-format = {
              enable = true;
              package = pkgs.elixir;
            };
            programs.prettier.enable = true;
          };

          devShells.default = pkgs.mkShellNoCC {
            packages =
              with pkgs;
              [
                elixir
                git
                nodejs_latest
                stripe-cli
                config.formatter
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
                inotify-tools
                libnotify
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
                terminal-notifier
              ];
          };
        };
    };
}
