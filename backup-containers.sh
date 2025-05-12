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

    echo -e "Starting/Restarting $schedule containers:"
    # Check if the entry for the schedule is empty or just whitespace
    if [[ -z "${container_table[$schedule]// }" ]]; then
        echo " - none registered for this schedule"
        return
    fi
    # Use word splitting intentionally here by not quoting the variable
    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        echo " - Triggering $container_name ($container_id)"
        # Use docker restart instead of docker start
        docker restart "$container_id" > /dev/null || echo "   - Failed to restart $container_name ($container_id)"
    done
}

list_containers() {
    local schedule="$1"

    echo -e "  Registered $schedule containers:"
    # Check if the entry for the schedule is empty or just whitespace
    if [[ -z "${container_table[$schedule]// }" ]]; then
        echo "   - none"
        return
    fi

    # Use word splitting intentionally here by not quoting the variable
    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        echo "   - $container_name ($container_id)"
    done
}

# --- Main Script Logic ---

# Fetch ALL container IDs (running, stopped, etc.)
# Using docker ps -a to ensure we find containers regardless of state
all_containers=$(docker ps -a -q)

# Iterate through all containers found
for container_id in $all_containers; do
    # Get the value of the label de.g3gg0.cron
    # Use --no-trunc with inspect for potentially long labels if needed, though unlikely here.
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
             echo "Warning: Container $container_id has invalid cron label '$cron_label'. Ignoring." >&2
        fi
    elif [[ $? -ne 0 ]]; then
        echo "Warning: Failed to inspect container $container_id. It might have been removed." >&2
    fi
done


# Handle parameters
case "$1" in
    install)
        echo -e "Creating bash scripts for cron jobs..."
        # Make sure the script path is absolute
        if [[ "$0" = /* ]]; then
             script_path="$0"
        else
             script_path="$(pwd)/$0"
        fi
        # Ensure the script exists and is executable before installing
        if [ ! -f "$script_path" ]; then
            echo "Error: Script '$script_path' not found." >&2
            exit 1
        fi
        # No need to chmod +x the script itself here, but the cron wrappers need it.

        install_dir=""
        if [ -d /etc/periodic/15min ]; then
             echo -e "    Installing into /etc/periodic"
             install_dir="/etc/periodic"
             echo -e "#!/bin/bash\nexec $script_path quarterhourly" > "$install_dir/15min/docker-cron" # Use a consistent name
             echo -e "#!/bin/bash\nexec $script_path hourly" > "$install_dir/hourly/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path daily" > "$install_dir/daily/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path weekly" > "$install_dir/weekly/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path monthly" > "$install_dir/monthly/docker-cron"
             chmod +x "$install_dir/15min/docker-cron" \
                      "$install_dir/hourly/docker-cron" \
                      "$install_dir/daily/docker-cron" \
                      "$install_dir/weekly/docker-cron" \
                      "$install_dir/monthly/docker-cron"
        elif [ -d /etc/cron.hourly ]; then
             echo -e "    Installing into /etc/cron.*"
             install_dir="/etc"
             echo "Warning: quarterhourly schedule not supported with /etc/cron.* structure." >&2
             echo -e "#!/bin/bash\nexec $script_path hourly" > "$install_dir/cron.hourly/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path daily" > "$install_dir/cron.daily/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path weekly" > "$install_dir/cron.weekly/docker-cron"
             echo -e "#!/bin/bash\nexec $script_path monthly" > "$install_dir/cron.monthly/docker-cron"
             chmod +x "$install_dir/cron.hourly/docker-cron" \
                      "$install_dir/cron.daily/docker-cron" \
                      "$install_dir/cron.weekly/docker-cron" \
                      "$install_dir/cron.monthly/docker-cron"
        else
            echo -e "Error: Failed to install. No compatible cron directory structure found (/etc/periodic/* or /etc/cron.*)." >&2
            exit 1
        fi

        echo -e "Bash scripts created/updated in $install_dir. Exiting."
        exit 0
        ;;

    list)
        echo -e "Containers with cron schedules:"
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
        echo -e "Usage: $0 {install|list|quarterhourly|hourly|daily|weekly|monthly}" >&2
        exit 1 # Use non-zero exit code for errors/unknown parameters
        ;;
esac

exit 0
