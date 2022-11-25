#!/usr/bin/env bash

CLIP1=$1
CLIP2=$2
OUTPUT=$3

function help {
    echo "Usage: $0 <first_video> <second_video> <output_file>"
    exit
}

function read_stream_info {
    INPUT=$(ffprobe -count_packets -show_entries stream=nb_read_packets,r_frame_rate,width,height,sample_rate -v quiet $1 | awk -F= '$2{print $2}')

    [[ "$INPUT" == "" ]] && >&2 echo "Can't read information from file $1" && exit
    printf "$INPUT"
}

function convert_clips {
    TMP1=$(mktemp XXXXXXXXXX.mp4)
    TMP2=$(mktemp XXXXXXXXXX.mp4)
    { read w; read h; read fps; read packets; read rate;} <<< $(read_stream_info $CLIP2)
    [[ "$w" == "" ]] && cleanup
    echo "Converting clips..."
    ffmpeg -i $CLIP1 -vf "fps=$FPS" -y -v quiet $TMP1
    nw=$(printf "%.0f" $(echo "$HEIGHT/$h*$w" | bc -l))
    nh=$HEIGHT
    (( "$nw" % 2 != 0 )) && nw=$(("$nw" + 1))
    (( "$nw" < $WIDTH )) && nh=$(printf "%.0f" $(echo "$WIDTH/$w*$h" | bc -l)) && nw=$WIDTH
    (( "$nh" % 2 != 0 )) && nh=$(("$nh" + 1))
    ffmpeg -i $CLIP2 -ar $RATE -keyint_min $packets -vf "fps=$FPS,scale=$nw:$nh,crop=$WIDTH:$HEIGHT:(iw-ow)/2:(ih-oh)/2" -y -v quiet $TMP2
    
}

function concat_clips {
    LIST=$(mktemp XXXXXXXXXX.txt)
    echo -e "file $TMP1\nfile $TMP2" > $LIST

    [ -f $OUTPUT ] && [[ "$(read -e -p 'File '$OUTPUT' already exists, do you want to replace? [y/N]>'; echo $REPLY)" != [Yy]* ]] && return
    echo "Combining files and removing keyframes..."
    ffmpeg -f concat -i $LIST -c:v copy -bsf:v "noise=drop='eq(n,$PACKETS)'" -y -v quiet $OUTPUT
}

function cleanup {
    echo "Removing temporary files..."
    [ -f "$TMP1" ] && rm $TMP1
    [ -f "$TMP2" ] && rm $TMP2
    [ -f "$LIST" ] && rm $LIST
    echo "Done."
    exit
}

[ $# -lt 3 ] && help
[ ! -f $CLIP1 ] && echo "File $CLIP1 does not exist" && exit
[ ! -f $CLIP2 ] && echo "File $CLIP2 does not exist" && exit

{ read WIDTH; read HEIGHT; read FPS; read PACKETS; read RATE;} <<< $(read_stream_info $CLIP1)
[[ "$WIDTH" == "" ]] && cleanup
convert_clips 
concat_clips
cleanup
