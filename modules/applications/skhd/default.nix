{
  flake.modules.darwin.skhd = {
    services.skhd = {
      enable = true;
      skhdConfig = ''
        alt - return : /usr/bin/open -na Ghostty --args --window-save-state=never
      '';
    };
  };
}
