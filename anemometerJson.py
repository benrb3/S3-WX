
import csv

def create_json(my_file):

	datafile = "/home/pi/WX/data/anemometerData.json"

	with open(my_file) as csvfile:
		readCSV = csv.reader(csvfile, delimiter=',')
		for row in readCSV:
			date_time = row[0]
			unix_time = row[1]
			wind_avg  = row[2]
			wind_gust = row[3]

	f = open("%s" % datafile, "w")
	f.write('{\n')
	f.write('\t' + '"date_time":' + ' ' + '"' + date_time + '"' + ',\n')
	f.write('\t' + '"unix_time":' + ' ' + unix_time + ',\n')
	f.write('\t' + '"wind_avg":' + ' ' + wind_avg + ',\n')
	f.write('\t' + '"wind_gust":' + ' ' + wind_gust + '\n')
	f.write('}\n')

	f.close()
