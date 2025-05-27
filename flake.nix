{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {system, ...}: let
        pkgs = import nixpkgs {inherit system;};

        # Full TeX Live so we never chase missing packages
        tex = pkgs.texlive.combine {inherit (pkgs.texlive) scheme-full latexmk;};

        resume = pkgs.stdenvNoCC.mkDerivation {
          pname = "aly-raffauf-resume";
          version =
            if self ? shortRev
            then "git-${self.shortRev}"
            else "dev";
          src = self;
          buildInputs = [tex];
          buildPhase = ''latexmk -pdf -halt-on-error resume.tex'';
          installPhase = ''mkdir -p $out; cp *.pdf $out/'';
        };
      in {
        packages.default = resume;

        formatter = pkgs.writeShellApplication {
          name = "fmt";

          runtimeInputs = with pkgs; [
            alejandra
            nodePackages.prettier
            tex-fmt
          ];

          text = ''
            set -euo pipefail

            CHECK=false
            if [[ ''${1:-} == "-c" ]]; then CHECK=true; fi

            if $CHECK; then
              ALEJ_ARGS=(-c)
              PRETTIER_ARGS+=("--check")
              TEXFMT_ARGS=(--check)
            else
              ALEJ_ARGS=()
              PRETTIER_ARGS+=("--write")
              TEXFMT_ARGS=()
            fi

            find . -type f -name "*.md" -exec prettier "''${PRETTIER_ARGS[@]}" {} +
            find . -type f -name "*.yml" -exec prettier "''${PRETTIER_ARGS[@]}" {} +
            find . -type f -name "*.json" -exec prettier "''${PRETTIER_ARGS[@]}" {} +
            find . -type f -name '*.nix' -exec alejandra "''${ALEJ_ARGS[@]}" {} +
            find . -type f -name '*.tex' -exec tex-fmt "''${TEXFMT_ARGS[@]}" {} +
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
            nixd
            nodePackages.prettier
            tex-fmt
          ];
        };
      };
    };
}
