# Copyright 2026 peeterson
# Distributed under the terms of the FileNo licence (see README.md)

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )
inherit desktop python-single-r1 xdg

DESCRIPTION="A dual-pane file manager for Linux, in the shape of Directory Opus"
HOMEPAGE="https://github.com/peeterson/fileno-dist"
SRC_URI="https://github.com/peeterson/fileno-dist/releases/download/v${PV}/${P}.tar.gz"

# The sources carry no licence file, so nothing may be assumed about them.
# RESTRICT=mirror keeps them off the Gentoo mirrors for the same reason.
LICENSE="all-rights-reserved"
RESTRICT="mirror"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="+archives +pdf +video"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

# Qt itself is not a dependency of ours: PySide6 pulls in the parts it needs.
# In Gentoo PySide6 is `dev-python/pyside:6`, and its modules are USE flags —
# `svg` is off by default, so it has to be asked for by name or the program
# starts without its own icons.
# `pyte` is the VT parser behind the terminal under the panes.
# The three optional ones are what the program says is missing when a feature is
# asked for without them — it runs perfectly well without all three.
RDEPEND="
	$(python_gen_cond_dep '
		dev-python/pyside:6[${PYTHON_USEDEP},gui,svg,widgets]
		dev-python/pyte[${PYTHON_USEDEP}]
	')
	${PYTHON_DEPS}
	archives? ( app-arch/7zip )
	pdf? ( app-text/poppler[utils] )
	video? ( media-video/ffmpegthumbnailer )
"

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
	local icon
	for icon in icons/fileno-*.png; do
		local size=${icon##*fileno-}
		newicon -s "${size%.png}" "${icon}" fileno.png
	done

	dodoc README.md
}
