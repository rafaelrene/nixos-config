export type WorktreeBase = {
  ref: string;
  track?: true;
};

export type LocalBranch = {
  name: string;
  upstream: string;
};

export type Branch = {
  name: string;
  remote?: string;
};

export type Route =
  | { kind: "directory"; path: string; submodule?: true }
  | { kind: "branch"; branch: Branch };

export type Script = {
  kind: "script";
  directory: string;
  manager: string;
  name: string;
};

export type Action =
  | Route
  | Script
  | { kind: "ssh"; host: string }
  | { kind: "create"; from: WorktreeBase }
  | { kind: "delete" };

export const labels = {
  home: "Home",
  code: "Code",
  config: "Config",
  checkout: "Main checkout",
  parent: "Parent repository",
  root: "Current worktree root",
  submodule: "Submodule",
};

export const tags = {
  directories: "[@]",
  gitDirectories: "[#] [@]",
  git: "[#]",
  manage: "[##]",
  scripts: "[:]",
} as const;

export type Row = {
  tag: (typeof tags)[keyof typeof tags];
  label: string;
  detail: string;
  action: Action;
  worktree?: WorktreeBase;
};
