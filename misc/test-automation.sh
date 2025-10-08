#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Automated Container Testing Script

set -eEuo pipefail

# Detect if running from ./misc directory and adjust to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$(basename "$SCRIPT_DIR")" == "misc" ]]; then
    # Running from ./misc, change to parent directory
    cd "$SCRIPT_DIR/.."
    echo "Detected running from ./misc directory, switching to project root: $(pwd)"
fi

# Color codes
RD='\033[01;31m'
GN='\033[1;92m'
YW='\033[1;93m'
BL='\033[36m'
CL='\033[m'
BOLD='\033[1m'

# Setup timestamp and logging
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="./logs/${TIMESTAMP}"
SCRIPT_LOG_DIR="${LOG_DIR}/scripts"
OUTPUT_LOG="${LOG_DIR}/output.log"
SUMMARY_LOG="${LOG_DIR}/summary.log"

# Concurrency / UI controls
MAX_CONCURRENCY="${MAX_CONCURRENCY:-4}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-1}"
LINES_PER_PANE="${LINES_PER_PANE:-10}"
USE_UI="${USE_UI:-auto}"  # auto|yes|no

# Result tracking
declare -a ACCESSIBLE_CONTAINERS=()
declare -a INACCESSIBLE_CONTAINERS=()
declare -a NOT_TESTED_CONTAINERS=()
declare -a SKIPPED_SCRIPTS=()
declare -a FAILED_CONTAINERS=()

# Create log directories
mkdir -p "${SCRIPT_LOG_DIR}"

# Function to log messages
log_msg() {
    echo -e "$1" | tee -a "${OUTPUT_LOG}"
}

log_info() {
    log_msg "${BL}[INFO]${CL} $1"
}

log_ok() {
    log_msg "${GN}[OK]${CL} $1"
}

log_error() {
    log_msg "${RD}[ERROR]${CL} $1"
}

log_warn() {
    log_msg "${YW}[WARN]${CL} $1"
}

# Check if running on Proxmox
if ! command -v pveversion >/dev/null 2>&1; then
    log_error "This script must be run on a Proxmox VE host"
    exit 1
fi

# Parse statuses.json for 🧪 scripts
log_info "Reading statuses.json for test scripts (🧪 status)..."

if [[ ! -f "frontend/public/json/statuses.json" ]]; then
    log_error "statuses.json not found at frontend/public/json/statuses.json"
    exit 1
fi

# Extract scripts with 🧪 status
TEST_SCRIPTS=$(jq -r 'to_entries[] | select(.value == "🧪") | .key' frontend/public/json/statuses.json | sed 's/\.json$//')

if [[ -z "$TEST_SCRIPTS" ]]; then
    log_warn "No scripts found with 🧪 status"
    exit 0
fi

log_ok "Found $(echo "$TEST_SCRIPTS" | wc -l) scripts to test"

# Convert test scripts to array for scheduling
mapfile -t SCRIPT_LIST <<< "$TEST_SCRIPTS"

# Determine if we should render UI (only if stdout is a TTY)
if [[ "$USE_UI" == "auto" ]]; then
    if [ -t 1 ]; then
        USE_UI="yes"
    else
        USE_UI="no"
    fi
fi

# Initialize base ID for concurrent-safe allocation
BASE_ID=$(pvesh get /cluster/nextid)
ID_LOCK_FILE="${LOG_DIR}/.id.lock"
ID_COUNTER_FILE="${LOG_DIR}/.id.counter"
echo -n "${BASE_ID}" > "${ID_COUNTER_FILE}"

# Allocate a unique, currently free CT ID (concurrency-safe)
allocate_container_id() {
    local fd id
    exec {fd}>"${ID_LOCK_FILE}"
    flock "${fd}"
    id=$(cat "${ID_COUNTER_FILE}" 2>/dev/null || echo "${BASE_ID}")
    # Find the next free ID
    while pct config "$id" &>/dev/null; do
        id=$((id+1))
    done
    # Reserve next ID for subsequent calls
    echo -n $((id+1)) > "${ID_COUNTER_FILE}"
    flock -u "${fd}"
    eval "exec ${fd}>&-"
    echo "$id"
}

# UI helpers
hide_cursor() { tput civis 2>/dev/null || true; }
show_cursor() { tput cnorm 2>/dev/null || true; }
clear_screen() { tput clear 2>/dev/null || printf "\033c"; }
move_cursor() { tput cup "$1" "$2" 2>/dev/null || printf "\033[$1;$2H"; }

