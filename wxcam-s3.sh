#!/bin/bash
#$Header$

# Delay so we don't conflict with other scripts
sleep 20

DIR="/home/pi/WX"
image="$DIR/wxcam_s3/snap.jpg"

# Get latest wx cam image from old RPi (192.168.1.95), which takes a snapshot every 5 minutes
scp alarm@192.168.1.95:/home/alarm/tmp/snap.jpg $DIR/wxcam_s3 > /dev/null 2>&1

# Calculate brightness of the image
data=$(/usr/bin/convert /home/pi/WX/wxcam_s3/snap.jpg -colorspace gray -verbose info:)
mean=$(echo "$data" | sed -n '/^.*[Mm]ean:.*[(]\([0-9.]*\).*$/{ s//\1/; p; q; }')
bright=$(/usr/bin/convert xc: -format "%[fx:quantumrange*$mean]" info:)

# Convert $bright to an integer
BRIGHT=${bright/.*}
#echo $BRIGHT

# Function definition - code adds timestamp to image.
add_date_time () {
# Redefine DIR variable
DIR="/home/pi/WX/wxcam_s3"
timestamp=$(date)
image_in="$DIR/snap.jpg"
image_tmp="$DIR/snaptmp.jpg"
image_out="$DIR/snapshot.jpg"

# Sharpen the image
convert $image_in -sharpen 0x1.25 $image_tmp

# Annotate with date and time
width=$(identify -format %w $image_tmp)
width=$(( width - 430 ))
convert -background '#0008' -fill white -gravity center -pointsize 13  -size ${width}x30 \
    caption:"$timestamp" \
        $image_tmp +swap -gravity southwest -composite $image_out
}

if [ $BRIGHT -gt 10000 ];
then
    add_date_time
    # Copy image to AWS s3 storage bucket
    # Get image file name with directory components removed
    image_file_name=$(basename "$image_out")
    /usr/local/bin/aws s3 cp $image_out s3://cspawx.ddns.net/wxcam/$image_file_name --acl public-read  > /dev/null 2>&1
fi
