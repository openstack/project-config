#!/bin/bash -xe

RETRY_LIMIT=20

# Keep fetching until this uuid appears in the logs before uploading
END_UUID=$(cat /proc/sys/kernel/random/uuid)

echo "Grabbing consoleLog ($END_UUID)"

# Since we are appending to fetched logs, clear any possibly old runs
# Don't add a newline so we end up with a 0 byte file.
echo -n > /tmp/console.html

# Grab the HTML version of the log (includes timestamps)
TRIES=0
console_log_path='logText/progressiveHtml'
while ! grep -q "$END_UUID" /tmp/console.html; do
    TRIES=$((TRIES+1))
    if [ $TRIES -gt $RETRY_LIMIT ]; then
        echo "Failed grabbing consoleLog within $RETRY_LIMIT retries."
        break
    fi
    sleep 3
    # -X POST because Jenkins doesn't do partial gets properly when
    #         job is running.
    # --data start=X instructs Jenkins to mimic a partial get using
    #                POST. We determine how much data we need based on
    #                how much we already have.
    # --fail will cause curl to not output data if the request
    #        fails. This allows us to retry when we have Jenkins proxy
    #        errors without polluting the output document.
    # --insecure because our Jenkins masters use self signed SSL certs.
    curl -X POST --data "start=$(stat -c %s /tmp/console.html || echo 0)" \
        --fail --insecure $BUILD_URL$console_log_path \
        >> /tmp/console.html || true
done

# We need to add <pre> tags around the output for log-osanalyze to not escape
# the content

sed -i '1s/^/<pre>\n/' /tmp/console.html
echo "</pre>" >> /tmp/console.html
