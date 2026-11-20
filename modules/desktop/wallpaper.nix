{ config, ... }:
let
  source = ../../wallpapers;
  files = builtins.readDir source;
  originals = builtins.filter (
    name:
    files.${name} == "regular"
    && builtins.match ".*\\.(jpg|jpeg|png|webp)" name != null
    && builtins.match ".*-[0-9]+x[0-9]+\\.[^.]+" name == null
  ) (builtins.attrNames files);
  catalog =
    pkgs: resolution:
    pkgs.linkFarm "wallpapers" (
      map (
        original:
        let
          parts = builtins.match "(.*)\\.([^.]+)" original;
          variant = "${builtins.elemAt parts 0}-${toString resolution}.${builtins.elemAt parts 1}";
          name = if resolution != null && files.${variant} or null == "regular" then variant else original;
        in
        {
          inherit name;
          path = source + "/${name}";
        }
      ) originals
    );
  desktopSession = (config.features.modulesFor "darwin").desktop-session;
in
{
  flake.modules = {
    nixos.wallpaper =
      { config, pkgs, ... }:
      let
        user = config.workstation.user;
        inherit (config.users.users.${user}) home group;
        wallpapers = catalog pkgs (config.workstation.niri.displayResolution or null);
      in
      {
        systemd.tmpfiles.rules = [
          "d ${home}/Pictures 0755 ${user} ${group} - -"
          "L+ ${home}/Pictures/Wallpapers - - - - ${wallpapers}"
        ];
      };

    darwin.wallpaper =
      { pkgs, ... }:
      let
        wallpapers = catalog pkgs null;
      in
      {
        imports = [ desktopSession ];
        workstation = {
          links."Pictures/Wallpapers" = toString wallpapers;
          desktop.wallpaper = "${wallpapers}/akame-95y5rk.png";
        };
      };
  };
}
