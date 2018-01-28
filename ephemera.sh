#!/bin/bash
#$Header$

FILE="/home/pi/WX/data/solunar.txt"
FILE_json="/home/pi/WX/data/solunar.json"

/usr/local/bin/solunar -l 41.84,-80.09 --syslocal > $FILE

# Remove blank lines
sed -i '/^$/d' $FILE
# Remove leading whitespace
sed -i "s/^[ \t]*//" $FILE

# Extract times
sunrise=$(grep Sunrise $FILE|sed 's/Sunrise: //')
sunset=$(grep Sunset $FILE|sed 's/Sunset: //')
moonrise=$(grep 'Moonrise' $FILE|sed 's/Moonrise: //')
moonset=$(grep 'Moonset' $FILE|sed 's/Moonset: //')
moonphase=$(grep 'Moon phase' $FILE|sed 's/Moon phase: //')
sys_uptime=$(uptime | awk '{print $3 " "$4" " $5" " $6}'|sed 's/,$//')

cat << EOF > $FILE_json
{
    "sunrise": "$sunrise",
    "sunset": "$sunset",
    "moonrise": "$moonrise",
    "moonset": "$moonset",
    "moonphase": "$moonphase",
    "uptime": "$sys_uptime"
}
EOF

# Send file to AWS S3 storage bucket
file_json_basename=$(basename "$FILE_json")
/usr/local/bin/aws s3 cp $FILE_json s3://cspawx.ddns.net/data/$file_json_basename --acl public-read > /dev/null 2>&1
