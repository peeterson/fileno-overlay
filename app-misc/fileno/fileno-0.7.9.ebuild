# Copyright 2026 peeterson
# Distributed under the terms of the FileNo licence (see README.md)

EAPI=8

# 3.11 is not offered: no dev-python/pyside in ::gentoo supports it, so a build
# for it could only ever fail at dependency resolution.
PYTHON_COMPAT=( python3_{12..14} )
inherit desktop python-single-r1 xdg

DESCRIPTION="A dual-pane file manager for Linux, in the shape of Directory Opus"
HOMEPAGE="https://github.com/peeterson/fileno-dist"
SRC_URI="https://github.com/peeterson/fileno-dist/releases/download/v${PV}/${P}.tar.gz"

# The sources carry no licence file, so nothing may be assumed about them.
# RESTRICT=mirror keeps them off the Gentoo mirrors for the same reason, and
# `bindist` says it about the other direction a package can travel: a binary
# package built from these sources may not be passed on either. It does not stop
# anybody building a binpkg for their own machines — it stops a binhost handing
# it round, which is what a licence granting nothing forbids.
LICENSE="all-rights-reserved"
RESTRICT="mirror bindist"
SLOT="0"
# ~x86 is not wishful thinking: dev-python/pyside carries ~x86 in ::gentoo, so
# the stack this needs is genuinely available there.
KEYWORDS="~amd64 ~x86"
IUSE="+archives +pdf +remote samba +video"

# `samba` is meaningless on its own: it only widens what `remote` can mount.
REQUIRED_USE="${PYTHON_REQUIRED_USE}
	samba? ( remote )"

