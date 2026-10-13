#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
preflight_checks() {
    for tool in python3 zip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "ERROR: $tool is not installed." >&2
            exit 1
        fi
    done
    python3 --version  
}
copy_templates() {
    for f in attendance_checker.py config.json; do
        if [[ ! -f "$SCRIPT_DIR/templates/$f" ]]; then
            echo "ERROR: template $f not found." >&2
            return 1
        fi
    done
    cp "$SCRIPT_DIR/templates/attendance_checker.py" "$PROJECT_DIR/" || return 1
    cp "$SCRIPT_DIR/templates/config.json" "$PROJECT_DIR/Helpers/" || return 1
}
build_roster() {
    local choice count
    while true; do
        echo "Roster: A) copy from template  B) generate fresh roster"
        read -rp "Choose A or B: " choice
        [[ "$choice" =~ ^[ABab]$ ]] && break
        echo "Please enter A or B."
    done

    while true; do
        read -rp "How many students (1-10)? " count
        if [[ "$count" =~ ^[0-9]+$ ]] && (( count >= 1 && count <= 10 )); then
            break
        fi
        echo "Enter a number from 1 to 10."
    done

    local roster="$PROJECT_DIR/Helpers/assets.csv"
    local config="$PROJECT_DIR/Helpers/config.json"

    if [[ "$choice" =~ ^[Aa]$ ]]; then
        head -n $((count + 1)) "$SCRIPT_DIR/templates/assets.csv" > "$roster"
    else
        local names=("Alice Johnson" "Bob Smith" "Charlie Davis" "Diana Prince" "Ethan Cole" "Fatima Noor" "George Mensah" "Hannah Kim" "Ibrahim Osei" "Jasmine Lee")
        local emails=(alice@example.com bob@example.com charlie@example.com diana@example.com ethan@example.com fatima@example.com george@example.com hannah@example.com ibrahim@example.com jasmine@example.com)
        echo "Email,Names,Attendance Count,Absence Count" > "$roster"
        for ((i = 0; i < count; i++)); do
            echo "${emails[i]},${names[i]},0,0" >> "$roster"
        done
        sed -i 's/"total_sessions": 5/"total_sessions": 1/' "$config"
    fi
    echo "Roster created with $count student(s)."
}
set_permissions() {
    chmod +x "$PROJECT_DIR/attendance_checker.py" || { echo "ERROR: chmod failed on attendance_checker.py" >&2; return 1; }
    chmod 600 "$PROJECT_DIR/Helpers/config.json" || { echo "ERROR: chmod failed on config.json" >&2; return 1; }

    echo "Permissions set:"
    ls -l "$PROJECT_DIR/attendance_checker.py" "$PROJECT_DIR/Helpers/config.json"
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

  copy_templates || return 1
    build_roster || return 1
    set_permissions || return 1      
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
