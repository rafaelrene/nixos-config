{ pkgs, ... }:
{
  packages = with pkgs; [
    # Nix itself comes from the host installation, which owns the daemon/store.
    nixd
    nixfmt
    statix
    deadnix

    # Existing shell helpers, Nushell configuration, Lua config and Python tests.
    bashInteractive
    zsh
    nushell
    lua
    neovim-unwrapped
    python3
    shellcheck
    shfmt
    stylua
    ruff
    treefmt
    taplo
    prettier

    # Repository maintenance and the utilities used by existing helpers.
    git
    ripgrep
    jq
    curl
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    fzf
    openssh
    age
  ];
}
