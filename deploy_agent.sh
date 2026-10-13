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
       # 1. Ask for a valid project name (loop until it is valid)
    while true; do
        read -rp "Enter project name: " name
        if [[ "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
            break
        fi
        echo "Invalid name. Use letters, numbers, - or _ only (no spaces)."
    done

    # 2. Set the project directory (global, no 'local', so the Stage 8 trap can use it)
    PROJECT_DIR="attendance_tracker_${name}"

    # 3. Protect against overwriting an existing project
    if [[ -d "$PROJECT_DIR" ]]; then
        read -rp "$PROJECT_DIR already exists. Overwrite? (y/n): " answer
        if [[ "$answer" == "y" ]]; then
            rm -rf "$PROJECT_DIR"
        else
            echo "Aborted. Existing project left untouched."
            return 1
        fi
    fi

    # 4. Create the structure, and stop with an error if it fails
    mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" || { echo "ERROR: could not create directories." >&2; return 1; }

    echo "Created structure:"
    ls -R "$PROJECT_DIR"
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
