{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  checkout = config.workstation.checkout;
  home = config.users.users.${config.system.primaryUser}.home;
  theme = import ../../themes { inherit lib pkgs; };
  deltaConfig = pkgs.writeText "delta.gitconfig" (lib.generators.toGitINI { inherit (theme) delta; });
in
{
  environment.systemPackages = [
    (import ../applications/neovim/package.nix { inherit inputs lib pkgs; })
  ];
  environment.etc = {
    "xdg/nvim-theme.json".text = builtins.toJSON theme.neovim;
    "xdg/ghostty/theme".text = import ../applications/ghostty/theme.nix { inherit lib pkgs; };
  };
  workstation = {
    legacyDirectories = {
      ".config/git" = "/roles/git/files";
      ".config/ghostty" = "/roles/ghostty/files";
      ".config/tealdeer" = "/roles/tealdeer/files";
      ".config/graphite" = "/roles/graphite/files";
      ".config/try-rs" = "/roles/try-rs/files";
    };
    links = {
      ".config/git/config" = "${checkout}/modules/development/git/config";
      ".config/git/ignore" = "${checkout}/modules/development/git/ignore";
      ".config/git/themes.gitconfig" = toString deltaConfig;
      ".config/nvim" = "${checkout}/modules/applications/neovim/config";
      ".config/ghostty/config" = "${checkout}/modules/darwin/ghostty.config";
      ".config/tealdeer/config.toml" = toString ../applications/tealdeer/config.toml;
      ".config/graphite/aliases" = "${checkout}/modules/darwin/graphite-aliases";
      ".config/try-rs/config.toml" = toString (
        (pkgs.formats.toml { }).generate "try-rs.toml" {
          tries_path = "${home}/code/.personal/.try";
          theme = theme.name;
          editor = "nvim";
          apply_date_prefix = true;
          transparent_background = true;
          show_disk = true;
          show_preview = true;
          show_legend = true;
          show_right_panel = true;
          right_panel_width = 25;
        }
      );
      ".ssh/config" = "${checkout}/modules/darwin/ssh.config";
      ".local/share/raycast/scripts" = "${checkout}/modules/darwin/web-apps";
    };
    legacyLinks = {
      ".config/nvim" = "/roles/nvim/files/nvim";
      ".ssh/config" = "/roles/ssh/files/config";
    };
  };
}
