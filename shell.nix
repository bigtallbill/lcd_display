# shell.nix - Backward compatibility for non-flake Nix users
# This file provides the same development environment as the flake
# Usage: nix-shell

let
  # Import nixpkgs
  pkgs = import <nixpkgs> {};

  # Define Elixir and Erlang versions (same as in flake)
  erlang = pkgs.erlang_27;
  elixir = pkgs.elixir_1_18.override { inherit erlang; };

in pkgs.mkShell {
  buildInputs = with pkgs; [
    # Elixir and Erlang
    elixir_1_18
    erlang_27

    # Development tools
    mix2nix  # For generating mix dependencies

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
}
