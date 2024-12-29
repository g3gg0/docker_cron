#!/bin/bash

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

    # Populate lists based on the label
    case "$cron_label" in
        quarterhourly)
            quarterhourly+=("$container ($container_name)")
            ;;
        hourly)
            hourly+=("$container ($container_name)")
            ;;
        daily)
            daily+=("$container ($container_name)")
            ;;
        weekly)
            weekly+=("$container ($container_name)")
            ;;
        monthly)
            monthly+=("$container ($container_name)")
            ;;
        *)
            ;;
    esac
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
        if [ ${#quarterhourly[@]} -gt 0 ]; then
            echo -e "\n15min:"
            printf "  %s\n" "${quarterhourly[@]}"
        fi
        if [ ${#hourly[@]} -gt 0 ]; then
            echo -e "\nHourly:"
            printf "  %s\n" "${hourly[@]}"
        fi
        if [ ${#daily[@]} -gt 0 ]; then
            echo -e "\nDaily:"
            printf "  %s\n" "${daily[@]}"
        fi
        if [ ${#weekly[@]} -gt 0 ]; then
            echo -e "\nWeekly:"
            printf "  %s\n" "${weekly[@]}"
        fi
        if [ ${#monthly[@]} -gt 0 ]; then
            echo -e "\nMonthly:"
            printf "  %s\n" "${monthly[@]}"
        fi
        exit 0
        ;;

    quarterhourly)
        echo -e "Starting 15min containers:"
        for container_entry in "${quarterhourly[@]}"; do
            echo " - $container_entry"
            container_id=$(echo "$container_entry" | awk '{print $1}')
            docker start "$container_id"
        done
        ;;

    hourly)
        echo -e "Starting hourly containers:"
        for container_entry in "${hourly[@]}"; do
            echo " - $container_entry"
            container_id=$(echo "$container_entry" | awk '{print $1}')
            docker start "$container_id"
        done
        ;;

    daily)
        echo -e "Starting daily containers:"
        for container_entry in "${daily[@]}"; do
            echo " - $container_entry"
            container_id=$(echo "$container_entry" | awk '{print $1}')
            docker start "$container_id"
        done
        ;;

    weekly)
        echo -e "Starting weekly containers:"
        for container_entry in "${weekly[@]}"; do
            echo " - $container_entry"
            container_id=$(echo "$container_entry" | awk '{print $1}')
            docker start "$container_id"
        done
        ;;

    monthly)
        echo -e "Starting monthly containers:}"
        for container_entry in "${monthly[@]}"; do
            echo " - $container_entry"
            container_id=$(echo "$container_entry" | awk '{print $1}')
            docker start "$container_id"
        done
        ;;

    *)
        echo -e "Unknown parameter. Please use install, list, hourly, daily, weekly, or monthly."
        ;;
esac

