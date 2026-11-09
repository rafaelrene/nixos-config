{ rclone }:
# Recheck the VFS fixes against upstream before changing this version.
assert rclone.version == "1.75.2";
rclone.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./rclone-1.75.2-writeback-identity.patch
    ./rclone-1.75.2-pending-directory-reparent.patch
    ./rclone-1.75.2-recovered-file-object.patch
  ];
})
