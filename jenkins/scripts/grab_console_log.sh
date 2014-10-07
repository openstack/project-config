#!/bin/bash -xe

echo "Grabbing consoleLog"

# Get the plain text version (does not contain links or timestamps)
console_log_path='consoleText'
wget -O /tmp/console.txt --no-check-certificate $BUILD_URL$console_log_path

# Grab the HTML version of the log (includes timestamps)
console_log_path='logText/progressiveHtml'
wget -O /tmp/console.html --no-check-certificate $BUILD_URL$console_log_path

# We need to add <pre> tags around the output for log-osanalyze to not escape
# the content

sed -i '1s/^/<pre>\n/' /tmp/console.html
echo "</pre>" >> /tmp/console.html
