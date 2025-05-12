#!/bin/bash

declare -A container_table

# Initialize the table keys to prevent potential errors if a schedule has no containers
schedules=(quarterhourly hourly daily weekly monthly)
for schedule in "${schedules[@]}"; do
    container_table[$schedule]=""
done

# Renamed function to better reflect its action
start_or_restart_containers() {
    local schedule=$1

    # Use printf for output
    printf "Starting/Restarting %s containers:\n" "$schedule"
    # Check if the entry for the schedule is empty or just whitespace
    if [[ -z "${container_table[$schedule]// }" ]]; then
        printf " - none registered for this schedule\n"
        return
    fi
    # Use word splitting intentionally here by not quoting the variable
    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        # Use printf for output
        printf " - Triggering %s (%s)\n" "$container_name" "$container_id"
        # Use docker restart instead of docker start
        docker restart "$container_id" > /dev/null || printf "   - Failed to restart %s (%s)\n" "$container_name" "$container_id"
    done
}

list_containers() {
    local schedule="$1"

    # Use printf for output
    printf "  Registered %s containers:\n" "$schedule"
    # Check if the entry for the schedule is empty or just whitespace
    if [[ -z "${container_table[$schedule]// }" ]]; then
        printf "   - none\n"
        return
    fi

    # Use word splitting intentionally here by not quoting the variable
    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        # Use printf for output
        printf "   - %s (%s)\n" "$container_name" "$container_id"
    done
}

# --- Main Script Logic ---

# Fetch ALL container IDs (running, stopped, etc.)
# Using docker ps -a to ensure we find containers regardless of state
all_containers=$(docker ps -a -q)

# Iterate through all containers found
for container_id in $all_containers; do
    # Get the value of the label de.g3gg0.cron
    # Add error handling in case inspect fails (e.g., container removed during script run)
    cron_label=$(docker inspect -f '{{ index .Config.Labels "de.g3gg0.cron" }}' "$container_id" 2>/dev/null)

    # Proceed only if inspect was successful and label exists
    if [[ $? -eq 0 && -n "$cron_label" ]]; then
        # Check if the label value is one of the valid schedules
        is_valid_schedule=false
        for valid_schedule in "${schedules[@]}"; do
            if [[ "$cron_label" == "$valid_schedule" ]]; then
                is_valid_schedule=true
                break
            fi
        done

        if $is_valid_schedule; then
            container_name=$(docker inspect -f '{{ .Name }}' "$container_id" | sed 's|/||')
            # Append container ID and name to the appropriate schedule list in the table
            # Add a space separator if the list is not empty
            [[ -n "${container_table[$cron_label]}" ]] && container_table[$cron_label]+=" "
            container_table[$cron_label]+="$container_id:$container_name"
        else
             # Use printf for error output
             printf "Warning: Container %s has invalid cron label '%s'. Ignoring.\n" "$container_id" "$cron_label" >&2
        fi
    elif [[ $? -ne 0 ]]; then
        # Use printf for error output
        printf "Warning: Failed to inspect container %s. It might have been removed.\n" "$container_id" >&2
    fi
done


# Handle parameters
case "$1" in
    install)
        # Use printf for output
        printf "Creating bash scripts for cron jobs...\n"
        # Make sure the script path is absolute
        if [[ "$0" = /* ]]; then
             script_path="$0"
        else
             # Use printf for command substitution - slightly more robust
             script_path="$(printf "%s/%s" "$(pwd)" "$0")"
        fi
        # Ensure the script exists and is executable before installing
        if [ ! -f "$script_path" ]; then
            # Use printf for error output
            printf "Error: Script '%s' not found.\n" "$script_path" >&2
            exit 1
        fi

        install_dir=""
        if [ -d /etc/periodic/15min ]; then
             # Use printf for output
             printf "    Installing into /etc/periodic\n"
             install_dir="/etc/periodic"
             # Use printf to create the files - handles special chars slightly better
             printf "#!/bin/bash\nexec %s quarterhourly\n" "$script_path" > "$install_dir/15min/docker-cron"
             printf "#!/bin/bash\nexec %s hourly\n" "$script_path" > "$install_dir/hourly/docker-cron"
             printf "#!/bin/bash\nexec %s daily\n" "$script_path" > "$install_dir/daily/docker-cron"
             printf "#!/bin/bash\nexec %s weekly\n" "$script_path" > "$install_dir/weekly/docker-cron"
             printf "#!/bin/bash\nexec %s monthly\n" "$script_path" > "$install_dir/monthly/docker-cron"
             chmod +x "$install_dir/15min/docker-cron" \
                      "$install_dir/hourly/docker-cron" \
                      "$install_dir/daily/docker-cron" \
                      "$install_dir/weekly/docker-cron" \
                      "$install_dir/monthly/docker-cron"
        elif [ -d /etc/cron.hourly ]; then
             # Use printf for output
             printf "    Installing into /etc/cron.*\n"
             install_dir="/etc"
             # Use printf for warning output
             printf "Warning: quarterhourly schedule not supported with /etc/cron.* structure.\n" >&2
             printf "#!/bin/bash\nexec %s hourly\n" "$script_path" > "$install_dir/cron.hourly/docker-cron"
             printf "#!/bin/bash\nexec %s daily\n" "$script_path" > "$install_dir/cron.daily/docker-cron"
             printf "#!/bin/bash\nexec %s weekly\n" "$script_path" > "$install_dir/cron.weekly/docker-cron"
             printf "#!/bin/bash\nexec %s monthly\n" "$script_path" > "$install_dir/cron.monthly/docker-cron"
             chmod +x "$install_dir/cron.hourly/docker-cron" \
                      "$install_dir/cron.daily/docker-cron" \
                      "$install_dir/cron.weekly/docker-cron" \
                      "$install_dir/cron.monthly/docker-cron"
        else
            # Use printf for error output
            printf "Error: Failed to install. No compatible cron directory structure found (/etc/periodic/* or /etc/cron.*).\n" >&2
            exit 1
        fi

        # Use printf for output
        printf "Bash scripts created/updated in %s. Exiting.\n" "$install_dir"
        exit 0
        ;;

    list)
        # Use printf for output
        printf "Containers with cron schedules:\n"
        # Iterate through the defined schedules to maintain order
        for schedule in "${schedules[@]}"; do
             list_containers "$schedule"
        done
        exit 0
        ;;

    quarterhourly|hourly|daily|weekly|monthly)
        # Call the renamed function
        start_or_restart_containers "$1"
        ;;

    *)
        # Use printf for error output (Usage message)
        printf "Usage: %s {install|list|quarterhourly|hourly|daily|weekly|monthly}\n" "$0" >&2
        exit 1 # Use non-zero exit code for errors/unknown parameters
        ;;
esac

exit 0
