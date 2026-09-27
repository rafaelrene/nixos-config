{
  flake.modules.devenv.development =
    { pkgs, ... }:
    {
      packages = with pkgs; [
        # Nix itself comes from the host installation, which owns the daemon/store.
        nixd
        nixfmt
        statix
        deadnix

        # Devenv supplies Bash; these support the repository's other config and tests.
        zsh
        nushell
        nufmt
        lua
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
    };
}
