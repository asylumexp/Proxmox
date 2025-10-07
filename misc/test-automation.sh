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

# Function to monitor log file for output timeout (5 minutes of no output)
monitor_output_timeout() {
    local log_file="$1"
    local script_name="$2"
    local timeout_file="/tmp/timeout_monitor_${script_name}_$$.txt"
    local timeout_seconds=300  # 5 minutes
    
    # Background process to monitor log file modification time
    (
        local last_size=0
        local no_change_count=0
        
        while [ -f "$timeout_file" ]; do
            if [ -f "$log_file" ]; then
                local current_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
                
                if [ "$current_size" -eq "$last_size" ]; then
                    # No change in file size
                    no_change_count=$((no_change_count + 1))
                    
                    # Check if we've exceeded the timeout
                    if [ $no_change_count -ge $timeout_seconds ]; then
                        echo "TIMEOUT_EXCEEDED" > "${timeout_file}.exceeded"
                        # Kill the parent bash process (the test script)
                        local parent_pid=$(cat "${timeout_file}.pid" 2>/dev/null || echo "")
                        if [ -n "$parent_pid" ]; then
                            kill -TERM "$parent_pid" 2>/dev/null || true
                        fi
                        break
                    fi
                else
                    # File size changed, reset counter
                    last_size=$current_size
                    no_change_count=0
                fi
            fi
            sleep 1
        done
    ) &
    
    echo "$!" > "$timeout_file"
}

