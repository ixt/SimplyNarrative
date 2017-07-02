#!/usr/bin/env bash
# Utility for dealing with Memento/Narrative Clip
# CC-0 Ixtli Orange 2017

# if width is 0 or less than 60, make it 80
# if width is greater than 178 then make it 120

INTERFACE="usb0"

calc_whiptail_size(){
    WT_HEIGHT=20
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 50 ]; then
        WT_WIDTH=60
    fi
    if [ "$WT_WIDTH" -gt 60 ]; then
        WT_WIDTH=60
    fi

    WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_about() {
    whiptail --msgbox "
    This utility is designed to make downloading and working
    with a Narrative Clip on Linux much nicer and pretty.\
        " 20 70 1
}

do_change_if() {
    sudo ifconfig $INTERFACE 192.168.2.10 netmask 255.255.255.0 broadcast 192.168.2.255
}

do_get_host_ip() {
    sudo ifconfig $INTERFACE | grep "inet addr:" | cut -d: -f2 | awk '{ print $1 }'
}

do_get_files() {
    # If folder doesn't exist then make it
    if [ ! -e ./files ]; then
        mkdir files && cd files
    fi
    # move into files folder and download all from narrative
    cd files
    wget ftp://192.168.2.2/mnt/storage/ --recursive -A jpg,json,snap
    mv ./192.168.2.2/mnt/storage/* ./ 
    rm -d *_* lost+found 192.168.2.2/mnt/storage 192.168.2.2/mnt 192.168.2.2 2>/dev/null
    # list all directories
    ls -1 -p | sed -n "/\//p" > .dirs
    # for ever directory make a list of files then rename them to be sane
    while read dir; do
        cd $dir
        ls -1 *.json *.snap *.jpg 2>/dev/null > .files
        while read entry; do
            FILENAME=$( echo $entry | sed -E "s/event_([^_]*)_([^_]*)_([^_.]*)\.(.*)/\1_\2.\4/")
            mv $entry $FILENAME
        done < .files 
        rm .files
        cd ..
    done < .dirs
    rm .dirs
    cd ..
}

# Pipe a filtered ls command after telneting to stdin and then to a textbox
do_list_images() {
{ echo "ls /mnt/storage -1 -p | grep -v "lost" | grep /"; sleep 2;  echo "exit"; } | telnet 192.168.2.2 | grep -vE '(ls|Connection|#|Try|192.168.2.2|Escape)' | cut -c1-10 > .tmp_listfolders
    whiptail --textbox ./.tmp_listfolders 17 80
    rm .tmp_listfolders
}

do_clear_files() {
    { echo "rm /mnt/storage/*_*/ -r";sleep 10; echo "exit"; } | telnet 192.168.2.2
    whiptail --textbox "Done" 10 20
}

do_set_time() {
    TIME=$(date +%Y%m%d%H%M.%S)
    { echo "date --set "$TIME ;sleep 1; echo "exit"; } | telnet 192.168.2.2
    whiptail --textbox "Done" 10 20
}

do_download_then_clear() {
    do_get_files
    do_clear_files
}

rotate_images_and_clean() {
    cd files
    ls -1 > .folders
    while read folder; do
        cd $folder
        # Delete Orphan Files
        ls *.json *.jpg -1 2>/dev/null | sed -e "s/\..*//g" | uniq -u | sed -e 's/$/.meta.json/g' | xargs rm -f 2>/dev/null
        ls *.json -1 > .listoffiles 2>/dev/null
        # Get & Use Accelerometer data
        while read entry; do 
            X=$(grep acc_data $entry | cut -c 28- | cut -f 1 -d ']' | sed -e 's/,//;s/, / /' | cut -d' ' -f 1)
            FILE=$(echo $entry | sed -e "s/\.meta\.json/\.jpg/g")
            if [ ! $X -lt -800 ]; then
                convert $FILE -rotate "-90>" $FILE 2>/dev/null
            fi
        done < .listoffiles
        rm *.json .listoffiles 2>/dev/null
        echo "completed $(printf '%s\n' "${PWD##*/}")" 
        cd ..
    done < .folders
    rm * -d -f 2>/dev/null
    cd ..
}

#
# Interactive loop
#

calc_whiptail_size
while true; do
    FUN=$(whiptail --title "Memento/Narrative Utility" --menu "options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
    "1 About" "What's this all about?" \
    "2 Change interface" "add the usb0 interface required" \
    "3 List" "list image folders on Clip" \
    "4 Images+JSON" "does what it sounds like" \
    "5 Delete" "files on device" \
    "6 Time" "set time" \
    "7 Sort" "sort and rotate images in files" \
    3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        exit 0
    elif [ $RET -eq 0 ]; then
        case "$FUN" in
            1\ *) do_about ;;
            2\ *) do_change_if ;;
            3\ *) do_list_images ;;
            4\ *) do_get_files ;;
            5\ *) do_clear_files ;;
            6\ *) do_set_time ;;
            7\ *) rotate_images_and_clean ;;
            *) whiptail --msgbox "Unrecognised option" 20 60 1 ;;
        esac
    else
        exit 1
    fi
done