# Draw the dashboard with a fixed number of panes equal to MAX_CONCURRENCY
draw_dashboard() {
    local cols=$(tput cols 2>/dev/null || echo 120)
    local rows=$(tput lines 2>/dev/null || echo 40)

    # Layout: up to 3 columns depending on terminal width
    local num_cols
    if (( cols >= 180 )); then
        num_cols=3
    elif (( cols >= 100 )); then
        num_cols=2
    else
        num_cols=1
    fi
    if (( MAX_CONCURRENCY < num_cols )); then
        num_cols=$MAX_CONCURRENCY
    fi
    (( num_cols == 0 )) && return

    local total=$MAX_CONCURRENCY
    local num_rows=$(( (total + num_cols - 1) / num_cols ))
    local header_rows=2
    local footer_rows=1
    local cell_h=$(( (rows - header_rows - footer_rows) / (num_rows > 0 ? num_rows : 1) ))
    local cell_w=$(( cols / (num_cols > 0 ? num_cols : 1) ))
    local content_h=$(( cell_h - 2 ))
    local content_w=$(( cell_w - 2 ))
    if (( content_h < 2 )); then content_h=2; fi
    if (( content_w < 20 )); then content_w=20; fi

    clear_screen
    move_cursor 0 0; printf "Concurrent Test Runner  |  Concurrency: %s  |  %s\n" "$MAX_CONCURRENCY" "$(date +%H:%M:%S)"
    printf "%.0s-" $(seq 1 "$cols"); printf "\n"

    local idx=0
    while (( idx < total )); do
        local r=$(( idx / num_cols ))
        local c=$(( idx % num_cols ))
        local top=$(( header_rows + r * cell_h ))
        local left=$(( c * cell_w ))

        local script="${SLOT_SCRIPT[$idx]:-}"
        local title=""
        local status="IDLE"
        local log_file=""
        local status_file=""
        if [[ -n "$script" ]]; then
            title="$script"
            log_file="${SCRIPT_LOG_DIR}/${script}.log"
            status_file="${SCRIPT_LOG_DIR}/${script}.status"
            if [[ -f "$status_file" ]]; then
                status=$(head -n1 "$status_file" | cut -d'|' -f1)
            else
                status="RUNNING"
            fi
        else
            title="Idle Slot"
        fi

        move_cursor "$top" "$left"; printf "[%s] %s\n" "$status" "$title"
        local start_y=$(( top + 1 ))
        if [[ -n "$script" && -f "$log_file" ]]; then
            local content
            content=$(tail -n "$content_h" "$log_file" 2>/dev/null | sed -e $'s/\t/  /g')
            local line_no=0
            while IFS= read -r line; do
                move_cursor $(( start_y + line_no )) "$left"
                printf "%s" "${line:0:$content_w}"
                line_no=$(( line_no + 1 ))
                (( line_no >= content_h )) && break
            done <<< "$content"
        else
            move_cursor "$start_y" "$left"; printf "(idle)"
        fi
        idx=$(( idx + 1 ))
    done

    # Footer: show currently testing scripts or next queued
    local footer_y=$(( rows - 1 ))
    local testing_line="Testing: "
    local any_running=0
    for i in $(seq 0 $(( MAX_CONCURRENCY - 1 ))); do
        if [[ -n "${SLOT_SCRIPT[$i]:-}" ]]; then
            testing_line+="${SLOT_SCRIPT[$i]}  "
            any_running=1
        fi
    done
    if (( any_running == 0 )); then
        if (( started_jobs < total_jobs )); then
            testing_line+="${SCRIPT_LIST[$started_jobs]} (queued)"
        else
            testing_line+="Done"
        fi
    fi
    move_cursor "$footer_y" 0
    printf "%s" "$testing_line"
}

# Function to extract HTTP URL from log file
extract_http_url() {
    local log_file="$1"
    # Look for http:// or https:// URLs in the log (with IP:PORT format)
    # Common patterns: http://192.168.1.100:8080, https://10.0.0.1:3000
    # Now supports HTTPS endpoints with self-signed certificates
    grep -oP 'https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' "$log_file" | tail -1
}

