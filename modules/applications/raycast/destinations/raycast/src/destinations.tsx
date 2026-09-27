import {
  Action,
  ActionPanel,
  closeMainWindow,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { useEffect, useState } from "react";

const execute = promisify(execFile);
const launcher = "/nix/var/nix/profiles/system/sw/bin/workstation-open";

type Destination = {
  id: string;
  kind: "home" | "code" | "project" | "config" | "ssh";
  name: string;
  path: string;
};

function isDestination(value: unknown): value is Destination {
  return (
    typeof value === "object" &&
    value !== null &&
    "id" in value &&
    typeof value.id === "string" &&
    "name" in value &&
    typeof value.name === "string" &&
    "path" in value &&
    typeof value.path === "string" &&
    "kind" in value &&
    (value.kind === "home" ||
      value.kind === "code" ||
      value.kind === "project" ||
      value.kind === "config" ||
      value.kind === "ssh")
  );
}

async function loadDestinations() {
  const { stdout } = await execute(launcher, ["list"], {
    maxBuffer: 8 * 1024 * 1024,
  });
  const rows: unknown = JSON.parse(stdout);
  if (!Array.isArray(rows) || !rows.every(isDestination)) {
    throw new Error("The destination helper returned an invalid list.");
  }
  return rows;
}

async function openDestination(destination: Destination, newWindow = false) {
  try {
    // Hide first so closing Raycast cannot steal focus back from Ghostty.
    await closeMainWindow();
    await execute(launcher, [
      "open",
      destination.id,
      ...(newWindow ? ["--new-window"] : []),
    ]);
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Could not open destination",
      message: error instanceof Error ? error.message : String(error),
    });
  }
}

const sections = [
  { title: "Places", kinds: ["home", "code"] },
  { title: "Projects", kinds: ["project"] },
  { title: "Configuration", kinds: ["config"] },
  { title: "SSH", kinds: ["ssh"] },
];

export default function Destinations() {
  const [destinations, setDestinations] = useState<Destination[]>([]);
  const [loading, setLoading] = useState(true);
  const [failure, setFailure] = useState<string>();

  useEffect(() => {
    let active = true;
    loadDestinations()
      .then((rows) => {
        if (active) setDestinations(rows);
      })
      .catch((error: unknown) => {
        if (active) {
          setFailure(error instanceof Error ? error.message : String(error));
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, []);

  return (
    <List isLoading={loading} searchBarPlaceholder="Find a destination…">
      <List.EmptyView
        title={
          failure ? "Could not load destinations" : "No destinations found"
        }
        description={failure}
      />
      {sections.map((section) => (
        <List.Section key={section.title} title={section.title}>
          {destinations
            .filter((destination) => section.kinds.includes(destination.kind))
            .map((destination) => (
              <List.Item
                key={destination.id}
                title={destination.name}
                subtitle={destination.path}
                keywords={[destination.kind, destination.path]}
                icon={destination.kind === "ssh" ? Icon.Network : Icon.Folder}
                actions={
                  <ActionPanel>
                    <Action
                      title={
                        destination.kind === "ssh"
                          ? "Connect in New Window"
                          : "Open Destination"
                      }
                      icon={Icon.Terminal}
                      onAction={() => openDestination(destination)}
                    />
                    {destination.kind !== "ssh" && (
                      <Action
                        title="Open New Window"
                        icon={Icon.Plus}
                        shortcut={{ modifiers: ["cmd", "shift"], key: "enter" }}
                        onAction={() => openDestination(destination, true)}
                      />
                    )}
                  </ActionPanel>
                }
              />
            ))}
        </List.Section>
      ))}
    </List>
  );
}
