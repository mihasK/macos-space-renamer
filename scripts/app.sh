#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PRODUCT_NAME="SpacesRenamer"
APP_DIR="${REPO_ROOT}/dist/SpacesRenamer.app"
APP_EXECUTABLE="${APP_DIR}/Contents/MacOS/${PRODUCT_NAME}"
BUILD_BEFORE_START=1

usage() {
    cat <<EOF
Usage: scripts/app.sh [start|stop|restart|status] [--build|--no-build]

Commands:
  start     Package if needed, then open the app if it is not running.
  stop      Quit the running app process.
  restart   Package if needed, quit the app, then open it again.
  status    Print whether the app is running.

Aliases:
  run       Same as start.
  rerun     Same as restart.
  quit      Same as stop.

Options:
  --build      Package before start/restart. This is the default.
  --no-build   Reuse the existing dist/SpacesRenamer.app bundle.

Examples:
  scripts/app.sh start
  scripts/app.sh restart
  scripts/app.sh stop
  scripts/app.sh status
  CONFIGURATION=release scripts/app.sh restart
EOF
}

action="${1:-start}"
if [[ $# -gt 0 && "$1" != --* ]]; then
    shift
else
    action="start"
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            BUILD_BEFORE_START=1
            ;;
        --no-build)
            BUILD_BEFORE_START=0
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

pids() {
    pgrep -x "${PRODUCT_NAME}" || true
}

pid_list() {
    local running
    running="$(pids)"

    if [[ -z "${running}" ]]; then
        printf 'none'
    else
        printf '%s' "${running}" | paste -sd ', ' -
    fi
}

package_app() {
    if [[ "${BUILD_BEFORE_START}" == "1" || ! -x "${APP_EXECUTABLE}" ]]; then
        "${SCRIPT_DIR}/package-app.sh"
    fi
}

wait_for_start() {
    local attempt

    for attempt in {1..50}; do
        if [[ -n "$(pids)" ]]; then
            printf 'SpacesRenamer is running (pid %s).\n' "$(pid_list)"
            return 0
        fi

        sleep 0.1
    done

    printf 'SpacesRenamer did not start within 5 seconds.\n' >&2
    return 1
}

wait_for_stop() {
    local attempt

    for attempt in {1..50}; do
        if [[ -z "$(pids)" ]]; then
            printf 'SpacesRenamer is stopped.\n'
            return 0
        fi

        sleep 0.1
    done

    printf 'SpacesRenamer is still running (pid %s).\n' "$(pid_list)" >&2
    return 1
}

start_app() {
    if [[ -n "$(pids)" ]]; then
        printf 'SpacesRenamer is already running (pid %s).\n' "$(pid_list)"
        return 0
    fi

    package_app
    open -n "${APP_DIR}"
    wait_for_start
}

stop_app() {
    local running
    running="$(pids)"

    if [[ -z "${running}" ]]; then
        printf 'SpacesRenamer is not running.\n'
        return 0
    fi

    printf '%s\n' "${running}" | while IFS= read -r pid; do
        kill -TERM "${pid}" 2>/dev/null || true
    done

    wait_for_stop
}

status_app() {
    if [[ -n "$(pids)" ]]; then
        printf 'SpacesRenamer is running (pid %s).\n' "$(pid_list)"
    else
        printf 'SpacesRenamer is not running.\n'
    fi
}

case "${action}" in
    start|run)
        start_app
        ;;
    stop|quit)
        stop_app
        ;;
    restart|rerun)
        package_app
        stop_app
        BUILD_BEFORE_START=0
        start_app
        ;;
    status)
        status_app
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
