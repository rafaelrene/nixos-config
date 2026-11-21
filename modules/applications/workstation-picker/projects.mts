import { spawnSync } from "node:child_process";
import {
  accessSync,
  constants,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs";
import { homedir } from "node:os";
import { delimiter, dirname, join, relative } from "node:path";

import { maxBuffer } from "./git.mts";
import { labels, tags, type Row } from "./types.mts";

export function displayPath(path: string): string {
  const home = homedir();
  if (path === home) return "~";
  return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
}

function directoryRow(label: string, path: string): Row {
  return {
    tag: tags.directories,
    label,
    detail: path,
    action: { kind: "directory", path },
  };
}

function projectDirectories(code: string): string[] {
  const excludes = [
    "node_modules",
    "vendor",
    "target",
    "dist",
    "build",
    ".devenv",
    ".cache",
  ];
  const found = spawnSync(
    "fd",
    [
      "--hidden",
      "--no-ignore",
      "--prune",
      "--type",
      "d",
      "--type",
      "f",
      "--glob",
      "--absolute-path",
      "--print0",
      ...excludes.flatMap((name) => ["--exclude", name]),
      ".git",
      code,
    ],
    { encoding: "utf8", maxBuffer },
  );
  if (found.error) throw found.error;
  if (found.status !== 0)
    throw new Error(
      found.stderr.trim() || "Could not search for Git projects.",
    );
  const projects = [
    ...new Set(found.stdout.split("\0").filter(Boolean).map(dirname)),
  ].sort();
  const roots: string[] = [];
  for (const path of projects) {
    if (!roots.some((root) => path.startsWith(root + "/"))) roots.push(path);
  }
  return roots;
}

export function destinations(code: string, exclude: Set<string>): Row[] {
  const home = homedir();
  const config = join(home, ".config");
  const rows: Row[] = [];
  for (const [label, path] of [
    [labels.home, home],
    [labels.code, code],
    [labels.config, config],
  ]) {
    if (statSync(path, { throwIfNoEntry: false })?.isDirectory())
      rows.push(directoryRow(label, path));
  }
  if (statSync(code, { throwIfNoEntry: false })?.isDirectory()) {
    try {
      for (const path of projectDirectories(code)) {
        if (path !== code && !exclude.has(path))
          rows.push(directoryRow(relative(code, path), path));
      }
    } catch (error) {
      console.error(error instanceof Error ? error.message : error);
    }
  }
  if (statSync(config, { throwIfNoEntry: false })?.isDirectory()) {
    for (const entry of readdirSync(config, { withFileTypes: true })) {
      if (entry.isDirectory())
        rows.push(
          directoryRow(`Config / ${entry.name}`, join(config, entry.name)),
        );
    }
  }
  for (const host of ["othinus", "proserpina", "nephtys"]) {
    rows.push({
      tag: tags.directories,
      label: host,
      detail: "SSH host",
      action: { kind: "ssh", host },
    });
  }
  return rows;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function manifest(directory: string) {
  const path = join(directory, "package.json");
  if (!statSync(path, { throwIfNoEntry: false })?.isFile()) return;
  const value: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (!isObject(value)) throw new Error("Expected a JSON object.");
  const scripts = value.scripts ?? {};
  if (
    !isObject(scripts) ||
    Object.values(scripts).some((command) => typeof command !== "string")
  ) {
    throw new Error("Expected scripts to be an object of string commands.");
  }
  const manager = value.packageManager;
  if (manager != null && typeof manager !== "string") {
    throw new Error("Expected packageManager to be a string.");
  }
  return { scripts, manager: manager?.split("@", 1)[0] };
}

const lockfiles = [
  ["pnpm-lock.yaml", "pnpm"],
  ["yarn.lock", "yarn"],
  ["bun.lock", "bun"],
  ["bun.lockb", "bun"],
  ["package-lock.json", "npm"],
  ["npm-shrinkwrap.json", "npm"],
];

function detectedManager(directory: string): string | undefined {
  return lockfiles.find(([filename]) =>
    statSync(join(directory, filename), { throwIfNoEntry: false })?.isFile(),
  )?.[1];
}

export function scriptRows(cwd: string, root = cwd): Row[] {
  const packages: {
    directory: string;
    scripts: Record<string, unknown>;
    manager?: string;
  }[] = [];
  let directory = cwd;
  while (true) {
    const path = directory;
    try {
      const { scripts, manager } = manifest(path) ?? {
        scripts: {},
        manager: undefined,
      };
      packages.push({
        directory: path,
        scripts,
        manager: manager || detectedManager(path),
      });
    } catch (error) {
      console.error(
        `Cannot read ${join(path, "package.json")}: ${error instanceof Error ? error.message : error}`,
      );
    }
    if (path === root || dirname(path) === path) break;
    directory = dirname(path);
  }

  return packages.flatMap(({ directory, scripts }, index): Row[] => {
    const manager =
      packages.slice(index).find((entry) => entry.manager)?.manager ?? "npm";
    const location = relative(root, directory) || ".";
    return Object.keys(scripts)
      .sort()
      .filter((name) => !name.includes("\0"))
      .map((name) => ({
        tag: tags.scripts,
        label: `${name} · ${location}`,
        detail: String(scripts[name]),
        action: { kind: "script", directory, manager, name },
      }));
  });
}

export function checkManager(manager: string) {
  if (!["npm", "pnpm", "yarn", "bun"].includes(manager)) {
    throw new Error(`Unsupported package manager: ${manager}`);
  }
  for (const directory of (process.env.PATH ?? "").split(delimiter)) {
    const path = join(directory, manager);
    try {
      if (!statSync(path, { throwIfNoEntry: false })?.isFile()) continue;
      accessSync(path, constants.X_OK);
      return;
    } catch {
      // Try the next PATH entry if this candidate is inaccessible.
    }
  }
  throw new Error(
    `${manager} is not on PATH. Enter this project's development environment first.`,
  );
}
