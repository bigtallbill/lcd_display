{
  description = "LcdDisplay - Control Hitachi HD44780-compatible LCD displays in Elixir";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Define the Elixir and Erlang versions
        erlang = pkgs.erlang_27;
        elixir = pkgs.elixir_1_18.override { inherit erlang; };

        # Build the Elixir package as a library (not a release)
        lcdDisplay = pkgs.stdenv.mkDerivation {
          pname = "lcd_display";
          version = "0.2.0";

          src = ./.;

          buildInputs = [ elixir erlang ];

          buildPhase = ''
            export MIX_ENV=prod
            export MIX_HOME="$TMPDIR/.mix"
            export HEX_HOME="$TMPDIR/.hex"

            # Install hex and rebar3
            mix local.hex --force
            mix local.rebar3 --force

            # Get dependencies and compile
            mix deps.get
            mix compile

            # Generate docs
            mix docs
          '';

          installPhase = ''
            mkdir -p $out/lib/elixir
            cp -r _build/prod/lib/lcd_display $out/lib/elixir/

            # Install documentation
            mkdir -p $out/share/doc
            if [ -d "doc" ]; then
              cp -r doc $out/share/doc/lcd_display
            fi

            # Create a simple wrapper script
            mkdir -p $out/bin
            cat > $out/bin/lcd_display <<EOF
            #!${pkgs.bash}/bin/bash
            export ERL_LIBS="$out/lib/elixir:\$ERL_LIBS"
            exec ${elixir}/bin/iex -S mix
            EOF
            chmod +x $out/bin/lcd_display
          '';

          meta = with pkgs.lib; {
            description = "Use character liquid crystal display (LCD) in Elixir";
            homepage = "https://github.com/mnishiguchi/lcd_display";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

      in
      {
        packages = {
          default = lcdDisplay;
          lcd_display = lcdDisplay;
        };

        # Development shell with all necessary tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Elixir and Erlang
            elixir_1_18
            erlang_27

            # Development tools
            mix2nix  # For generating mix dependencies
            hex2nix  # Alternative tool for hex dependencies

            # Documentation generation
            gnumake

            # Git for version control
            git

            # Optional: tools for embedded development if targeting Nerves
            fwup
            squashfs-tools-ng

            # Build tools that might be needed by native dependencies
            gcc
            pkg-config

            # For I2C/SPI/GPIO functionality (if running on real hardware)
            i2c-tools
          ];

          # Environment variables
          shellHook = ''
            echo "🚀 Welcome to the LcdDisplay development environment!"
            echo "📦 Elixir version: $(elixir --version | head -1)"
            echo "🔧 Available commands:"
            echo "  mix deps.get    - Install dependencies"
            echo "  mix compile     - Compile the project"
            echo "  mix test        - Run tests"
            echo "  mix docs        - Generate documentation"
            echo "  mix format      - Format code"
            echo "  mix credo       - Run code analysis"
            echo "  mix dialyzer    - Run type analysis"
            echo ""

            # Set up mix for local development
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME"

            # Ensure mix and hex are available
            mix local.hex --force --if-missing
            mix local.rebar3 --force --if-missing
          '';

          # Set ERL_AFLAGS for better development experience
          ERL_AFLAGS = "-kernel shell_history enabled";
        };

        # Application for running the library in different contexts
        apps.default = {
          type = "app";
          program = "${lcdDisplay}/bin/lcd_display";
        };

        # Checks to run during CI/development
        checks = {
          # Format check
          format = pkgs.stdenv.mkDerivation {
            name = "check-format";
            src = ./.;
            buildInputs = [ elixir erlang ];
            buildPhase = ''
              export MIX_HOME="$TMPDIR/.mix"
              export HEX_HOME="$TMPDIR/.hex"
              mix local.hex --force
              mix format --check-formatted
            '';
            installPhase = "touch $out";
          };

          # Compile check
          compile = pkgs.stdenv.mkDerivation {
            name = "check-compile";
            src = ./.;
            buildInputs = [ elixir erlang ];
            buildPhase = ''
              export MIX_ENV=test
              export MIX_HOME="$TMPDIR/.mix"
              export HEX_HOME="$TMPDIR/.hex"
              mix local.hex --force
              mix local.rebar3 --force
              mix deps.get
              mix compile --warnings-as-errors
            '';
            installPhase = "touch $out";
          };

          # Test check
          test = pkgs.stdenv.mkDerivation {
            name = "check-test";
            src = ./.;
            buildInputs = [ elixir erlang ];
            buildPhase = ''
              export MIX_ENV=test
              export MIX_HOME="$TMPDIR/.mix"
              export HEX_HOME="$TMPDIR/.hex"
              mix local.hex --force
              mix local.rebar3 --force
              mix deps.get
              mix test
            '';
            installPhase = "touch $out";
          };
        };

        # Formatter for the flake itself
        formatter = pkgs.nixpkgs-fmt;
      });
}
