#!/usr/bin/env python
#
# Convert IEEE Vendor DB to KisMac 
#
# Geordie Millar (aka themacuser)
#

import sys,httplib,xml.sax.saxutils

header = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\x09<key>01:00:0C</key>
\x09<string>Cisco-multicast</string>
\x09<key>01:00:10</key>
\x09<string>Hughes-multicast</string>
\x09<key>01:00:1D</key>
\x09<string>Enterasys-multicast</string>
\x09<key>01:00:5E</key>
\x09<string>multicast</string>
\x09<key>01:00:5E:00:00:01</key>
\x09<string>all-hosts-multicast</string>
\x09<key>01:00:5E:00:00:02</key>
\x09<string>all-routers-multicast</string>
\x09<key>01:00:5E:00:00:04</key>
\x09<string>DVMRP-multicast</string>
\x09<key>01:00:5E:00:00:05</key>
\x09<string>OSPF-multicast</string>
\x09<key>01:00:5E:00:00:06</key>
\x09<string>OSPF-designated-multicast</string>
\x09<key>01:00:5E:00:00:09</key>
\x09<string>RIP2-multicast</string>
\x09<key>01:00:5E:00:00:0C</key>
\x09<string>DHCP-agent-multicast</string>
\x09<key>01:00:5E:00:00:0D</key>
\x09<string>PIM-multicast</string>
\x09<key>01:00:5E:00:00:0E</key>
\x09<string>RSVP-encapsulation</string>
\x09<key>01:00:5E:00:00:10</key>
\x09<string>IGRP-multicast</string>
\x09<key>01:00:5E:00:00:12</key>
\x09<string>VRRP-multicast</string>
\x09<key>01:00:5E:00:00:EB</key>
\x09<string>DNS-multicast</string>
\x09<key>01:00:5E:00:01:01</key>
\x09<string>NTP-multicast</string>
\x09<key>01:00:5E:00:01:08</key>
\x09<string>NIS-plus-multicast</string>
\x09<key>01:00:5E:00:01:8D</key>
\x09<string>DHCP-server-multicast</string>
\x09<key>01:00:5E:00:07:06</key>
\x09<string>Tivoli-multicast</string>
\x09<key>01:00:5E:00:07:13</key>
\x09<string>PolyCom-multicast</string>
"""

footer = """</dict>
</plist>
"""
try:
	if (sys.argv[1] == "-f"):
		source = 2
	if (sys.argv[1] == "-i"):
		source = 1

except:
	print """ConvertVendorDB.py - convert IEEE's vendor db listing to a KisMac Vendor DB XML file.
Usage: %s -f to retrieve from a file (oui.txt in the local directory)
or     %s -i to download from the internet and parse.
File is written as vendor.db in the local directory."""
	sys.exit()

if (source == 1):
	print "Connecting to standards.ieee.org..."
	conn = httplib.HTTPConnection("standards.ieee.org")
	conn.request("GET", "/regauth/oui/oui.txt")
	print "GET /regauth/oui/oui.txt"
	reply = conn.getresponse()
	if (reply.status != 200):
		print "%s %s. Exiting." % (reply.status, reply.reason)
		sys.exit()
	print reply.status, reply.reason
	print "Now downloading, please wait..."
	data = reply.read()

if (source == 2):
	f = open('oui.txt', 'r')
	data = f.read()
	f.close()

lines = range(data.count("\n"))
lined_data = data.split("\n")
print "Read %i vendors, now processing" % data.count("(hex)")

vendors = {}
vcount = 0

for line in lines:
	theLine = lined_data[line]
	print ".",
	if (theLine.count("(hex)") == 1):
		vcount += 1
		vendors[vcount] = theLine

vendors_range = range(1, len(vendors) + 1)

db = header

for thisVendor in vendors_range:
	currentVendor = vendors[thisVendor]
	currentVendor = currentVendor.split("   ");
	currentVendor[1] = xml.sax.saxutils.escape(currentVendor[1].split("\t\t")[1]);
	currentVendor[0] = str.replace(currentVendor[0], "-", ":")
	db += ("\x09<key>%s</key>\n\x09<string>%s</string>\n" % (currentVendor[0], currentVendor[1]))
	sys.stdout.flush()

db += footer

print "Saving to vendor.db"
db2 = ""

for character in db:
	if (ord(character) < 128):
		db2 += character

f = open('vendor.db', 'w')
f.write(unicode(db2,"UTF-8",errors="ignore"))
f.close()

print "Done."
