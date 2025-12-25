#!/usr/bin/env python3
"""
Small system tray toggle for socks-vpn service using PyQt5.
"""
import sys
import shutil
import subprocess
from PyQt5 import QtWidgets, QtGui, QtCore

SERVICE = "socks-vpn"

def run_cmd(cmd):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def systemctl(*args):
    return run_cmd(["systemctl"] + list(args))

def is_active():
    rc, out, err = systemctl("is-active", SERVICE)
    return rc == 0 and out == "active"

class TrayApp(QtWidgets.QSystemTrayIcon):
    def __init__(self, icon, parent=None):
        super().__init__(icon, parent)
        self.setToolTip("Socks VPN Tray")
        self.menu = QtWidgets.QMenu()
        self.action_start = self.menu.addAction("Start")
        self.action_stop  = self.menu.addAction("Stop")
        self.action_restart = self.menu.addAction("Restart")
        self.menu.addSeparator()
        self.action_quit = self.menu.addAction("Quit")
        self.setContextMenu(self.menu)
        self.action_start.triggered.connect(self.start_service)
        self.action_stop.triggered.connect(self.stop_service)
        self.action_restart.triggered.connect(self.restart_service)
        self.action_quit.triggered.connect(QtWidgets.qApp.quit)
        self.activated.connect(self.on_click)

        self.status_timer = QtCore.QTimer()
        self.status_timer.timeout.connect(self.refresh_status)
        self.status_timer.start(2500)  # poll every 2.5s
        self.refresh_status()

    def on_click(self, reason):
        # left-click toggles start/stop
        if reason == QtWidgets.QSystemTrayIcon.Trigger:
            if is_active():
                self.stop_service()
            else:
                self.start_service()

    def refresh_status(self):
        active = is_active()
        if active:
            self.setIcon(QtGui.QIcon.fromTheme("media-playback-start"))  # theme icon
            self.setToolTip(f"Socks VPN is running")
            self.action_start.setEnabled(False)
            self.action_stop.setEnabled(True)
        else:
            self.setIcon(QtGui.QIcon.fromTheme("media-playback-stop"))
            self.setToolTip(f"Socks VPN is inactive")
            self.action_start.setEnabled(True)
            self.action_stop.setEnabled(False)

    def start_service(self):
        rc, out, err = systemctl("start", SERVICE)
        if rc == 0:
            self.showMessage("Service started", "It may take a few seconds to connect.")
        else:
            self.showMessage("Failed to start", f"{err or out}")
        self.refresh_status()

    def stop_service(self):
        rc, out, err = systemctl("stop", SERVICE)
        if rc == 0:
            self.showMessage("Service stopped", "Socks VPN has been stopped.")
        else:
            self.showMessage("Failed to stop", f"{err or out}")
        self.refresh_status()

    def restart_service(self):
        rc, out, err = systemctl("restart", SERVICE)
        if rc == 0:
            self.showMessage("Service restarted", "It may take a few seconds to reconnect.")
        else:
            self.showMessage("Failed to restart", f"{err or out}")
        self.refresh_status()

def main():
    app = QtWidgets.QApplication(["Socks VPN Tray"])
    # ensure tray is available
    if not QtWidgets.QSystemTrayIcon.isSystemTrayAvailable():
        print("System tray not available")
        sys.exit(1)

    # pick a fallback icon if theme icons not present
    icon = QtGui.QIcon.fromTheme("system-run")
    if icon.isNull():
        icon = app.style().standardIcon(QtWidgets.QStyle.SP_ComputerIcon)

    tray = TrayApp(icon)
    tray.show()
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()
