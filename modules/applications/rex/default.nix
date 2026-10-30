{ config, ... }:
{
  flake.modules.darwin.rex = { pkgs, ... }: {
    environment.systemPackages = [
      (config.features.rex.package { inherit pkgs; })
    ];
    # Rex forces update checks; updates require an explicit install choice.
    # https://www.superlogical.com/rex/docs/reference/privacy
    system.defaults.CustomUserPreferences."com.superlogical.rex".SUAutomaticallyUpdate = false;
  };
}
