#!/bin/bash -xe

# Keep fetching until this uuid to appear in the logs before uploading
END_UUID=$(cat /proc/sys/kernel/random/uuid)

echo "Grabbing consoleLog ($END_UUID)"

# Get the plain text version (does not contain links or timestamps)
console_log_path='consoleText'
while ! grep -q "$END_UUID" /tmp/console.txt; do
    sleep 3
    wget -c -O /tmp/console.txt --no-check-certificate $BUILD_URL$console_log_path
done

# Grab the HTML version of the log (includes timestamps)
console_log_path='logText/progressiveHtml'
while ! grep -q "$END_UUID" /tmp/console.html; do
    sleep 3
    wget -c -O /tmp/console.html --no-check-certificate $BUILD_URL$console_log_path
done

# We need to add <pre> tags around the output for log-osanalyze to not escape
# the content

sed -i '1s/^/<pre>\n/' /tmp/console.html
echo "</pre>" >> /tmp/console.html
