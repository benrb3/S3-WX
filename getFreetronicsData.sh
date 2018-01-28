#!/bin/ksh
#$Header: /home/pi/WX/bin/RCS/getFreetronicsData.sh,v 1.4 2017/02/06 19:37:46 pi Exp pi $

# This script gets data from the Freetronics Etherten using the netcat (nc) utility
# Sleep for a bit so as not to conflict with another script running at same time via cron
sleep 15

# Define file names
DIR="/home/pi/WX"
bogus_file="$DIR/tmp/bogus.txt"
tmp_data_entry="$DIR/tmp/tmp_data_entry"
data_file="$DIR/data/freetronicsData.txt"
data_file_json="$DIR/data/freetronicsData.json"
awskey="$DIR/aws/wx-website.pem"
dokey="$DIR/digitalOcean/do1_rsa"
awsdatafile="/home/ubuntu/WX/data/freetronicsData.txt"
dodatafile="/home/ben/WX/data/freetronicsData.txt"

# Function to create *.json data file
create_json_file () {
while IFS=',' read col1 col2 col3 col4 col5 col6 col7 col8 col9
do
  date_time=$col1
  unix_time=$col2
  inTempC=$col3
  inTempF=$col4
  outTempC=$col5
  outTempF=$col6
  pressure=$col7
  inRH=$col8
  outDewptF=$col9
done < $data_file
cat << EOF > $data_file_json
{
	 "date_time": "$date_time",
	 "unix_time": $unix_time,
	 "inTempC": $inTempC,
	 "inTempF": $inTempF,
	 "outTempC": $outTempC,
	 "outTempF": $outTempF,
	 "pressure": $pressure,
	 "inRH": $inRH,
	 "outDewptF": $outDewptF
}
EOF
}

# Create bogus file
echo '123456' > $bogus_file

count=1
while [ $count -le 3 ]; do
    # Send a UDP packet to the Arduino, which returns a data string
    # that nc redirects into $tmp_data_entry
    /bin/nc -w 4 -u 192.168.1.120 8888 < $bogus_file > $tmp_data_entry

    # Check integrity of data string, which should have 7 comma-separated fields
    num_fields=$(awk -F ',' '{ print NF }' $tmp_data_entry)

    if [ $num_fields -eq 7 ]
    then
        # Write timestamp to data file
        date_time=$(date -u '+%F %T,%s,')
        #echo $date_time | tr -d '\n' > $data_file
        echo -n $date_time > $data_file
        # Write data to file
        cat $tmp_data_entry >> $data_file
        echo "" >> $data_file
        create_json_file
        # Update sqlite3 database
        /home/pi/WX/sqlite3/bin/sqlite3_insert.sh
        #/home/pi/WX/rrd/bin/update_rrd.sh
        break
    else
        # wait 5 seconds and try again to get a good data string
        (( count++ )); sleep 5; continue
    fi
done

# Send file 'freetronicsData.txt' to Amazon t2.micro instance and Digital Ocean droplet using secure copy (scp)
#/usr/bin/scp -i $DIR/aws/wx-website.pem $DIR/data/freetronicsData.txt ubuntu@35.164.26.176:/home/ubuntu/WX/data > /dev/null 2>&1
#sleep 3
#/usr/bin/ssh -i $DIR/aws/wx-website.pem ubuntu@cspa16403.hopto.org docker cp /home/ubuntu/WX/data/freetronicsData.txt wxdata:/datavolume1/data > /dev/null 2>&1
#/usr/bin/scp -i $DIR/digitalOcean/do1_rsa $DIR/data/freetronicsData.txt root@45.55.89.253:/home/ben/WX/data > /dev/null 2>&1

# ------
# More streamlined method of tranferring freetronics data to servers
# Send data to Amazon server
cat $data_file | ssh -i $awskey ubuntu@cspa16403.hopto.org "cat > $awsdatafile; docker cp $awsdatafile wxdata:/datavolume1/data"
# Send data to Digital Ocean server
cat $data_file | ssh -i $dokey root@wxben.ddns.net "cat > $dodatafile"
# ------

# Update wxdata.rrd database
$DIR/rrd/bin/update_rrd.sh

# Send $data_file_json to AWS S3 storage bucket
data_file_json_basename=$(basename "$data_file_json")
/usr/local/bin/aws s3 cp $data_file_json s3://cspawx.ddns.net/data/$data_file_json_basename --acl public-read > /dev/null 2>&1

exit
