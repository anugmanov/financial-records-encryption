#!/bin/bash
#---------------
#Script for encrypting Buddi financial records and program entirely in 
#LUKS container using strongest encryption methods(symmetric).
#Needed:
#1.buddi.jar
#2.buddi starting shell script. Must be edited to use different home folder
#3.dm-crypt for LUKS
#--------------
#USAGE:
#-h Prins help mess
#-u <dir> Unmounts specified directory, closes LUKS, removes mapper and loop devices

CONTAINER_PATH=${HOME}"/Finances/buddi.fin"
LOOP_NAME=""
DEVMAPPER_NAME="Buddi_crypted"
MNT_PATH="/media/Buddi_crypted"

USERNAME=$(whoami)
GROUPNAME=$(id -g -n ${USERNAME})
LINE="------------------------------------"


unset HISTFILE

show_help(){
	echo "Some fucking help message goes here \
		see source, fucker. No cookies here. \
	"
}


parse_args(){
	if [ "$1" == "-u" ]; then
		unmount_everything ${2}
		exit 0
	fi
	if [ "$1" == "-h" ]; then
		show_help
		exit 0
	fi
	mount_container

}

create_container(){
	echo $LINE
	echo "Creating container in $CONTAINER_PATH"
	mkdir "${HOME}/Finances"
	read -p "Type size in megabytes" SIZE
	#Check if number
	regex="^-?[0-9]+([.][0-9]+)?$"
	if ! [[ $SIZE =~ $regex ]]; then
		echo "Not a number, try again, fucker"
		create_container
	fi
	dd if=/dev/urandom of=$CONTAINER_PATH bs=1M count=$SIZE
	if [ ! -f $CONTAINER_PATH ]; then
		echo "Shit happened"
		exit 1
	fi
	echo "Your password needed"
	LOOP_NAME=$(sudo losetup -f)
	sudo losetup ${LOOP_NAME} $CONTAINER_PATH
	sudo cryptsetup -v --key-size 512 --hash sha512 --iter-time 5000 --use-urandom --verify-passphrase luksFormat ${LOOP_NAME}
	echo $LINE
	echo "Now open container"
	sudo cryptsetup luksOpen ${LOOP_NAME} ${DEVMAPPER_NAME}
	echo "Making ext4 FS in there"
	echo
	sudo mkfs.ext4 /dev/mapper/${DEVMAPPER_NAME}
	echo $LINE
	if [ ! -f $MNT_PATH ];then
		sudo mkdir $MNT_PATH
	fi
	sudo mount -t ext4 /dev/mapper/${DEVMAPPER_NAME} ${MNT_PATH}
	echo "OK. Move buddi files there (${MNT_PATH}), modify buddi bash script, unmount fukken everything"
	sudo mkdir ${MNT_PATH}/.buddi
	exit 0
}

mount_container(){
	echo $LINE
	echo "Mounting container $CONTAINER_PATH"

	echo "Your password needed to proceed (sudo command)"
	LOOP_NAME=$(sudo losetup -f)
	sudo losetup ${LOOP_NAME} $CONTAINER_PATH
	echo "Container password"
	sudo cryptsetup luksOpen ${LOOP_NAME} ${DEVMAPPER_NAME}

	if [ ! -f $MNT_PATH ]; then
		sudo mkdir $MNT_PATH
	fi
	
	echo "Mounting..."
	sudo mount  -t ext4 /dev/mapper/${DEVMAPPER_NAME} $MNT_PATH
	if [ $? -ne 0 ]; then
		if [ $? -e 32 ]; then
		       echo "Not ext4 type. Edit this script"
		       exit 1
	        fi
 		echo "Shit happened"
		exit 1
	fi

	sudo chown -R ${USERNAME}:${GROUPNAME} ${MNT_PATH}
	sudo chmod -R 755 $MNT_PATH
	cd $MNT_PATH
	./buddi
	exit 0
}

unmount_everything(){
	echo "Password needed (sudo command)"
	sudo umount $MNT_PATH
	if [ $? -ne 0 ]; then
		echo "Shit happened"
	fi
	LOOP_NAME="/dev/"$(lsblk -l --output NAME | grep -B1 Buddi_crypted | grep loop)
	sudo cryptsetup close $DEVMAPPER_NAME
	sudo losetup -d $LOOP_NAME
	sudo rm -ri $MNT_PATH
	echo "Ok"
	exit 0
}


echo "Starting Buddi financial records crypted init script"
echo 
if [ ! -f ${CONTAINER_PATH} ]; then
	echo "${CONTAINER_PATH} not found. Create (y/N)?"
	read ans;
	if [ $ans == "y" ]; then
		create_container
	else
		echo "Exiting."
		exit 0
	fi
fi

parse_args $1 $2
