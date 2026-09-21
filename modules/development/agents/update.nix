{
  pkgs,
  profile,
  flake ? "github:numtide/llm-agents.nix",
  upgradeAll ? false,
}:
pkgs.writeShellApplication {
  name = "update-llm-agents";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.nix
  ];
  text = ''
    mkdir -p "$(dirname "${profile}")"
    if test -e "${profile}/manifest.json"; then
      nix profile upgrade --profile "${profile}" --refresh --no-accept-flake-config ${
        if upgradeAll then "--all" else "'.*'"
      }
    else
      nix profile install --profile "${profile}" --no-accept-flake-config \
        "${flake}#codex" \
        "${flake}#claude-code" \
        "${flake}#opencode"
    fi
  '';
}
