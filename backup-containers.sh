#!/bin/bash

declare -A container_table

schedules=(quarterhourly hourly daily weekly monthly)
for schedule in "${schedules[@]}"; do
    containers_by_schedule[$schedule]=""
done

start_containers() {
    local schedule=$1

    echo -e "Starting $schedule containers:"
    if [[ -z "${container_table[$schedule]}" ]]; then
        echo " - none"
        return
    fi
    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        echo " - $container_name ($container_id)"
        docker start "$container_id" > /dev/null || echo "Failed"
    done
}

list_containers() {
    local schedule="$1"

    echo -e "  Registered $schedule containers:"
    if [[ -z "${container_table[$schedule]}" ]]; then
        echo "   - none"
        return
    fi

    for container_entry in ${container_table[$schedule]}; do
        container_id=$(echo "$container_entry" | awk -F ':' '{print $1}')
        container_name=$(echo "$container_entry" | awk -F ':' '{print $2}')
        echo "   - $container_name ($container_id)"
    done
}


# Define lists
quarterhourly=()
hourly=()
daily=()
weekly=()
monthly=()

# Fetch all stopped container IDs
containers=$(docker ps -q -f status=exited)

# Iterate through containers
for container in $containers; do
    # Get the value of the label de.g3gg0.cron
    cron_label=$(docker inspect -f '{{ index .Config.Labels "de.g3gg0.cron" }}' "$container")
    container_name=$(docker inspect -f '{{ .Name }}' "$container" | sed 's|/||')
    
    if [[ -n "$cron_label" ]]; then
        container_table[$cron_label]+="$container:$container_name "
    fi
done

# Handle parameters
case "$1" in
    install)
        echo -e "Creating bash scripts for cron jobs..."
        script_path=$(realpath "$0")

        if [ -d /etc/periodic ]; then
            echo -e "    Installing into /etc/periodic"
            echo -e "#!/bin/bash\n$script_path quarterhourly" > /etc/periodic/15min/docker-backup
            echo -e "#!/bin/bash\n$script_path hourly" > /etc/periodic/hourly/docker-backup
            echo -e "#!/bin/bash\n$script_path daily" > /etc/periodic/daily/docker-backup
            echo -e "#!/bin/bash\n$script_path weekly" > /etc/periodic/weekly/docker-backup
            echo -e "#!/bin/bash\n$script_path monthly" > /etc/periodic/monthly/docker-backup
            chmod +x /etc/periodic/{15min,hourly,daily,weekly,monthly}/docker-backup
        elif [ -d /etc/cron.hourly ]; then
            echo -e "    Installing into /etc/cron.*"
            echo -e "#!/bin/bash\n$script_path hourly" > /etc/cron.hourly/docker-backup
            echo -e "#!/bin/bash\n$script_path daily" > /etc/cron.daily/docker-backup
            echo -e "#!/bin/bash\n$script_path weekly" > /etc/cron.weekly/docker-backup
            echo -e "#!/bin/bash\n$script_path monthly" > /etc/cron.monthly/docker-backup
            chmod +x /etc/cron.{hourly,daily,weekly,monthly}/docker-backup
        else
            echo -e "Failed to install. No cron installed."
            exit 1
        fi

        echo -e "Bash scripts created. Exiting."
        exit 0
        ;;

    list)
        echo -e "Containers with cron schedules:"

        list_containers quarterhourly
        list_containers hourly
        list_containers daily
        list_containers weekly
        list_containers monthly
        exit 0
        ;;

    quarterhourly|hourly|daily|weekly|monthly)
        start_containers "$1"
        ;;

    *)
        echo -e "Unknown parameter. Please use install, list, hourly, daily, weekly, or monthly."
        ;;
esac

exit 0