# Function to stop timeout monitor
stop_timeout_monitor() {
    local script_name="$1"
    local timeout_file="/tmp/timeout_monitor_${script_name}_$$.txt"
    
    if [ -f "$timeout_file" ]; then
        local pid=$(cat "$timeout_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$timeout_file" "${timeout_file}.pid" "${timeout_file}.exceeded"
    fi
}

# Function to check if timeout was exceeded
check_timeout_exceeded() {
    local script_name="$1"
    local timeout_file="/tmp/timeout_monitor_${script_name}_$$.txt"
    
    if [ -f "${timeout_file}.exceeded" ]; then
        return 0  # Timeout exceeded
    else
        return 1  # No timeout
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
    
    log_info "==================== Testing: ${script_name} ===================="
    
    # Skip alpine scripts
    if [[ "$script_name" =~ alpine ]]; then
        log_warn "Skipping alpine script: ${script_name}"
        SKIPPED_SCRIPTS+=("${script_name} (alpine - skipped)")
        return
    fi
    
    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_warn "Script not found: ${script_path}"
        SKIPPED_SCRIPTS+=("${script_name} (not found)")
        return
    fi
    
    # Get next available container ID
    local next_id=$(pvesh get /cluster/nextid)
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
    
    # Start monitoring current step
    monitor_current_step "${script_log}" "${script_name}"
    
    # Start timeout monitoring (5 minutes of no output)
    monitor_output_timeout "${script_log}" "${script_name}"
    
    # Run the script in background so we can monitor it
    bash "${TEMP_SCRIPT}" > "${script_log}" 2>&1 &
    local script_pid=$!
    
    # Store PID for timeout monitor
    echo "$script_pid" > "/tmp/timeout_monitor_${script_name}_$$.txt.pid"
    
    # Wait for the script to complete
    wait $script_pid
    local exit_code=$?
    
    # Stop monitors
    stop_monitor "${script_name}"
    stop_timeout_monitor "${script_name}"
    
    # Check if timeout was exceeded
    if check_timeout_exceeded "${script_name}"; then
        log_error "Script ${script_name} timed out (no output for 5 minutes)"
        FAILED_CONTAINERS+=("${script_name}:${next_id}:TIMEOUT - No output for 5 minutes")
        rm -f "$TEMP_SCRIPT"
        cleanup_container "${next_id}"
    elif [ $exit_code -eq 0 ]; then
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
                ACCESSIBLE_CONTAINERS+=("${script_name}:${next_id}:${http_url}:${last_step}")
            else
                log_error "HTTP endpoint is not accessible: ${http_url}"
                INACCESSIBLE_CONTAINERS+=("${script_name}:${next_id}:${http_url}:${last_step}")
            fi
        else
            log_warn "No HTTP endpoint found in output"
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
        
        FAILED_CONTAINERS+=("${script_name}:${next_id}:${last_step}")
        rm -f "$TEMP_SCRIPT"
        
        # Try to cleanup failed container
        cleanup_container "${next_id}"
    fi
    
    # Cleanup wrapper if it exists
    rm -f "${wrapper_script}"
    
    log_info "==================== Finished: ${script_name} ====================\n"
}

# Main testing loop
log_info "Starting automated container testing..."
log_info "Log directory: ${LOG_DIR}"
log_info ""

# Limit to 10 scripts per session (excluding skipped scripts)
TESTED_COUNT=0
MAX_SCRIPTS=10

while IFS= read -r script; do
    # Check if we've reached the limit
    if [[ $TESTED_COUNT -ge $MAX_SCRIPTS ]]; then
        log_warn "Reached maximum of ${MAX_SCRIPTS} tested scripts for this session"
        log_info "Remaining scripts will be skipped"
        break
    fi
    
    # Test the script
    test_script "$script"
    
    # Increment counter only if script was actually tested (not skipped)
    # We check if the script was added to SKIPPED_SCRIPTS array
    local was_skipped=false
    for skipped in "${SKIPPED_SCRIPTS[@]}"; do
        if [[ "$skipped" =~ ^"$script" ]]; then
            was_skipped=true
            break
        fi
    done
    
    if [[ "$was_skipped" == false ]]; then
        TESTED_COUNT=$((TESTED_COUNT + 1))
        log_info "Progress: ${TESTED_COUNT}/${MAX_SCRIPTS} scripts tested"
    fi
    
    # Small delay between tests
    sleep 5
done <<< "$TEST_SCRIPTS"

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

# Auto-delete successful and HTTP accessible containers
log_info "Auto-deleting successful and HTTP accessible containers..."
if [[ ${#ACCESSIBLE_CONTAINERS[@]} -gt 0 ]]; then
    for item in "${ACCESSIBLE_CONTAINERS[@]}"; do
        IFS=':' read -r name id url _ <<< "$item"
        if [[ -n "$id" ]] && pct status "$id" &>/dev/null; then
            log_info "Destroying container ${id} (${name}) - successful and HTTP accessible"
            pct stop "$id" 2>/dev/null || true
            sleep 2
            pct destroy "$id" 2>/dev/null || true
        fi
    done
    log_ok "Auto-deleted ${#ACCESSIBLE_CONTAINERS[@]} successful and HTTP accessible container(s)"
else
    log_info "No successful and HTTP accessible containers to delete"
fi

# Ask user if they want to destroy remaining test containers
if [[ ${#INACCESSIBLE_CONTAINERS[@]} -gt 0 ]] || [[ ${#NOT_TESTED_CONTAINERS[@]} -gt 0 ]] || [[ ${#FAILED_CONTAINERS[@]} -gt 0 ]]; then
    echo ""
    read -p "Do you want to destroy remaining test containers (inaccessible/failed/not-tested)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Destroying remaining test containers..."
        
        for item in "${INACCESSIBLE_CONTAINERS[@]}" "${NOT_TESTED_CONTAINERS[@]}" "${FAILED_CONTAINERS[@]}"; do
            IFS=':' read -r name id _ <<< "$item"
            if [[ -n "$id" ]] && pct status "$id" &>/dev/null; then
                log_info "Destroying container ${id} (${name})..."
                pct stop "$id" 2>/dev/null || true
                sleep 2
                pct destroy "$id" 2>/dev/null || true
            fi
        done
        
        log_ok "Remaining test containers destroyed"
    else
        log_info "Remaining test containers left running for manual inspection"
    fi
else
    log_info "No remaining containers to prompt for deletion"
fi

log_ok "Automation complete!"

