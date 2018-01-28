#!/usr/bin/env python3
#$Header: /home/pi/WX/bin/RCS/getAnemometerData.py,v 1.3 2017/02/06 19:37:09 pi Exp pi $

import subprocess
import serial
import datetime
import time
import re
import os
# The paho module was installed with: sudo pip3 install paho-mqtt
import paho.mqtt.publish as publish
import anemometerJson

datafile = '/home/pi/WX/data/anemometerData.txt'
datafile_json = '/home/pi/WX/data/anemometerData.json'
awskey = '/home/pi/WX/aws/wx-website.pem'
dokey  = '/home/pi/WX/digitalOcean/do1_rsa'
awsdatafile = '/home/ubuntu/WX/data/anemometerData.txt'
dodatafile = '/home/ben/WX/data/anemometerData.txt'

# -----------
# Function to convert anemometer average voltage to wind speed in miles/hour
def convert (bytes) :
  voltageMin = 0.41
  voltageMax = 2.01
  speedMax = 32.0
  speed = 0.0  # meters/second
  string = str(bytes)
  results = re.findall('([\d\.\d]+)', string)
  twoMinuteAverageVoltage  = float(results[0])
  fiveSecondAverageVoltage = float(results[1])
  # Convert voltage values to wind speeds in mph (1 m/s = 2.23694 mph)
  if ( twoMinuteAverageVoltage <= voltageMin ) :
    windSpeed = 0.0 # Set wind speed to zero if voltage is less than or equal to the minimum value
  else :
    # For voltages above minimum value, use the linear relationship to calculate wind speed
    windSpeed = ((( twoMinuteAverageVoltage - voltageMin ) * speedMax ) / ( voltageMax - voltageMin ))
  if ( fiveSecondAverageVoltage <= voltageMin ) :
    gustSpeed = 0.0 # Set wind speed to zero if voltage is less than or equal to the minimum value
  else :
    # For voltages above minimum value, use the linear relationship to calculate wind speed
    gustSpeed = ((( fiveSecondAverageVoltage - voltageMin ) * speedMax ) / ( voltageMax - voltageMin ))
  return (round((windSpeed * 2.23694), 1), round((gustSpeed * 2.23694), 1))
# -----------


# -----------
text = "A"

try :
  # Open serial port and send the letter 'A' command to the Arduino
  ser = serial.Serial('/dev/ttyUSB0', 9600)
  time.sleep(0.1)
  ser.write(text.encode('utf-8'))
  time.sleep(0.1)
  # Read the data (bytes packet) coming back from the Arduino
  bytes = ser.readline()
  ser.close()
  #fv = open("/home/pi/WX/data/data_string.txt", "a")
  #fv.write(str(bytes) + "\n")
  #fv.close()
  # print(bytes)
  # Call conversion function to get wind speeds (average, gust)
  windSpeed, gustSpeed = convert(bytes)
  # print(windSpeed)
  # print(gustSpeed)
  # Timestamps
  # print('{:%Y-%m-%d %H:%M:%S}'.format(datetime.datetime.now()))
  ts = time.time()
  # print(round(ts, 1))
  # print("...")
  # Write data to file, which will be sent to the AWS server
  f = open("%s" % datafile, "w")
  f.write('{:%Y-%m-%d %H:%M:%S}'.format(datetime.datetime.now()))
  f.write("," + str(round(ts, 1)) + "," + str(windSpeed) + "," + str(gustSpeed) + "\n")
  f.close()
  # Create json data file
  anemometerJson.create_json(datafile)
  # Publish to local mosquitto MQTT server (this feeds home web server)
  publish.single("wind", str(windSpeed) + "," + str(gustSpeed), hostname="192.168.1.102")

except :
  pass
# -----------

# Send file 'anemometerData.txt' to Amazon AWS t2.micro instance and Digital Ocean droplet using secure copy (scp)
#result1 = subprocess.getoutput("scp -i /home/pi/WX/aws/wx-website.pem /home/pi/WX/data/anemometerData.txt ubuntu@35.164.26.176:/home/ubuntu/WX/data")
#time.sleep(3)
#result1 = subprocess.getoutput("ssh -i /home/pi/WX/aws/wx-website.pem ubuntu@cspa16403.hopto.org docker cp /home/ubuntu/WX/data/anemometerData.txt wxdata:/datavolume1/data")
#result2 = subprocess.getoutput("scp -i /home/pi/WX/digitalOcean/do1_rsa /home/pi/WX/data/anemometerData.txt root@45.55.89.253:/home/ben/WX/data")

# New, more streamlined transfer of anemomter data to servers
#-------
# Send file to Amazon server
result = subprocess.getoutput('cat %s | ssh -i %s ubuntu@cspa16403.hopto.org \
"cat > %s; docker cp %s wxdata:/datavolume1/data"' % (datafile, awskey, awsdatafile, awsdatafile))
# Send file to Digital Ocean server
result = subprocess.getoutput('cat %s | ssh -i %s root@wxben.ddns.net \
"cat > %s"' % (datafile, dokey, dodatafile))
#-------

# Update winddata.rrd database
devnull = open(os.devnull, 'w')
subprocess.call(["/home/pi/WX/rrd/bin/update_wind_rrd.sh"], stdout=devnull)

# Send file to AWS S3 storage bucket
datafile_json_basename = os.path.basename(datafile_json)
subprocess.call(["/usr/local/bin/aws", "s3", "cp", datafile_json, "s3://cspawx.ddns.net/data/" + datafile_json_basename, "--acl", "public-read"], stdout=devnull)
devnull.close()