# Qt itself is not a dependency of ours: PySide6 pulls in the parts it needs.
# In Gentoo PySide6 is `dev-python/pyside:6`, and its modules are USE flags —
# `svg` is off by default, so it has to be asked for by name. What it buys is
# the ability to DRAW an svg: Papirus and breeze ship their icons as svg and
# nothing else, so without QtSvg the theme hands Qt files it cannot read. It
# supplies no icon of its own, though — which this comment used to blur. Every
# icon in the program comes out of QIcon.fromTheme, and a theme is a package in
# its own right:
#
#   hicolor-icon-theme — we install our own icon into hicolor with `newicon`,
#            and the specification wants a valid index.theme sitting there.
#   || ( papirus breeze adwaita ) — one theme with real content, or a correct
#            install produces a program with blank toolbars and a list of
#            nameless rows, which reads as a broken build rather than a bare
#            system. An any-of group asks for ONE of them: a box that already
#            has any member is left alone entirely, and only a box with none
#            gets anything built — the leftmost that can be. So this order is
#            not the order the code searches in (theme/style.py tries Papirus,
#            then Adwaita, then breeze); it is the order in which we would
#            rather build one for somebody who has none. Papirus and breeze are
#            the two with full mimetype and places coverage; recent Adwaita
#            releases have been shedding the legacy full-colour icons, so it
#            comes last — where it still satisfies the group for free on a
#            GNOME box that has it.
#
# `qtimageformats` is a quieter version of the same gap. Thumbnails and the
# preview panel read every image through QImageReader, i.e. through Qt's image
# plugins, and Qt on its own brings png/jpeg/gif/bmp and no more. webp, tiff and
# tga are in our extension lists (core/thumbnails.py, core/viewer.py) and this
# package is where they come from; without it those previews stay empty and
# never say why. It is not everything our lists mention: Gentoo builds this
# package with `-DQT_FEATURE_jasper=OFF`, so jp2 gets no plugin, and Qt 6 dropped
# the dds one altogether. Those two stay unreadable, and the package is worth
# having for the three that are not.
# `pillow` reads the EXIF block behind the Metadata dialog. It is deliberately
# NOT a USE flag like the features further down, and for one reason: those
# announce what is missing, whereas `exif_rows` catches the ImportError and
# returns an empty list — the panel then shows the dimensions and stops, and the
# photographer concludes the camera wrote no EXIF. A hole that silent is not
# something to offer as a choice.
# `glib` carries the `gio` command, and that is not a remote-only tool however
# the flags below read: Delete goes through `gio trash`, Undo through
# `gio trash --restore`, and "Open with…" takes its entire list of applications
# from `gio mime` and starts them with `gio launch` (core/fileops.py,
# core/undo.py, core/openwith.py). Gated behind `remote?` it was absent from an
# ordinary build, and there Delete falls back on our own FreeDesktop trash (no
# per-volume cans) while "Open with…" offers an empty list and nothing else.
# `pyte` is the VT parser behind the terminal under the panes.
# The optional ones are what the program says is missing when a feature is
# asked for without them — it runs perfectly well without all of them.
#
# `archives` is app-arch/7zip. p7zip is not gone from ::gentoo yet, but it is
# package.mask'd as outdated and replaced by 7zip, with removal set for
# 2026-08-15 — depending on it now means depending on a package on its way out.
# It is written
# WITHOUT [rar] on purpose: 7zip's `rar` flag is off by default and brings the
# unRAR licence, which is not in @FREE, so asking for it would stop the emerge
# of everyone who only wanted to walk into a .zip until they had written a
# package.license entry for a package that is not even ours. So we promise 7z,
# zip and tar, and say where RAR comes from rather than imply it is included.
#
# `remote` is FTP/SFTP/SMB/WebDAV (§11). We write no network client of our own:
# gvfs mounts the share and we work on an ordinary folder. Hence the sub-flags,
# and none of them is a nicety:
#   fuse   — without it gvfs mounts over D-Bus ONLY, and /run/user/<uid>/gvfs
#            never appears; the program then has no path to open and says so.
#            This is exactly what makes FTP look broken on Gentoo.
#   http   — the dav:// and davs:// backends.
#   sftp   — the sftp:// backend. On by default in gvfs, and pinned anyway for
#            the same reason as the other two: with USE=-sftp the scheme is
#            still offered and still fails with nothing to read.
#
# SMB is a flag of our own instead, and off by default, because gvfs[samba]
# pulls in net-fs/samba — a big build to hand to somebody who asked for FTP.
# The dependency is written `samba?` on the gvfs atom, which is Portage's way
# of saying "gvfs must have samba only if we do": with the flag off, an
# existing gvfs is left alone rather than rebuilt.
# `pygobject` is the real mount route (GIO's own mount operation, so we can
# answer the password prompt from our dialog); the sftp backend spawns `ssh`
# itself, so the client has to be there. `virtual/openssh`, NOT `virtual/ssh`:
# the latter is also satisfied by net-misc/dropbear, which installs `dbclient`
# and never an `ssh`, so the backend would still have nothing to exec. gvfs's own
# `sftp? ( virtual/openssh )` says the same thing, which is why `sftp` is pinned
# on the gvfs atom — the two together are what make SFTP work rather than fail
# wordlessly, exactly as `fuse` and `http` do for the other schemes.
RDEPEND="
	$(python_gen_cond_dep '
		dev-python/pyside:6[${PYTHON_USEDEP},gui,svg,widgets]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/pyte[${PYTHON_USEDEP}]
		remote? ( dev-python/pygobject:3[${PYTHON_USEDEP}] )
	')
	${PYTHON_DEPS}
	dev-libs/glib:2
	dev-qt/qtimageformats:6
	x11-themes/hicolor-icon-theme
	|| (
		x11-themes/papirus-icon-theme
		kde-frameworks/breeze-icons
		x11-themes/adwaita-icon-theme
	)
	archives? ( app-arch/7zip )
	pdf? ( app-text/poppler[utils] )
	remote? (
		gnome-base/gvfs[fuse,http,sftp,samba?]
		virtual/openssh
	)
	video? ( media-video/ffmpegthumbnailer )
"

# There is nothing to compile, but `python_domodule` byte-compiles what it
# installs, and that runs the interpreter on the build machine. So the
# interpreter — and only the interpreter — belongs in BDEPEND. No DEPEND: we
# import nothing from the target root while building, so PySide6 and the rest
# are needed at run time alone.
BDEPEND="${PYTHON_DEPS}"

src_install() {
	python_domodule fileno

	# The launcher: python_newscript puts the right interpreter in the shebang,
	# so the program starts under the Python it was installed for.
	cat > "${T}"/fileno.py <<-EOF || die
		#!/usr/bin/env python
		import sys

		from fileno.app import main

		sys.exit(main())
	EOF
	python_newscript "${T}"/fileno.py fileno

	domenu fileno.desktop

	# Two ways this loop can go wrong quietly, and both end with a menu entry
	# pointing at an icon nobody installed. A glob that matches nothing is left
	# standing by bash, so the body would run once on the literal
	# "icons/fileno-*.png" with a size of "*"; and `newicon` refuses an
	# unsupported size with `eerror` and `exit 1` from inside its own subshell,
	# which does NOT die — the ebuild would carry on and merge without icons.
	# Hence the file test, the `|| die`, and the count at the end.
	local icon found=
	for icon in icons/fileno-*.png; do
		[[ -f ${icon} ]] || continue
		local size=${icon##*fileno-}
		newicon -s "${size%.png}" "${icon}" fileno.png || die "newicon ${icon} failed"
		found=yes
	done
	[[ -n ${found} ]] || die "no icons/fileno-*.png in the tarball"

	dodoc README.md
}
