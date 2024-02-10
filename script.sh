# Changes: Fixed repetition of notification for same change

#!/bin/bash

# Directory to monitor
monitor_dir="$HOME/abc"
# Base file to store initial hashes
base_file="$HOME/Folder/base_hashes.txt"
# Log file to store file change events
log_file="$HOME/Folder/file_change_logs.txt"
# Temporary file to store already alerted files
alerted_file="$HOME/Folder/alerted_files.txt"

# Function to generate and save file hashes and inodes to the base file
generate_base_hashes() {
    echo "Base file not found in $monitor_dir. Creating base file..."
    for file_path in "$monitor_dir"/*; do
        if [[ -f "$file_path" ]]; then
            # Calculate hash and inode for current file
            hash=$(sha256sum "$file_path" | awk '{print $1}')
            inode=$(stat -c '%i' "$file_path")
            echo "$hash $inode $file_path" >> "$base_file"
        fi
    done
}

# Function to log file change events
log_file_changes() {
    local event="$1"
    local file_path="$2"
    local timestamp=$(date)
    echo "$event: $file_path ($timestamp)" >> "$log_file"
}

# Function to check if the base file exists
check_base_file() {
    if [[ ! -f "$base_file" ]]; then
        echo "Base file not found in $base_file. Generating base file..."
        generate_base_hashes
    fi
}

# Function to initialize the alerted file
initialize_alerted_file() {
    touch "$alerted_file"
}

# Function to check if a file has already triggered an alert
is_already_alerted() {
    local file_path="$1"
    grep -qF "$file_path" "$alerted_file"
}

# Function to mark a file as already alerted
mark_as_alerted() {
    local file_path="$1"
    echo "$file_path" >> "$alerted_file"
}

# Function to check for file changes
check_file_changes() {
    local has_changes=false
    local new_files_found=false
    
    # Check if the base file exists
    check_base_file
    
    # Check if the alerted file exists
    if [[ ! -f "$alerted_file" ]]; then
        initialize_alerted_file
    fi
    
    # Iterate over files in monitor_dir
    for file_path in "$monitor_dir"/*; do
        local file_name=$(basename "$file_path")
        local hash
        local inode
        
        # Calculate hash and inode for current file
        hash=$(sha256sum "$file_path" | awk '{print $1}')
        inode=$(stat -c '%i' "$file_path")
        
        # Check if file exists in base file
        if grep -qF "$file_name" "$base_file"; then
            # Check if hash and inode matches
            local existing_entry=$(grep "$file_name" "$base_file")
            local existing_hash=$(echo "$existing_entry" | awk '{print $1}')
            local existing_inode=$(echo "$existing_entry" | awk '{print $2}')
            if [[ "$existing_hash" != "$hash" || "$existing_inode" != "$inode" ]]; then
                if ! is_already_alerted "$file_path"; then
                    notify-send "Modification Detected" "Modifications in file $file_name found. $(date)"
                    log_file_changes "Modification" "$file_path"
                    mark_as_alerted "$file_path"
                fi
                has_changes=true
            fi
        else
            # New file found
            if ! is_already_alerted "$file_path"; then
                notify-send "New File Detected" "New file $file_name found in $monitor_dir. $(date)"
                log_file_changes "New File" "$file_path"
                mark_as_alerted "$file_path"
            fi
            new_files_found=true
            has_changes=true
        fi
    done
    
    # Check for deleted files
    while IFS=' ' read -r existing_hash existing_inode existing_path; do
        if ! [[ -f "$existing_path" ]]; then
            # File deleted
            if ! is_already_alerted "$existing_path"; then
                file_name=$(basename "$existing_path")
                notify-send "File Deleted" "File $file_name has been deleted from $monitor_dir. $(date)"
                log_file_changes "File Deleted" "$existing_path"
                mark_as_alerted "$existing_path"
            fi
            has_changes=true
        fi
    done < "$base_file"
    
    # No changes detected
    #if [[ "$has_changes" == false && "$new_files_found" == false ]]; then
    #   echo "No changes detected."
    #fi
}

# Main loop to monitor the directory
while true; do
    check_file_changes
    sleep 5  
done
