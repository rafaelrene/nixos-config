{ rclone }:
rclone.overrideAttrs (old: {
  patchFlags = (old.patchFlags or [ "-p1" ]) ++ [ "--fuzz=0" ];
  patches = (old.patches or [ ]) ++ [
    ./rclone-1.75.2-writeback-identity.patch
    ./rclone-1.75.2-pending-directory-reparent.patch
    ./rclone-1.75.2-recovered-file-object.patch
  ];
  doCheck = true;
  postCheck = (old.postCheck or "") + ''
    cp ${./rclone-vfs_test.go} vfs/filen_test.go
    go test -timeout 1m -run '^TestFilen' ./vfs
  '';
})
