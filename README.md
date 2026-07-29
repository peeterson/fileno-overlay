# The FileNo overlay (Gentoo)

FileNo is a dual-pane file manager for Linux. This repository holds only the
ebuild — the program itself lives at
[peeterson/fileno-dist](https://github.com/peeterson/fileno-dist).

## Installing

    curl -fsSL https://raw.githubusercontent.com/peeterson/fileno-dist/main/install.sh | bash

The installer adds this overlay and emerges the package. By hand it is:

    sudo tee /etc/portage/repos.conf/fileno.conf <<'CONF'
    [fileno]
    location = /var/db/repos/fileno
    sync-type = git
    sync-uri = https://github.com/peeterson/fileno-overlay.git
    auto-sync = yes
    CONF
    sudo emerge --sync fileno
    sudo emerge --ask app-misc/fileno

## The USE flags

| Flag | What it adds |
|------|--------------|
| archives | archives as folders (7z, RAR) |
| pdf | previews of PDF files |
| remote | FTP, SFTP, SMB and WebDAV through gvfs |
| video | thumbnails of videos |

All four are on by default; the program runs without them and says plainly
what is missing.

`remote` pulls `gnome-base/gvfs` with `USE="fuse http samba"`. The `fuse` part
is not optional in practice: without it gvfs mounts the share over D-Bus alone,
nothing appears under `/run/user/UID/gvfs`, and a connection that in fact
succeeded looks to the program like a failure. On an existing system it is worth
checking:

    emerge -pv gnome-base/gvfs      # fuse, http, samba should all be on
