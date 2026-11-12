package vfs

import (
	"context"
	"io"
	"testing"
	"time"

	_ "github.com/rclone/rclone/backend/local"
	"github.com/rclone/rclone/fs"
	"github.com/rclone/rclone/fs/config"
	"github.com/rclone/rclone/vfs/vfscache/writeback"
	"github.com/rclone/rclone/vfs/vfscommon"
	"github.com/stretchr/testify/require"
)

func filenTestOptions(t *testing.T) (fs.Fs, vfscommon.Options) {
	t.Helper()
	previous := config.GetCacheDir()
	require.NoError(t, config.SetCacheDir(t.TempDir()))
	t.Cleanup(func() { require.NoError(t, config.SetCacheDir(previous)) })
	remote, err := fs.NewFs(context.Background(), t.TempDir())
	require.NoError(t, err)
	opt := vfscommon.Opt
	opt.CacheMode = vfscommon.CacheModeFull
	opt.CachePollInterval = 0
	opt.WriteBack = fs.Duration(time.Hour)
	return remote, opt
}

func TestFilenPendingDirectoryMove(t *testing.T) {
	remote, opt := filenTestOptions(t)
	ctx := context.Background()
	require.NoError(t, remote.Mkdir(ctx, "old/child"))
	require.NoError(t, remote.Mkdir(ctx, "new"))
	vfs := New(ctx, remote, &opt)
	t.Cleanup(vfs.Shutdown)

	file, err := vfs.Create("old/child/pending.txt")
	require.NoError(t, err)
	_, err = file.WriteString("pending content")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, vfs.Rename("old/child", "new/child"))

	vfs.FlushDirCache()
	node, err := vfs.Stat("new/child/pending.txt")
	require.NoError(t, err, "a moved pending file must survive directory cache expiry")
	require.Equal(t, int64(len("pending content")), node.Size())
}

func TestFilenRecoveredUploadRename(t *testing.T) {
	remote, opt := filenTestOptions(t)
	ctx := context.Background()
	vfs := New(ctx, remote, &opt)
	t.Cleanup(func() { vfs.Shutdown() })

	file, err := vfs.Create("pending.txt")
	require.NoError(t, err)
	_, err = file.WriteString("recovered content")
	require.NoError(t, err)
	require.NoError(t, file.Close())
	vfs.Shutdown()

	vfs = New(ctx, remote, &opt)
	_, err = vfs.Stat("pending.txt")
	require.NoError(t, err)
	queue := vfs.cache.Queue()["queue"].([]writeback.QueueInfo)
	require.Len(t, queue, 1)
	require.NoError(t, vfs.cache.QueueSetExpiry(queue[0].ID, time.Now(), 0))
	vfs.WaitForWriters(5 * time.Second)
	require.False(t, vfs.Busy(), "the recovered upload must finish")
	require.NoError(t, vfs.Rename("pending.txt", "renamed.txt"))

	object, err := remote.NewObject(ctx, "renamed.txt")
	require.NoError(t, err, "renaming a recovered upload must rename its remote object")
	reader, err := object.Open(ctx)
	require.NoError(t, err)
	contents, err := io.ReadAll(reader)
	require.NoError(t, err)
	require.NoError(t, reader.Close())
	require.Equal(t, "recovered content", string(contents))
}
