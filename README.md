# Attendance Tracker Deploy Agent

A Bash script that deploys the provided Student Attendance Tracker, runs interactive marking sessions, and archives generated logs.

## Requirements

- Linux with Bash and standard command-line utilities
- Python 3
- zip
- Git for version control

The script checks that `python3` and `zip` are installed before displaying the menu.

## Repository Files

- `deploy_agent.sh`: deployment, execution, log archiving, and interrupt handling.
- `templates/attendance_checker.py`: provided Python application.
- `templates/assets.csv`: provided sample roster.
- `templates/config.json`: provided default configuration.

The template files should remain unchanged. Configuration updates apply to deployed copies.

## Getting Started

Clone the repository and run the script from its root directory:

```bash
git clone https://github.com/bmugishant/deploy_agent_bmugishant.git
cd deploy_agent_bmugishant
chmod +x deploy_agent.sh
./deploy_agent.sh
```

If the implementation has not yet been merged into the default branch, switch to:

```bash
git switch feature/deploy-script
```

## Menu Options

| Option | Action |
|---|---|
| 1 | Deploy the application and automatically run it |
| 2 | Run an existing deployed application |
| 3 | Archive an existing project's logs |
| 4 | Quit |

When prompted for a project name, enter only the suffix. For example, enter `demo` for `attendance_tracker_demo`.

Project names accept letters, numbers, underscores, and hyphens. Names are case-sensitive.

## Deployment

Option 1 asks for a project name and creates:

```text
attendance_tracker_demo/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/
```

The script asks before overwriting an existing project. Declining leaves the existing project untouched.

The Python application and configuration are copied from `templates/`. The script then builds the roster, sets permissions, offers threshold updates, and starts the application to verify deployment.

### Roster Options

**Option A — Copy from the template**

Copies the CSV header and the requested number of student rows from the sample roster. Each sample student has four prior sessions, so the deployed configuration starts with `total_sessions: 5`.

**Option B — Generate a fresh roster**

Creates students from sample names and emails defined in the shell script. Attendance and absence counts start at zero, so the deployed configuration starts with `total_sessions: 1`.

Both options accept between 1 and 10 students.

`total_sessions` includes the session being marked and must be one greater than the number of prior sessions recorded for each student.

### Permissions

The script makes `attendance_checker.py` executable and sets `Helpers/config.json` to `600`.

Permission `600` allows only the file owner to read and write the configuration.

### Threshold Updates

During deployment, the script asks whether to update the alert thresholds.

- Warning default: `75`
- Failure default: `50`
- Pressing Enter at a threshold prompt uses its default.
- Values must be whole numbers from 0 to 100.
- The failure threshold cannot exceed the warning threshold.

The script uses `sed` to replace the numbers associated with `"warning"` and `"failure"` in the deployed configuration. It preserves the surrounding formatting and does not reorder the file.

## Running the Application

Option 2 asks for an existing project name and runs:

```bash
cd attendance_tracker_demo
python3 attendance_checker.py
```

The instructor marks each student present or absent using the application's prompts.

The application updates the roster and writes logs into `reports/`. A subshell allows the deployment agent to retain its original working directory after execution.

Before another marking session, check that `total_sessions` remains consistent with the roster. Do not assume that the deployment default is appropriate for every later session.

## Log Archiving

Option 3 copies each existing log into its own archive folder:

```text
attendance_tracker_demo/
└── archives/
    ├── attendance/
    │   └── attendance_YYYYMMDD_HHMMSS.log
    └── absent/
        └── absent_YYYYMMDD_HHMMSS.log
```

The timestamp uses the server's clock.

Original logs remain in `reports/`. If an archive filename already exists for the current second, the script waits for another timestamp to avoid overwriting it.

Missing logs are reported and skipped. A nonexistent project produces a clear error and returns to the menu.

## Deployment Interrupt Handling

During project creation and setup:

- Ctrl+C sends `SIGINT`.
- Ctrl+Z sends `SIGTSTP`.

The deployment traps either signal, prints an interruption message, and uses `zip` to save the incomplete project as:

```text
attendance_tracker_demo_archive.zip
```

The ZIP contains the project directory and whatever files have been created at the time of interruption.

The incomplete directory is removed only after successful ZIP creation and placement. If archiving fails, the project directory is retained.

Deployment runs in a subshell. The parent menu catches `SIGTSTP` so it does not remain suspended while deployment handles Ctrl+Z.

The deployment traps are reset before Python execution. Deployment cleanup therefore does not apply to an interrupted marking session.

## Verification

Syntax and whitespace checks:

```bash
bash -n deploy_agent.sh
git diff --check
```

After a normal deployment, inspect the structure, configuration, permissions, and roster:

```bash
find attendance_tracker_demo -maxdepth 2 -type f
python3 -m json.tool attendance_tracker_demo/Helpers/config.json
stat -c '%a %n' attendance_tracker_demo/attendance_checker.py
stat -c '%a %n' attendance_tracker_demo/Helpers/config.json
cat attendance_tracker_demo/Helpers/assets.csv
```

Confirm that the deployed Python application matches its template:

```bash
cmp templates/attendance_checker.py attendance_tracker_demo/attendance_checker.py
```

A successful interactive marking session verifies that the application can use the deployed structure, roster, and configuration.

### Interrupt Test Procedure

1. Run `./deploy_agent.sh`.
2. Choose option 1.
3. Use a new project name, such as `interrupt_demo`.
4. Press Ctrl+C at the roster prompt.
5. Confirm the interruption message, ZIP creation, and directory removal.
6. Quit the menu and verify:

```bash
zip -T attendance_tracker_interrupt_demo_archive.zip
test ! -d attendance_tracker_interrupt_demo && echo "Cleanup passed"
```

Repeat with a different project name and Ctrl+Z. Confirm that the script does not report a stopped job.

### Additional Checks

Before submission, verify:

- Both roster options.
- Invalid and default threshold inputs.
- Refusing to overwrite an existing project.
- Automatic application execution after deployment.
- Standalone execution through option 2.
- Archiving both logs and repeating archiving.
- Graceful handling of missing logs and nonexistent projects.
- Ctrl+C and Ctrl+Z ZIP creation and cleanup.

## Version Control

Development is organized on `feature/deploy-script`, with separate commits for roster creation, permissions, threshold updates, application execution, log archiving, and interrupt handling.

Inspect the history with:

```bash
git log --oneline --graph --all
```

## Walkthrough Video