# Function to extract last completed step from log file
extract_last_step() {
    local log_file="$1"
    # Look for msg_ok messages (success indicators)
    # Also look for common success patterns
    local last_step=$(grep -E '\[OK\]|\[✓\]|msg_ok|✔️|Completed Successfully' "$log_file" | tail -1 | sed 's/.*\(msg_ok\|OK\|✓\|✔️\)//' | sed 's/^[^a-zA-Z]*//' | cut -c1-80)
    
    if [[ -n "$last_step" ]]; then
        echo "$last_step"
    else
        echo "No step information available"
    fi
}

# Function to monitor log and show current step
monitor_current_step() {
    local log_file="$1"
    local script_name="$2"
    local monitor_file="/tmp/monitor_${script_name}_$$.txt"
    
    # Background process to monitor log file
    (
        while [ -f "$monitor_file" ]; do
            if [ -f "$log_file" ]; then
                # Look for lines with hourglass emoji (⏳) which indicates current operation
                # Also look for msg_info patterns as fallback
                local current=$(grep -E '⏳|msg_info|Installing|Setting up|Configuring|Downloading|Building|Starting' "$log_file" | tail -1 | sed 's/.*⏳[[:space:]]*//' | sed 's/.*msg_info[[:space:]]*//' | sed 's/^[[:space:]]*//' | cut -c1-70)
                if [[ -n "$current" ]]; then
                    printf "\r\033[K%b[CURRENT]%b %s: %s" "${BL}" "${CL}" "${script_name}" "${current}"
                fi
            fi
            sleep 1
        done
        printf "\r\033[K"
    ) &
    
    echo "$!" > "$monitor_file"
}

