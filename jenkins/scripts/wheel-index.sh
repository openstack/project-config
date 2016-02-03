#!/bin/bash -xe

# Working variables
MIRROR_ROOT=$1
INDEX_FILE=${MIRROR_ROOT}/index.html

# Start building our file
echo -e "<html>\n  <head>\n    <title>Wheel Index</title>\n  </head>" > $INDEX_FILE
echo -e "  <body>\n    <ul>" >> $INDEX_FILE

# Get a list of files
FILES=`find $MIRROR_ROOT -maxdepth 2 -type d`
REGEX="([^/])\/($1[^/]+)$"
for f in $FILES; do
    if [[ $f =~ $REGEX ]]; then
        echo "      <li><a href=\"./${BASH_REMATCH[2]}/\">${BASH_REMATCH[2]}</a></li>" >> $INDEX_FILE
    fi
done

echo -e "    </ul>\n  </body>\n</html>" >> $INDEX_FILEFILE
