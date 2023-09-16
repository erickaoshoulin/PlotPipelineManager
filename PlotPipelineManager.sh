#!/bin/bash

# Check if at least one argument is provided (num_plots)
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <num_plots> <ssd_path1> <ssd_path2> ... -- <hdd_path1> <hdd_path2> ..."
    exit 1
fi

# Number of plots
num_plots_target=$1
shift # Shift arguments to remove num_plots

# Split SSD and HDD paths
ssds=() # Array for SSD paths
hdds=() # Array for HDD paths
separator_found=0

for arg in "$@"; do
    if [[ $arg == "--" ]]; then
        separator_found=1
        continue
    fi
    if [[ $separator_found -eq 0 ]]; then
        ssds+=("$arg")
    else
        hdds+=("$arg")
    fi
done

# Check if we have at least one SSD and HDD path
if [[ ${#ssds[@]} -eq 0 || ${#hdds[@]} -eq 0 ]]; then
    echo "You must provide at least one SSD path and one HDD path."
    exit 1
fi

ssd_is_free() {
    local ssd_path=$1
    # Check for existence of any matching file
    if [[ -z $(find "$ssd_path" -maxdepth 1 -name "*.plot" -print -quit) ]] &&
       [[ -z $(find "$ssd_path" -maxdepth 1 -name "*.plot.tmp" -print -quit) ]] &&
       [[ ! -f "$ssd_path/.copying" ]]; then
        return 0
    else
        return 1
    fi
}

ssd_has_completed_file() {
    local ssd_path=$1

    # Check if there's a .plot file and it's not currently being copied
    if [[ $(find "$ssd_path" -maxdepth 1 -name "*.plot" | wc -l) -gt 0 ]] && [[ ! -f "$ssd_path/.copying" ]]; then
        echo "$ssd_path has completed plot..."
        return 0  # True - there's a completed plot
    else
        echo "$ssd_path has no completed plot..."
        return 1  # False - no completed plot
    fi
}

# Function to find the least active HDD using a simple round-robin approach

find_least_active_hdd() {
    local selected_hdd="${hdds[$current_hdd]}"

    # Debug: Print the current state of all HDDs
    echo "All HDDs: ${hdds[@]}"
    echo "Current HDD Index Before Selection: $current_hdd"

    echo "Selecting HDD: $selected_hdd (Index: $current_hdd)"

    # Explicitly declare it as a global variable and increment.
    declare -g current_hdd
    current_hdd=$(( (current_hdd + 1) % ${#hdds[@]} ))

    # Debug: Print the updated index
    echo "Current HDD Index After Selection: $current_hdd"

    echo "${selected_hdd}"
}

# Define the function
copy_plot_to_hdd() {
    local plot=$1
    local destination=$2
    local ssd_path=$(dirname "$plot")

    rsync --progress --remove-source-files "$plot" "$destination"
    rm "$ssd_path/.copying"
    echo "Remove $ssd_path/.copying!!!"
}

current_hdd=0
while [ "$num_plots" -lt "$num_plots_target" ]; do
    for ssd in "${ssds[@]}"; do

     # If .copying exists, just print a message and skip to the next iteration
        if [[ -f "$ssd/.copying" ]]; then
            echo "$ssd is already being copied to a HDD."
            continue
        fi
        # If SSD is free and no bladebit is running
        if ssd_is_free "$ssd" && ! pgrep -x "bladebit_cuda" > /dev/null; then
            # Start the plotting process with your specific parameters
            chia plotters bladebit cudaplot -f b599eb9713c031319f1e92041bc9f161363ced3bdcb780d9b5b0018bf308d72732b6bb0a76d42e77c6f836cd0895329b -c xch1tw4wum6ykpszhfd40ud6r4j8uxwdck2chuj6x3whurxlurdpls4q3gcvg7 --compress 7 -n 1 -d "$ssd" &
            sleep 10s
            echo "bladebit running on $ssd ..."
            num_plots=$((num_plots + 1))
        elif ssd_has_completed_file "$ssd"; then
            if [[ ! -f "$ssd/.copying" ]]; then  # Check if .copying doesn't exist
                #hdd=$(find_least_active_hdd)
                hdd="${hdds[$current_hdd]}"
                current_hdd=$(( (current_hdd + 1) % ${#hdds[@]} ))


                plot_file=$(find "$ssd" -maxdepth 1 -name "*.plot" -print -quit)
                if [[ -n "$plot_file" ]]; then
	            echo "Touching: $ssd/.copying"
                    if [[ -f "$ssd/.copying" ]]; then
                        echo "Error: .copying file already exists on $ssd"
                    else
                        echo "Creating .copying file on $ssd"
                        touch "$ssd/.copying"
                    fi
                    
                    if [[ ! -f "$ssd/.copying" ]]; then
                        echo "Error: Failed to create .copying file on $ssd"
                    fi

                    touch "$ssd/.copying"  # Flag that we're copying
                    # Use the function and run it in the background
                    copy_plot_to_hdd "$plot_file" "$hdd" &

                    echo "$ssd has completed plot. Started copying to $hdd ..."
                fi
            else
                echo "$ssd is already being copied to a HDD."
            fi
        fi
    done
    sleep 10s
done
