{
  flake.modules.darwin.skhd = { config, ... }: {
    services.skhd = {
      enable = true;
      skhdConfig = ''
        alt - return : /usr/bin/open -a Ghostty "${
          config.users.users.${config.workstation.user}.home
        }" --args --window-save-state=never
      '';
    };
  };
}
