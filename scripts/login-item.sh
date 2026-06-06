#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

INFO_PLIST_SOURCE="${REPO_ROOT}/packaging/SpacesRenamer-Info.plist"
LABEL="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST_SOURCE}")"
APP_DIR="${SPACES_RENAMER_APP_DIR:-${REPO_ROOT}/dist/SpacesRenamer.app}"
APP_EXECUTABLE="${APP_DIR}/Contents/MacOS/SpacesRenamer"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
BOOTSTRAP_DOMAIN="gui/$(id -u)"
BUILD_BEFORE_INSTALL=1

usage() {
    cat <<EOF
Usage: scripts/login-item.sh [install|uninstall|status] [--build|--no-build]

Commands:
  install     Package if needed, then start SpacesRenamer automatically at login.
  uninstall   Remove the automatic login launcher.
  status      Print whether the login launcher is installed and loaded.

Options:
  --build      Package before install. This is the default.
  --no-build   Reuse the existing app bundle.

Environment:
  SPACES_RENAMER_APP_DIR=/Applications/SpacesRenamer.app
    Point the login launcher at a different app bundle path.

Examples:
  scripts/login-item.sh install
  scripts/login-item.sh status
  scripts/login-item.sh uninstall
  SPACES_RENAMER_APP_DIR=/Applications/SpacesRenamer.app scripts/login-item.sh install --no-build
EOF
}

action="${1:-status}"
if [[ $# -gt 0 && "$1" != --* ]]; then
    shift
else
    action="status"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            BUILD_BEFORE_INSTALL=1
            ;;
        --no-build)
            BUILD_BEFORE_INSTALL=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
    shift
done

package_app() {
    if [[ "${BUILD_BEFORE_INSTALL}" == "1" && "${APP_DIR}" == "${REPO_ROOT}/dist/SpacesRenamer.app" ]]; then
        "${SCRIPT_DIR}/package-app.sh"
    fi
}

require_app_bundle() {
    if [[ ! -x "${APP_EXECUTABLE}" ]]; then
        printf 'Missing app bundle executable: %s\n' "${APP_EXECUTABLE}" >&2
        printf 'Run scripts/package-app.sh, or set SPACES_RENAMER_APP_DIR to an existing app bundle.\n' >&2
        exit 66
    fi
}

write_plist() {
    install -d "${LAUNCH_AGENTS_DIR}"

    cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>${APP_DIR}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

    plutil -lint "${PLIST_PATH}" >/dev/null
}

unload_agent() {
    launchctl bootout "${BOOTSTRAP_DOMAIN}" "${PLIST_PATH}" >/dev/null 2>&1 || true
    launchctl remove "${LABEL}" >/dev/null 2>&1 || true
}

load_agent() {
    unload_agent
    launchctl bootstrap "${BOOTSTRAP_DOMAIN}" "${PLIST_PATH}"
}

is_loaded() {
    launchctl print "${BOOTSTRAP_DOMAIN}/${LABEL}" >/dev/null 2>&1
}

install_agent() {
    package_app
    require_app_bundle
    write_plist
    load_agent
    printf 'Installed login launcher: %s\n' "${PLIST_PATH}"
    printf 'It opens: %s\n' "${APP_DIR}"
}

uninstall_agent() {
    unload_agent
    rm -f "${PLIST_PATH}"
    printf 'Removed login launcher: %s\n' "${PLIST_PATH}"
}

status_agent() {
    if [[ -f "${PLIST_PATH}" ]]; then
        printf 'Login launcher plist: %s\n' "${PLIST_PATH}"
    else
        printf 'Login launcher plist: not installed\n'
    fi

    if is_loaded; then
        printf 'LaunchAgent status: loaded\n'
    else
        printf 'LaunchAgent status: not loaded\n'
    fi

    printf 'App bundle path: %s\n' "${APP_DIR}"
}

case "${action}" in
    install)
        install_agent
        ;;
    uninstall|remove)
        uninstall_agent
        ;;
    status)
        status_agent
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        printf 'Unknown command: %s\n\n' "${action}" >&2
        usage >&2
        exit 64
        ;;
esac