# Function to stop monitoring
stop_monitor() {
    local script_name="$1"
    local monitor_file="/tmp/monitor_${script_name}_$$.txt"
    
    if [ -f "$monitor_file" ]; then
        local pid=$(cat "$monitor_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$monitor_file"
    fi
    printf "\r\033[K"
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local timeout=10
    
    # Try to connect to the URL
    # -k/--insecure allows HTTPS with invalid/self-signed certificates
    if curl -s -k --max-time "$timeout" --connect-timeout "$timeout" -o /dev/null -w "%{http_code}" "$url" | grep -qE "^(200|301|302|401|403)"; then
        return 0
    else
        return 1
    fi
}

# Function to cleanup container on failure
cleanup_container() {
    local ctid="$1"
    if pct status "$ctid" &>/dev/null; then
        log_warn "Cleaning up container $ctid"
        pct stop "$ctid" 2>/dev/null || true
        sleep 2
        pct destroy "$ctid" 2>/dev/null || true
    fi
}

# Function to create wrapper script for automated testing
create_wrapper_script() {
    local original_script="$1"
    local wrapper_script="$2"
    
    # Create a wrapper that sources auto-build.func instead of build.func
    cat > "${wrapper_script}" <<'WRAPPER_EOF'
#!/usr/bin/env bash
# Automated testing wrapper - sources auto-build.func instead of build.func

# Read the original script and replace build.func with auto-build.func
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_SCRIPT="ORIGINAL_SCRIPT_PATH"

# Create temp file with modified source
TEMP_SCRIPT=$(mktemp)
sed 's|https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func|file://'"${SCRIPT_DIR}"'/misc/auto-build.func|g' "$ORIGINAL_SCRIPT" > "$TEMP_SCRIPT"

# Execute the modified script
bash "$TEMP_SCRIPT"
EXIT_CODE=$?

# Cleanup
rm -f "$TEMP_SCRIPT"
exit $EXIT_CODE
WRAPPER_EOF
    
    # Replace placeholder with actual path
    sed -i "s|ORIGINAL_SCRIPT_PATH|${original_script}|g" "${wrapper_script}"
    chmod +x "${wrapper_script}"
}

# Function to test a single script
test_script() {
    local script_name="$1"
    local script_path="ct/${script_name}.sh"
    local script_log="${SCRIPT_LOG_DIR}/${script_name}.log"
    local wrapper_script="/tmp/test_wrapper_${script_name}_$$.sh"
    local status_file="${SCRIPT_LOG_DIR}/${script_name}.status"
    
    log_info "==================== Testing: ${script_name} ===================="
    
    # Mark as running
    echo "RUNNING" > "$status_file"

    # Skip alpine scripts
    if [[ "$script_name" =~ alpine ]]; then
        log_warn "Skipping alpine script: ${script_name}"
        echo "SKIPPED|alpine" > "$status_file"
        SKIPPED_SCRIPTS+=("${script_name} (alpine - skipped)")
        return
    fi
    
    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_warn "Script not found: ${script_path}"
        echo "SKIPPED|not_found" > "$status_file"
        SKIPPED_SCRIPTS+=("${script_name} (not found)")
        return
    fi
    
    # Get next available container ID
    local next_id=$(allocate_container_id)
    log_info "Using container ID: ${next_id}"
    
    # Set environment variables for non-interactive execution
    export VERBOSE="yes"
    export DIAGNOSTICS="no"
    export var_verbose="yes"
    export AUTO_TEST_MODE="yes"
    
    # Create wrapper script (but use direct execution for simplicity)
    log_info "Starting container creation for ${script_name}..."
    
    # Temporarily replace build.func reference in script
    TEMP_SCRIPT=$(mktemp)
    sed 's|source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)|source misc/auto-build.func|g' "${script_path}" > "$TEMP_SCRIPT"
    
    # Ensure child uses our allocated CTID
    export var_ctid="${next_id}"

    # Run the script and capture output
    if bash "${TEMP_SCRIPT}" > "${script_log}" 2>&1; then
        rm -f "$TEMP_SCRIPT"
        log_ok "Container creation completed for ${script_name}"
        
        # Extract last completed step
        local last_step=$(extract_last_step "${script_log}")
        log_info "Last step: ${last_step}"
        
        # Extract HTTP URL from log
        local http_url=$(extract_http_url "${script_log}")
        
        if [[ -n "$http_url" ]]; then
            log_info "Found HTTP endpoint: ${http_url}"
            
            # Wait a bit for service to start
            log_info "Waiting 5 seconds for service to initialize..."
            sleep 5
            
            # Test the endpoint
            if test_http_endpoint "$http_url"; then
                log_ok "HTTP endpoint is accessible: ${http_url}"
                echo "ACCESSIBLE|${next_id}|${http_url}|${last_step}" > "$status_file"
                ACCESSIBLE_CONTAINERS+=("${script_name}:${next_id}:${http_url}:${last_step}")
            else
                log_error "HTTP endpoint is not accessible: ${http_url}"
                echo "INACCESSIBLE|${next_id}|${http_url}|${last_step}" > "$status_file"
                INACCESSIBLE_CONTAINERS+=("${script_name}:${next_id}:${http_url}:${last_step}")
            fi
        else
            log_warn "No HTTP endpoint found in output"
            echo "NOT_TESTED|${next_id}||${last_step}" > "$status_file"
            NOT_TESTED_CONTAINERS+=("${script_name}:${next_id}:${last_step}")
        fi
        
        # Stop the container after testing
        log_info "Stopping container ${next_id}..."
        pct stop "${next_id}" 2>/dev/null || true
        
    else
        log_error "Container creation failed for ${script_name}"
        
        # Extract last completed step even on failure
        local last_step=$(extract_last_step "${script_log}")
        log_error "Last completed step: ${last_step}"
        
        echo "FAILED|${next_id}||${last_step}" > "$status_file"
        FAILED_CONTAINERS+=("${script_name}:${next_id}:${last_step}")
        rm -f "$TEMP_SCRIPT"
        
        # Try to cleanup failed container
        cleanup_container "${next_id}"
    fi
    
    # Cleanup wrapper if it exists
    rm -f "${wrapper_script}"
    
    log_info "==================== Finished: ${script_name} ====================\n"
}

# Main concurrent testing controller
log_info "Starting automated container testing..."
log_info "Log directory: ${LOG_DIR}"
log_info ""

declare -A JOB_PIDS=()
declare -A JOB_STARTED=()
declare -a SLOT_SCRIPT=()
for i in $(seq 0 $(( MAX_CONCURRENCY - 1 ))); do SLOT_SCRIPT[$i]=""; done

total_jobs=${#SCRIPT_LIST[@]}
started_jobs=0
finished_jobs=0

if [[ "$USE_UI" == "yes" ]]; then
    hide_cursor
    clear_screen
fi

while (( finished_jobs < total_jobs )); do
    # Launch new jobs up to MAX_CONCURRENCY
    while (( started_jobs < total_jobs )) && (( ${#JOB_PIDS[@]} < MAX_CONCURRENCY )); do
        # Find a free slot
        free_slot=-1
        for i in $(seq 0 $(( MAX_CONCURRENCY - 1 ))); do
            if [[ -z "${SLOT_SCRIPT[$i]}" ]]; then
                free_slot=$i; break
            fi
        done
        (( free_slot == -1 )) && break

        script="${SCRIPT_LIST[$started_jobs]}"
        JOB_STARTED["$script"]=1
        SLOT_SCRIPT[$free_slot]="$script"
        # Ensure log/status files exist
        : > "${SCRIPT_LOG_DIR}/${script}.log"
        echo "QUEUED" > "${SCRIPT_LOG_DIR}/${script}.status"
        # Start job
        test_script "$script" &
        pid=$!
        JOB_PIDS["$script"]=$pid
        started_jobs=$(( started_jobs + 1 ))
        # Small stagger to avoid thundering herd
        sleep 1
    done

    # Draw UI
    if [[ "$USE_UI" == "yes" ]]; then
        draw_dashboard SCRIPT_LIST
        # Footer with counts
        move_cursor $(($(tput lines 2>/dev/null || echo 40)-1)) 0
        printf "Running: %d  |  Finished: %d  |  Total: %d\r" "${#JOB_PIDS[@]}" "$finished_jobs" "$total_jobs"
    fi

    # Check for finished jobs
    for s in "${!JOB_PIDS[@]}"; do
        if ! kill -0 "${JOB_PIDS[$s]}" 2>/dev/null; then
            unset 'JOB_PIDS[$s]'
            # free its slot
            for i in $(seq 0 $(( MAX_CONCURRENCY - 1 ))); do
                if [[ "${SLOT_SCRIPT[$i]:-}" == "$s" ]]; then
                    SLOT_SCRIPT[$i]=""
                    break
                fi
            done
            finished_jobs=$(( finished_jobs + 1 ))
        fi
    done

    sleep "$REFRESH_INTERVAL"
done

if [[ "$USE_UI" == "yes" ]]; then
    show_cursor
    printf "\n"
fi

# Regenerate arrays from status files for summary
ACCESSIBLE_CONTAINERS=()
INACCESSIBLE_CONTAINERS=()
NOT_TESTED_CONTAINERS=()
FAILED_CONTAINERS=()
SKIPPED_SCRIPTS=()

for script in "${SCRIPT_LIST[@]}"; do
    status_file="${SCRIPT_LOG_DIR}/${script}.status"
    [[ ! -f "$status_file" ]] && continue
    IFS='|' read -r status id url last_step < "$status_file"
    case "$status" in
        ACCESSIBLE)
            ACCESSIBLE_CONTAINERS+=("${script}:${id}:${url}:${last_step}")
            ;;
        INACCESSIBLE)
            INACCESSIBLE_CONTAINERS+=("${script}:${id}:${url}:${last_step}")
            ;;
        NOT_TESTED)
            NOT_TESTED_CONTAINERS+=("${script}:${id}:${last_step}")
            ;;
        FAILED)
            FAILED_CONTAINERS+=("${script}:${id}:${last_step}")
            ;;
        SKIPPED)
            SKIPPED_SCRIPTS+=("${script} ($(echo "$id"))")
            ;;
    esac
