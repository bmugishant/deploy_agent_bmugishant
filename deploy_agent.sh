#!/bin/bash

preflight_checks() {
    for tool in python3 zip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "ERROR: $tool is not installed." >&2
            exit 1
        fi
    done
    python3 --version  
}

deploy() {
    echo "TODO: deploy"
}

run_app() {
    echo "TODO: run"
}

archive_logs() {
    echo "TODO: archive"
}

# ---------- Menu ----------
main_menu() {
    while true; do
        echo ""
        echo "=== Attendance Tracker Deploy Agent ==="
        echo "1) Deploy the application"
        echo "2) Run the application"
        echo "3) Archive log files"
        echo "4) Quit"
        read -rp "Choose an option: " choice

        case "$choice" in
            1) deploy ;;
            2)  run_app ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice. Enter 1-4." ;;
        esac
    done
}

# ---------- Start ----------
preflight_checks
main_menu
