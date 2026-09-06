{ lib, pkgs, ... }:

let
  profile = "/home/raf/.local/state/nix/profiles/llm-agents";
  flake = "github:numtide/llm-agents.nix";
  mkAgentWrapper =
    name:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.devenv
      ];
      text = ''
        real="${profile}/bin/${name}"
        if ! test -x "$real"; then
          echo "${name} is not installed yet. Run: systemctl --user start llm-agents-update.service" >&2
          exit 1
        fi

        dir="$PWD"
        project=""
        while true; do
          if test -e "$dir/devenv.nix" || test -e "$dir/devenv.yaml"; then
            project="$dir"
            break
          fi
          if test "$dir" = /; then
            break
          fi
          dir="$(dirname "$dir")"
        done

        if test -n "$project" && test "''${DEVENV_ROOT:-}" != "$project"; then
          cd "$project"
          exec devenv shell -- "$real" "$@"
        fi

        exec "$real" "$@"
      '';
    };
  updateAgents = pkgs.writeShellApplication {
    name = "update-llm-agents";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nix
    ];
    text = ''
      mkdir -p "$(dirname "${profile}")"
      if test -e "${profile}/manifest.json"; then
        nix profile upgrade --profile "${profile}" --refresh --no-accept-flake-config '.*'
      else
        nix profile install --profile "${profile}" --no-accept-flake-config \
          "${flake}#codex" \
          "${flake}#claude-code" \
          "${flake}#opencode"
      fi
    '';
  };
in
{
  environment.variables = {
    CODEX_HOME = "$HOME/.local/share/codex";
    CLAUDE_CONFIG_DIR = "$HOME/.local/share/claude";
  };
  environment.systemPackages = [
    (mkAgentWrapper "claude")
    (mkAgentWrapper "codex")
    (mkAgentWrapper "opencode")
  ];

  systemd = {
    user.services.llm-agents-update = {
      description = "Update the independent LLM agent profile";
      unitConfig.ConditionUser = "raf";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe updateAgents;
        TimeoutStartSec = "4h";
      };
    };

    user.timers.llm-agents-update = {
      description = "Update LLM agents daily";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
    tmpfiles.rules = [
      "d /home/raf/.local/share/codex 0700 raf raf - -"
      "d /home/raf/.local/share/claude 0700 raf raf - -"
    ];

  };
}
