#!/bin/bash


#########################################################################
# Global
#########################################################################

# Colors scheme for text formatting
# Colors for text formatting
RED=$(tput bold setaf 9)
GREEN=$(tput bold setaf 10)
YELLOW=$(tput bold setaf 11)
BLUE=$(tput bold setaf 12)
PURPLE=$(tput bold setaf 13)
CYAN=$(tput bold setaf 14)
NC=$(tput bold sgr0)


#RED=$(tput setaf 1)
#GREEN=$(tput setaf 2)
#YELLOW=$(tput setaf 3)
#BLUE=$(tput setaf 4)
#PURPLE=$(tput setaf 5)
#CYAN=$(tput setaf 6)
#NC=$(tput sgr0)

# Author
Author=" Ahmad Rasheed"
# Script Name
Name="VISION-X Intrusion Detection System"
# Script Version
Version=" 0.0.1 (beta)"
# Script Description
Description="Monitor & Alert on Suspicious Activities"
# Script URL
URL="https://github.com/Ahmad-Rasheed-01/IDS.git"




# SETTING-UP DIRECTORIES

# Directory to monitor
monitor_dir="$HOME/abc"
# Base file to store initial hashes
base_file="$HOME/Folder/base_hashes.txt"
# Log file to store file change events
log_file="$HOME/Folder/file_change_logs.txt"
# Temporary file to store already alerted files
alerted_file="$HOME/Folder/alerted_files.txt"

#########################################################################
# Functions
#########################################################################

# Function to print the contents of an ASCII banner from a file
print_banner() {
    # Specify the path to the ASCII banner file
    banner="banner.txt"

    # Check if the banner file exists
    if [ -f "$banner" ]; then
        # Print the contents of the ASCII banner file
        cat "$banner"
    else
        # Print an error message if the banner file is not found
        echo "Banner file not found: $banner"
    fi
}

# Function to print the Linux-Util banner
print_linux_util_banner() {
    echo -e "${RED}"
    clear
    print_banner
    echo
    print_message "${NC}-----------------------------------------------------------------------------------------${NC}"
    print_message "${CYAN}Welcome to ${YELLOW}$Name${NC}${CYAN} - ${YELLOW}$Description${NC}"
    print_message "${CYAN}Author:${NC}${YELLOW}$Author${NC}"
    print_message "${CYAN}Version:${NC}${YELLOW}$Version${NC}"
    print_message "${NC}-----------------------------------------------------------------------------------------${NC}"
    echo
}

# Function to wait for Enter key press to continue
press_enter() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
    clear
}

# Function to wait for Enter key press to go back to main menu
press_enter_back() {
	echo
	echo -e "${YELLOW}Press Enter key to go-back...${NC}"
	# main_menu
	read -r
	# clear
}


# Trap Ctrl+C to display exit message
trap exit_message INT

# Function to display exit message
exit_message() {
    print_linux_util_banner
    print_message "${BLUE}" "Thanks for using $Name written by $Author."
    exit
}

# Function to display colored messages
print_message() {
    local COLOR=$1
    local MESSAGE=$2
    echo -e "${COLOR}${MESSAGE}${NC}"
}


# Function to generate and save file hashes and inodes to the base file
generate_base_hashes() {
    echo "Base file not found in $monitor_dir. Creating base file..."
    for file_path in "$monitor_dir"/*; do
        if [[ -f "$file_path" ]]; then
            # Calculate hash and inode for current file
	    hash=$(sha256sum "$file_path" 2>/dev/null | awk '{print $1}')  # find "$monitor_dir" -type f -exec sha256sum {} + | awk '{print $1, $2}' > "$base_file"            
            inode=$(stat -c '%i' "$file_path" 2>/dev/null )
            echo "$hash $inode $file_path" >> "$base_file" 
        fi
    done
}

# Function to log file change events
log_file_changes() {
    local event="$1"
    local file_path="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$event: $file_path $timestamp" >> "$log_file"
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
    if [[ -f "$alerted_file" ]]; then
        grep -qF "$file_path" "$alerted_file"
    else
        return 1
    fi
}

# Function to mark a file as already alerted
mark_as_alerted() {
    local file_path="$1"
    echo "$file_path" >> "$alerted_file"
}

check_active_conn_log() {
netstat -ntu
}

# Function to create/ update the base file
update_basefile() {
	
	if [[ -f "$base_file" ]]; then
		print_message "${YYELLOW} File already exists. Updating base file..."
        	generate_base_hashes
   	else
		print_message "${YELLOW} File not found. Creating the BaseFile..."
   		generate_base_hashes
        	if [[ -f "$base_file" ]]; then
        		sleep 2
        		print_message "${YELLOW} BaseFile create successfully."
        		press_enter_back
    		fi
	fi
}
# Function to delete the basefile
delete_basefile() {
    print_message "${RED} Warning! ${YELLOW}Press Y/y to continue" 
    read -r response
    if [[ "$response" == [Yy] ]]; then
        print_message "${YELLOW} Deleting the BaseFile. Please Wait..."
        rm -rf "$base_file"
        sleep 2
    else
	print_message "${YELLOW} Invalid Input. Going back to main menu..."
	sleep 1
	main_menu
	#print_message "${YELLOW} Wrong "
	fi
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
}

# Function to check file manipulation log file
check_file_log() {
	# cat "$HOME/Folder/file_change_logs.txt"
	cat "$log_file"
	# sleep 5
}

# Main loop to monitor the directory
#while true; do
  #  check_file_changes
 #   sleep 5  
#done




##########################################################################
# MAIN MENU
##########################################################################

# Print Banner


main_menu() {
    print_linux_util_banner

    print_message "${YELLOW}" "Select an option:"
    print_message "${GREEN} 1. ${PURPLE} Check File Manipulation Logs."
    print_message "${GREEN} 2. ${PURPLE} Check Active Network Connections."
    print_message "${GREEN} 3. ${PURPLE} Update BaseFile"
    print_message "${GREEN} 4. ${PURPLE} Delete BaseFile"
    print_message "${GREEN} 5. ${PURPLE} Exit"
    echo
    read -p "Enter your choice: " choice
    echo

    case $choice in 
        1) 
        check_file_log 
        # print_message "${RED}" "Press enter to back to main menu."
        press_enter_back
        main_menu
        ;;
        2) 
        check_active_conn_log 
        press_enter_back
        main_menu
        ;;
        3) update_basefile 
        ;;
        4) delete_basefile 
        ;;
	5) 
	print_message "${YELLOW}" "Exiting..."
	sleep 1
	exit_message   
        ;;
        *)
	print_message "${RED}" "Invalid option. Please try again."
        press_enter
        main_menu
        ;;
    esac
}

#########################################################################
# Main
#########################################################################

# Print the main menu
main_menu

# Main loop to monitor the directory
while true; do
    check_file_changes
    sleep 5  
done

