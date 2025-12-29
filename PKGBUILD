# Maintainer: Alireza Poodineh <itsaeliux@gmail.com>

pkgname=socks-vpn
pkgver=0.1.0
pkgrel=1
pkgdesc="SSH-based SOCKS VPN"
arch=("x86_64" "aarch64")
license=("MIT")
depends=("openssh" "sshpass" "badvpn" "curl" "python-pyqt5")
makedepends=("git")
install=${pkgname}.install
source=(".work::git+https://github.com/aeliux/sshvpn.git")
sha256sums=("SKIP")

package() {
  cd "${srcdir}/.work"

  # Daemon and tray
  install -d "${pkgdir}/usr/lib/socks-vpn" "${pkgdir}/usr/bin"
  install -m0755 bin/socks-vpn-control "${pkgdir}/usr/lib/socks-vpn/"
  install -m0755 bin/socks-vpn-tray "${pkgdir}/usr/lib/socks-vpn/"
  ln -sf ../lib/socks-vpn/socks-vpn-control "${pkgdir}/usr/bin/socks-vpn-control"
  ln -sf ../lib/socks-vpn/socks-vpn-tray "${pkgdir}/usr/bin/socks-vpn-tray"

  # Config (user can override); install empty password file for convenience
  install -Dm0644 config/socks-vpn.conf "${pkgdir}/etc/socks-vpn.conf"
  install -Dm0600 /dev/null "${pkgdir}/etc/socks-vpn.pass"

  # Systemd unit
  install -Dm0644 systemd/socks-vpn.service "${pkgdir}/usr/lib/systemd/system/socks-vpn.service"

  # Polkit rule
  install -Dm0644 polkit/50-socks-vpn.rules "${pkgdir}/usr/share/polkit-1/rules.d/50-socks-vpn.rules"

  # Desktop entry for tray
  install -Dm0644 desktop/socks-vpn-tray.desktop "${pkgdir}/usr/share/applications/socks-vpn-tray.desktop"
}
