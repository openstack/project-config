#!/bin/bash -xe

RETRY_LIMIT=20

# Keep fetching until this uuid appears in the logs before uploading
END_UUID=$(cat /proc/sys/kernel/random/uuid)

echo "Grabbing consoleLog ($END_UUID)"

# Since we are appending to fetched logs, remove any possibly old runs
rm -f /tmp/console.html

# Grab the HTML version of the log (includes timestamps)
TRIES=0
console_log_path='logText/progressiveHtml'
while ! grep -q "$END_UUID" /tmp/console.html; do
    TRIES=$((TRIES+1))
    if [ $TRIES -gt $RETRY_LIMIT ]; then
        break
    fi
    sleep 3
    curl -X POST --data "start=$(stat -c %s /tmp/console.html || echo 0)" --insecure $BUILD_URL$console_log_path >> /tmp/console.html
done

# We need to add <pre> tags around the output for log-osanalyze to not escape
# the content

sed -i '1s/^/<pre>\n/' /tmp/console.html
echo "</pre>" >> /tmp/console.html
