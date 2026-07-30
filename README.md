# The FileNo overlay (Gentoo)

FileNo is a dual-pane file manager for Linux. This repository holds only the
ebuild — the program itself lives at
[peeterson/fileno-dist](https://github.com/peeterson/fileno-dist).

## Installing

    curl -fsSL https://raw.githubusercontent.com/peeterson/fileno-dist/main/install.sh | bash

The installer adds this overlay and emerges the package. By hand it is four
files and two commands — and it really is four: with any of the first three
missing, Portage stops before it builds anything.

    # 1. the overlay itself
    sudo mkdir -p /etc/portage/repos.conf
    printf '%s\n' '[fileno]' 'location = /var/db/repos/fileno' \
        'sync-type = git' 'sync-uri = https://github.com/peeterson/fileno-overlay.git' \
        'auto-sync = yes' | sudo tee /etc/portage/repos.conf/fileno.conf

    # 2. the package is keyworded ~arch — it is a beta
    sudo mkdir -p /etc/portage/package.accept_keywords
    echo 'app-misc/fileno **' \
        | sudo tee /etc/portage/package.accept_keywords/fileno

    # 3. its licence is not one of the free ones Portage accepts unasked
    sudo mkdir -p /etc/portage/package.license
    echo 'app-misc/fileno all-rights-reserved' \
        | sudo tee /etc/portage/package.license/fileno

    # 4. two USE flags on OTHER packages that the program cannot do without
    sudo mkdir -p /etc/portage/package.use
    printf '%s\n' 'dev-python/pyside svg' 'gnome-base/gvfs fuse http' \
        | sudo tee /etc/portage/package.use/fileno

    sudo emerge --sync fileno
    sudo emerge --ask app-misc/fileno

Every one of those entries names one package and changes nothing else on the
box. The fourth is the one people leave out: `dev-python/pyside` builds without
`svg`, and then Qt cannot draw the icon themes that ship svg and nothing else —
the program comes up with empty toolbars. `gnome-base/gvfs` is the same story
for remote locations and is explained at the bottom of this page. Portage would
in fact ask for both, but only after a long dependency resolution, which is a
poor moment to find out.

## The USE flags

| Flag | What it adds |
|------|--------------|
| archives | archives as folders (7z, zip, tar) |
| pdf | previews of PDF files |
| remote | FTP, SFTP and WebDAV through gvfs |
| samba | Windows shares (smb://) as well — **off** by default |
| video | thumbnails of videos |

All but `samba` are on by default; the program runs without any of them and
says plainly what is missing. `samba` is the exception because it reaches past
gvfs into `net-fs/samba`, which is a long build for one protocol — so it is
asked for by name. Write it down rather than putting `USE=` in front of the
command: `sudo` throws the variable away, and a flag set for one emerge would be
gone again at the next update.

    printf '%s\n' 'app-misc/fileno samba' 'gnome-base/gvfs samba' \
        | sudo tee /etc/portage/package.use/fileno-samba
    sudo emerge --ask --changed-use gnome-base/gvfs app-misc/fileno

Both lines, not just the first: with `samba` on, this package asks for
`gnome-base/gvfs[samba]`, and the file written in step 4 grants gvfs only
`fuse http`. Without the second line Portage stops with "the following USE
changes are necessary to proceed" — the very thing step 4 exists to avoid. A
file of its own, because step 4's file is rewritten by the installer.

`archives` pulls `app-arch/7zip`, which reads RAR as well — but only when it was
itself built with `USE="rar"`. That flag is off by default and adds the unRAR
licence, which is not among the ones Portage accepts unasked, so we do not
demand it: nobody who only wanted to walk into a .zip should have to accept a
licence for it. If you want RAR:

    echo 'app-arch/7zip rar' | sudo tee /etc/portage/package.use/7zip
    echo 'app-arch/7zip unRAR' | sudo tee /etc/portage/package.license/7zip
    sudo emerge --changed-use app-arch/7zip

The third line is not optional. Nothing in the dependency graph asks for
`7zip[rar]`, so an already-merged 7zip is left exactly as it was and .rar files
go on failing until it is rebuilt.

`remote` pulls `gnome-base/gvfs` with `USE="fuse http sftp"`. The `fuse` part is
not optional in practice: without it gvfs mounts the share over D-Bus alone,
nothing appears under `/run/user/UID/gvfs`, and a connection that in fact
succeeded looks to the program like a failure. `http` is dav:// and `sftp` is
sftp://; both are on by default in gvfs and pinned so that turning one off gives
Portage something to say instead of leaving the scheme to fail wordlessly. On an
existing system it is worth checking:

    emerge -pv gnome-base/gvfs      # fuse, http and sftp should all be on