done

# Generate summary report
log_info ""
log_info "==================== TESTING SUMMARY ===================="

# Generate detailed summary for terminal/summary.log
{
    echo "=========================================="
    echo "Automated Container Testing Summary"
    echo "Timestamp: ${TIMESTAMP}"
    echo "=========================================="
    echo ""
    
    echo "ACCESSIBLE CONTAINERS (${#ACCESSIBLE_CONTAINERS[@]}):"
    if [[ ${#ACCESSIBLE_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${ACCESSIBLE_CONTAINERS[@]}"; do
            IFS=':' read -r name id url last_step <<< "$item"
            echo "  ✅ ${name} (CT:${id}) - ${url}"
            echo "     Last step: ${last_step}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "INACCESSIBLE CONTAINERS (${#INACCESSIBLE_CONTAINERS[@]}):"
    if [[ ${#INACCESSIBLE_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${INACCESSIBLE_CONTAINERS[@]}"; do
            IFS=':' read -r name id url last_step <<< "$item"
            echo "  ❌ ${name} (CT:${id}) - ${url}"
            echo "     Last step: ${last_step}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "NOT TESTED (no HTTP endpoint found) (${#NOT_TESTED_CONTAINERS[@]}):"
    if [[ ${#NOT_TESTED_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${NOT_TESTED_CONTAINERS[@]}"; do
            IFS=':' read -r name id last_step <<< "$item"
            echo "  ⚠️  ${name} (CT:${id})"
            echo "     Last step: ${last_step}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "FAILED CONTAINERS (${#FAILED_CONTAINERS[@]}):"
    if [[ ${#FAILED_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${FAILED_CONTAINERS[@]}"; do
            IFS=':' read -r name id last_step <<< "$item"
            echo "  💥 ${name} (CT:${id})"
            echo "     Last completed step: ${last_step}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "SKIPPED SCRIPTS (${#SKIPPED_SCRIPTS[@]}):"
    if [[ ${#SKIPPED_SCRIPTS[@]} -gt 0 ]]; then
        for item in "${SKIPPED_SCRIPTS[@]}"; do
            echo "  ⏭️  ${item}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    echo "=========================================="
    echo "Total Scripts Processed: $(( ${#ACCESSIBLE_CONTAINERS[@]} + ${#INACCESSIBLE_CONTAINERS[@]} + ${#NOT_TESTED_CONTAINERS[@]} + ${#FAILED_CONTAINERS[@]} + ${#SKIPPED_SCRIPTS[@]} ))"
    echo "Success Rate: $(( ${#ACCESSIBLE_CONTAINERS[@]} * 100 / (${#ACCESSIBLE_CONTAINERS[@]} + ${#INACCESSIBLE_CONTAINERS[@]} + ${#NOT_TESTED_CONTAINERS[@]} + ${#FAILED_CONTAINERS[@]} + 1) ))%"
    echo "=========================================="
    
} | tee "${SUMMARY_LOG}"

# Generate simplified output.log in the requested format
{
    echo "successful and http accessible:"
    if [[ ${#ACCESSIBLE_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${ACCESSIBLE_CONTAINERS[@]}"; do
            IFS=':' read -r name id url last_step <<< "$item"
            echo "$name"
        done
    fi
    echo ""
    
    echo "successful and not accessible:"
    if [[ ${#INACCESSIBLE_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${INACCESSIBLE_CONTAINERS[@]}"; do
            IFS=':' read -r name id url last_step <<< "$item"
            echo "$name"
        done
    fi
    if [[ ${#NOT_TESTED_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${NOT_TESTED_CONTAINERS[@]}"; do
            IFS=':' read -r name id last_step <<< "$item"
            echo "$name"
        done
    fi
    echo ""
    
    echo "failed:"
    if [[ ${#FAILED_CONTAINERS[@]} -gt 0 ]]; then
        for item in "${FAILED_CONTAINERS[@]}"; do
            IFS=':' read -r name id last_step <<< "$item"
            echo "$name"
        done
    fi
    echo ""
    
    echo "skipped:"
    if [[ ${#SKIPPED_SCRIPTS[@]} -gt 0 ]]; then
        for item in "${SKIPPED_SCRIPTS[@]}"; do
            # Extract just the script name from "name (reason)"
            echo "$item" | cut -d' ' -f1
        done
    fi
} > "${OUTPUT_LOG}"

log_ok "Testing completed. Results saved to:"
log_info "  - Summary: ${SUMMARY_LOG}"
log_info "  - Full log: ${OUTPUT_LOG}"
log_info "  - Script logs: ${SCRIPT_LOG_DIR}/"

# Ask user if they want to destroy test containers
echo ""
read -p "Do you want to destroy all test containers? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Destroying test containers..."
    
    for item in "${ACCESSIBLE_CONTAINERS[@]}" "${INACCESSIBLE_CONTAINERS[@]}" "${NOT_TESTED_CONTAINERS[@]}" "${FAILED_CONTAINERS[@]}"; do
        IFS=':' read -r name id _ <<< "$item"
        if [[ -n "$id" ]] && pct status "$id" &>/dev/null; then
            log_info "Destroying container ${id} (${name})..."
            pct stop "$id" 2>/dev/null || true
            sleep 2
            pct destroy "$id" 2>/dev/null || true
        fi
    done
    
    log_ok "All test containers destroyed"
else
    log_info "Test containers left running for manual inspection"
fi

log_ok "Automation complete!"
