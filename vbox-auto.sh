#! /bin/bash

show_help(){
    cat << EOF 
    Usage: $0 
    -n <name>   : Name of the virtual machine
    -t <type>   : OS Type (Required by VirtualBox. If unsure, put Linux_64 or Other_64)
    -c <value>  : Amount of cpu cores to assign to the virtual machine
    -m <value>  : Amount of memory (In megabytes) to assign to the virtual machine
    -d <value>  : Disk size of the virtual machine
    -p <path>   : Path to save the virtual drive. Leave empty for default VirtualBox installation
    -s <name>   : Label for the SATA port
    -i <name>   : Label for the IDE port
    -h          : Show this message

    Example:
    $0 -n "LinuxMint" -t "Linux_64" -c 8 -m 8192 -d 51200 -s "Home Drive" -i "DVD drive" [-p "/path/to/your/drive/"]
EOF
}

if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

while getopts "n:t:c:m:d:s:i:hp:" flag; do
case $flag in
    n) VMNAME=${OPTARG};;
    t) OS_TYPE=${OPTARG};;
    c) 
        if (( ${OPTARG} <= 0 )); then
            echo "[Error]: CPU cores can't be lower or equal to 0"
            exit 1
        elif (( $(nproc --all) <= ${OPTARG} )); then
            echo "[Error]: Your CPU doesn't have enough cores to satisfy the requested amount."
            echo "[Note]: Your computer has $(nproc --all) cores."
            exit 1
        else
            CPU_CORES=${OPTARG}
    fi
    ;;
    m)
        total_mem=$(vmstat -s -S M | awk '/total memory/ {print $1}')
        if (( ${OPTARG} <= 4 )); then
            echo "[Error]: Memory can't be lower or equal to 4 MB"
            exit 1
        elif (( $total_mem <= ${OPTARG})); then
            echo "[Error]: Your computer doesn't have enough memory for the virtual machine to run."
            echo "[Note]: You have $total_mem megabytes of memory"
            exit 1
        else
            RAM_MB=${OPTARG}
        fi
    ;;
    d) DISK_SIZE=${OPTARG};;
    s) SATA_LABEL=${OPTARG};;
    i) IDE_LABEL=${OPTARG};;
    p) DISK_PATH=${OPTARG};;
    h)
        show_help
        exit 1
    ;;
    \?)
        echo "Invalid option -$OPTARG"
        exit 1
    ;;
    esac
done

if [ ! "$VMNAME" ]; then
    echo "Missing argument: -n"
    exit 1
fi

if [ ! "$OS_TYPE" ]; then
    echo "Missing argument: -t"
    exit 1
fi

if [ ! "$CPU_CORES" ]; then
    echo "Missing argument: -c"
    exit 1
fi

if [ ! "$RAM_MB" ]; then
    echo "Missing argument: -m"
    exit 1
fi

if [ ! "$DISK_SIZE" ]; then
    echo "Missing argument: -d"
    exit 1
fi

if [ ! "$SATA_LABEL" ]; then
    echo "Missing argument: -s"
    exit 1
fi

if [ ! "$IDE_LABEL" ]; then
    echo "Missing argument: -i"
    exit 1
fi

if [ ! "$DISK_PATH" ]; then
    VirtualBoxPath=~/VirtualBox\ VMs
    echo "[Info]: No path provided for virtual disk, assuming $VirtualBoxPath"
    DISK_PATH="$VirtualBoxPath/$VMNAME"
fi

# Show vm info before using vboxmanager
cat << EOF
    Virtual machine name: $VMNAME
    Total CPU core count: $CPU_CORES
    Total ram size      : $RAM_MB
    Virtual disk size   : $DISK_SIZE
    Virtual disk path   : $DISK_PATH
    SATA port label     : $SATA_LABEL
    IDE port label      : $IDE_LABEL
EOF

read -p "Is this information correct? (y/n): " opt

if [ "$opt" != "y" ] && [ "$opt" != "Y" ]; then
    echo "Exitting..."
    exit 1
else

    GREEN='\e[1;32m'
    BLUE='\e[1;34m'
    BLUE_BG='\e[1;44m'
    NC='\e[0m'
    echo -e "${GREEN}-------------------[[STARTING WORK]]--------------------${NC}"
    echo -e "${BLUE}Registering virtual machine $VMNAME under $OS_TYPE...${NC}"
    vboxmanage createvm --name "$VMNAME" --ostype "$OS_TYPE" --register
    echo -e "${BLUE}Assigning $CPU_CORES Cores and $RAM_MB MB of memory to $VMNAME...${NC}"
    vboxmanage modifyvm "$VMNAME" --memory "$RAM_MB" --cpus "$CPU_CORES"
    echo -e "${BLUE}Creating a Virtual disk with $DISK_SIZE megabytes of size...${NC}"
    vboxmanage createhd --filename "$DISK_PATH/$VMNAME.vdi" --size "$DISK_SIZE" --variant Standard
    echo -e "${BLUE}Creating SATA port with label $SATA_LABEL for $VMNAME...${NC}"
    vboxmanage storagectl "$VMNAME" --name "$SATA_LABEL" --add sata --bootable on
    echo -e "${BLUE}Attaching Virtual disk drive to SATA port $SATA_LABEL for $VMNAME...${NC}"
	vboxmanage storageattach "$VMNAME" --storagectl "$SATA_LABEL" --port 0 --device 0 --type hdd --medium "$DISK_PATH/$VMNAME.vdi"
    echo -e "${BLUE}Creating IDE port $IDE_LABEL for $VMNAME...${NC}"
	vboxmanage storagectl "$VMNAME" --name "$IDE_LABEL" --add ide
    echo -e "${GREEN}-----------------------[[FINISH]]-----------------------${NC}"
    echo -e "${BLUE_BG}VirtualBox $VMNAME information...${NC}"
    vboxmanage showvminfo "$VMNAME"

fi

echo "Goodbye."
