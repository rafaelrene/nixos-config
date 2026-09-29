{
  flake.modules.darwin.skhd = {
    services.skhd = {
      enable = true;
      skhdConfig = ''
        alt - return : /usr/bin/open -a Ghostty "$HOME" --args --window-save-state=never
      '';
    };
  };
}
