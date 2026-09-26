{
  pkgs,
  home,
  code,
  hostname,
}:
let
  darwin = pkgs.stdenv.hostPlatform.isDarwin;
  settings = pkgs.writeText "workstation-destinations.json" (
    builtins.toJSON {
      inherit home code hostname;
      platform = if darwin then "darwin" else "linux";
      sshHosts = [
        "othinus"
        "proserpina"
      ];
      ssh = "${pkgs.openssh}/bin/ssh";
      ghostty = if darwin then "" else "${pkgs.ghostty}/bin/ghostty";
      appleScript = toString ./ghostty.applescript;
    }
  );
in
pkgs.writeShellApplication {
  name = "workstation-open";
  runtimeInputs = [
    pkgs.nushell
    pkgs.fd
  ]
  ++ pkgs.lib.optionals (!darwin) [
    pkgs.ghostty
    pkgs.niri
    pkgs.vicinae
  ];
  text = ''
    exec nu --no-config-file ${./launcher.nu} ${settings} "$@"
  '';
}
