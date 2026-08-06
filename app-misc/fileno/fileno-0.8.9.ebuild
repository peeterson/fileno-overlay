# Copyright 2026 peeterson
# Distributed under the terms of the FileNo license (see README.md)

EAPI=8

inherit desktop xdg

DESCRIPTION="A dual-pane file manager for Linux, in the shape of Directory Opus"
HOMEPAGE="https://github.com/peeterson/fileno-dist"
SRC_URI="https://github.com/peeterson/fileno-dist/releases/download/v${PV}/${P}-linux-amd64.tar.gz"

# This is a PREBUILT package: the program is closed source, and what the
# release carries is the compiled build with its Python and Qt inside — the
# same artifact the .deb wraps. Portage installs it, it does not build it.
# `strip` joins the RESTRICT list because the binaries arrive already stripped
# and prelinked with their $ORIGIN rpaths; re-stripping compiled-in resources
# is how prebuilt Qt programs get broken.
LICENSE="all-rights-reserved"
RESTRICT="mirror bindist strip"
SLOT="0"
# -* first: this tarball IS amd64 machine code, there is nothing an ~x86 user
# could build from it.
KEYWORDS="-* ~amd64"
IUSE="+archives +pdf +remote samba +video"

# `samba` is meaningless on its own: it only widens what `remote` can mount.
REQUIRED_USE="samba? ( remote )"

QA_PREBUILT="opt/${PN}/*"

# What the bundle does NOT carry — read off the binaries with ldd, not
# guessed. Qt, Python, PySide6, Pillow, pyte and the gi bindings all travel
# inside /opt/fileno; what is left is the system floor Qt stands on (glibc,
# X/Wayland client libraries, OpenGL, fontconfig, D-Bus) plus the tools the
# program calls as PROGRAMS rather than links:
#
# `glib` carries the `gio` command AND libgirepository — Delete goes through
#         `gio trash`, Undo through `gio trash --restore`, "Open with…" takes
#         its list from `gio mime`, and the bundled gi bindings still call the
#         system's libgirepository/typelibs at run time.
# The optional flags are what the program says is missing when a feature is
# asked for without them — it runs perfectly well without all of them:
#   archives — app-arch/7zip, WITHOUT [rar] on purpose: 7zip's `rar` flag is
#         off by default and brings the unRAR license, which is not in @FREE.
#         We promise 7z, zip and tar, and say where RAR comes from.
#   remote — gvfs mounts the share and we work on an ordinary folder.
#         `fuse` is not a nicety: without it nothing appears under
#         /run/user/<uid>/gvfs and a mount that succeeded looks failed.
#         `http` is dav://, `sftp` is sftp:// and needs a real `ssh` binary —
#         virtual/openssh, NOT virtual/ssh (dropbear installs `dbclient` and
#         never an `ssh`).
#   samba — Windows shares through the gvfs samba backend; off by default
#         because it pulls net-fs/samba, a large build to hand to somebody
#         who only wanted FTP.
# The icon themes: every FILE icon in the program comes out of
# QIcon.fromTheme, and a theme is a package in its own right. hicolor is where
# our own icon lands; the any-of group asks for ONE theme with real content —
# a box that already has any member is left alone entirely.
RDEPEND="
	dev-libs/glib:2
	media-libs/fontconfig
	media-libs/freetype
	media-libs/libglvnd
	sys-apps/dbus
	x11-libs/libX11
	x11-libs/libxcb
	x11-libs/libxkbcommon[X]
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

src_install() {
	# doins would drop the execute bits, and a loop of fperms over a whole Qt
	# tree is where install scripts go to die — so the dist is copied whole,
	# permissions and all, the way bin-style ebuilds do it.
	dodir /opt/${PN}
	cp -a "${S}/${PN}.dist/." "${ED}/opt/${PN}/" || die "copying the program failed"

	dosym ../../opt/${PN}/${PN} /usr/bin/${PN}

	domenu ${PN}.desktop
	domenu ${PN}-viewer.desktop

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

	dodoc README.md docs/BETA-TERMS.md docs/BETA-TERMS.pl.md

	# Portage compresses everything under /usr/share/doc, and the program READS
	# the terms from there to show them at the first start. A `.md.bz2` is a
	# file it cannot open, so the user would be asked to accept a fallback
	# summary instead of the text installed on their own disk.
	docompress -x /usr/share/doc/${PF}

	# `all-rights-reserved` is not a license Portage ships the text of, so the
	# text has to come from us — otherwise the one thing telling the user what
	# they may do with this program is absent from the machine it is on.
	insinto /usr/share/licenses/${PN}
	doins LICENSE
}
