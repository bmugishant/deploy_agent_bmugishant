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
update_thresholds() {
    local answer warning failure
    local config="$PROJECT_DIR/Helpers/config.json"

    while true; do
        read -rp "Update alert thresholds? (y/n): " answer || return 1

        case "$answer" in
            y|Y) break ;;
            n|N)
                echo "Keeping default thresholds: warning 75, failure 50."
                return 0
                ;;
            *) echo "Please enter y or n." ;;
        esac
    done

    while true; do
        read -rp "Warning threshold [75]: " warning || return 1
        warning="${warning:-75}"

        if [[ "$warning" =~ ^[0-9]{1,3}$ ]]; then
            warning=$((10#$warning))
            if (( warning <= 100 )); then
                break
            fi
        fi
        echo "Enter whole number from 0 to 100."
    done

    while true; do
        read -rp "Failure threshold [50]: " failure || return 1
        failure="${failure:-50}"

        if [[ "$failure" =~ ^[0-9]{1,3}$ ]]; then
            failure=$((10#$failure))
            if (( failure <= warning )); then
                break
            fi
        fi

        echo "Enter a whole number from 0 to $warning."
    done

    sed -i -E \
        -e "s/(\"warning\"[[:space:]]*:[[:space:]]*)[0-9]+/\1${warning}/" \
        -e "s/(\"failure\"[[:space:]]*:[[:space:]]*)[0-9]+/\1${failure}/" \
        "$config" || {
            echo "ERROR: could not update thresholds." >&2
            return 1
        }

    echo "Thresholds updated: warning $warning%, failure $failure%."
}
interrupt_deployment() {
    local signal="$1"
    local archive="${PROJECT_DIR}_archive.zip"
    local temp_dir

    # Prevent another interrupt during archiving.
    trap '' INT TSTP

    echo
    echo "Deployment interrupted by $signal."

    if [[ -d "$PROJECT_DIR" ]]; then
        temp_dir="$(mktemp -d)" || exit 1

        if zip -qr "$temp_dir/project.zip" "$PROJECT_DIR" &&
           mv -f "$temp_dir/project.zip" "$archive"; then
            echo "Incomplete project archived: $archive"

            if rm -rf -- "$PROJECT_DIR"; then
                echo "Incomplete project directory removed."
            else
                echo "ERROR: could not remove incomplete directory." >&2
            fi
        else
            echo "ERROR: archiving failed; project directory retained." >&2
        fi

        rm -rf -- "$temp_dir"
    else
        echo "No project directory was created."
    fi

    case "$signal" in
        SIGINT) exit 130 ;;
        SIGTSTP) exit 148 ;;
    esac
}
deploy() (
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
    trap 'interrupt_deployment SIGINT' INT
    trap 'interrupt_deployment SIGTSTP' TSTP

    mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" || {
        echo "ERROR: could not create directories." >&2;
        return 1
    }

  copy_templates || return 1
    build_roster || return 1
    set_permissions || return 1
update_thresholds || return 1

 echo "Created structure:"
    ls -R "$PROJECT_DIR"
 trap - INT TSTP
echo "Starting the application to verify deployment..."
    run_app "$PROJECT_DIR" || return 1
)

run_app() {
    local name
    local project_dir="${1:-}"

    # Menu option 2 asks which project to run.
   if [[ -z "$project_dir" ]]; then
        read -rp "Enter project name: " name || return 1

        if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo "ERROR: invalid project name." >&2
            return 1
        fi

        project_dir="attendance_tracker_${name}"
    fi

    if [[ ! -f "$project_dir/attendance_checker.py" ]]; then
        echo "ERROR: application not found in $project_dir." >&2
        return 1
    fi

    # A subshell keeps the main script in its original directory.
    (
        cd "$project_dir" || exit 1
        python3 attendance_checker.py
    )
}

archive_logs() {
    local name project_dir timestamp log source destination

    read -rp "Enter project name: " name || return 1

    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "ERROR: invalid project name." >&2
        return 1
    fi

    project_dir="attendance_tracker_${name}"

    if [[ ! -d "$project_dir" ]]; then
        echo "ERROR: project $project_dir does not exist." >&2
        return 1
    fi

    timestamp="$(date +%Y%m%d_%H%M%S)" || return 1

    # Avoid overwriting archives created within the same second.
    while [[ -e "$project_dir/archives/attendance/attendance_${timestamp}.log" ||
             -e "$project_dir/archives/absent/absent_${timestamp}.log" ]]; do
        sleep 1
        timestamp="$(date +%Y%m%d_%H%M%S)" || return 1
    done

    for log in attendance absent; do
        source="$project_dir/reports/${log}.log"

        if [[ ! -f "$source" ]]; then
            echo "No ${log}.log found; skipping."
            continue
        fi
        mkdir -p "$project_dir/archives/$log" || {
            echo "ERROR: could not create archive directory." >&2
            return 1
        }

        destination="$project_dir/archives/$log/${log}_${timestamp}.log"

        cp "$source" "$destination" || {
            echo "ERROR: could not archive $source." >&2
            return 1
        }

        echo "Archived: $destination"
    done
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
trap ':' TSTP
main_menu
