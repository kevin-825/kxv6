#!/bin/bash
set -e

# --- Functions ---

# Print info with a consistent prefix
log_info() {
    echo "[ENTRYPOINT] $1"
}

# Handle any setup logic (e.g., fixing permissions)
setup_env() {
    log_info "Initializing environment..."
    
    # Example: If you need to ensure a specific directory is owned by the user
    # current_user=$(whoami)
    # log_info "Running as user: $current_user"
}

# --- Main Logic ---

main() {
    setup_env

    # If the user passed a command (like 'bash' or 'python app.py'), run it.
    # If no command was passed, default to a shell.
    if [ $# -gt 0 ]; then
        log_info "Executing command: $@"
        exec "$@"
    else
        log_info "No command provided, starting default shell..."
        exec /bin/bash
    fi
}

# Run the main function with all script arguments
main "$@"
