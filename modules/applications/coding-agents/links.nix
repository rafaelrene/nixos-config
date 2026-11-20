{ config, lib, ... }:
{
  options.features.coding-agents.source = lib.mkOption {
    type = lib.types.path;
    default = ../../../config/agents;
    description = "Shared editable agent instructions and skills.";
  };

  options.features.coding-agents.links = lib.mkOption {
    type = lib.types.functionTo (lib.types.attrsOf lib.types.raw);
    description = "Declare shared agent rule and skill links.";
  };

  config.features.coding-agents.links =
    { lib }:
    let
      skillNames = lib.attrNames (
        lib.filterAttrs (
          name: type:
          type == "directory"
          && builtins.pathExists (config.features.coding-agents.source + "/skills/${name}/SKILL.md")
        ) (builtins.readDir (config.features.coding-agents.source + "/skills"))
      );
      skillDirectories = [
        ".local/share/codex/skills"
        ".local/share/claude/skills"
      ];
      antigravitySkills = ".local/share/antigravity/skills";
      skills = lib.genAttrs skillNames (name: "skills/${name}");
      linksFor =
        directories:
        lib.listToAttrs (
          lib.concatMap (
            directory:
            lib.mapAttrsToList (name: value: {
              name = "${directory}/${name}";
              inherit value;
            }) skills
          ) directories
        );
    in
    {
      inherit skillDirectories;
      rules = {
        ".local/share/codex/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/AGENTS.md" = "AGENTS.md";
        ".local/share/claude/CLAUDE.md" = "CLAUDE.md";
        ".gemini/config/AGENTS.md" = "AGENTS.md";
      };
      skillLinks = linksFor skillDirectories;
      antigravity = {
        skillDirectories = [ antigravitySkills ];
        links = linksFor [ antigravitySkills ];
        skillAliases.${antigravitySkills} = ".gemini/config/skills";
      };
    };
}
