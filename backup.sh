#!/usr/bin/env zsh

SCRIPT_DIR=$(dirname $0:A)
source $SCRIPT_DIR/config.env

TIMESTAMP=$(date +%F_%H-%M-%S)
AUTH="$SCRIPT_DIR/auth.env"
WORKDIR="$SCRIPT_DIR/.tmp"
STAGING="$WORKDIR/$BACKUPS_FOLDER"
SOURCES=($SOURCE_1 $SOURCE_2)
ARCHIVE_ENCRYPTED="backup_$TIMESTAMP.tar.gz.gpg"
ARCHIVE_ENCRYPTED_NO_TIMESTAMP="backup.tar.gz.gpg"

cleanup() {
    rm -rf $WORKDIR
}

prepare() {
    cleanup
    mkdir -p $STAGING
}

# $1 target file
# $2 destination
# $3 is remote
replicate() {
    echo "Destination: $2"
    dest="$2/$BACKUPS_FOLDER/"

    if [ -z ${3+x} ]; then
        echo "Copying to local"
        if [ -d "$2" ]; then
            mkdir -p $dest \
            && rsync -P $1 $dest \
            && echo "Copied to $dest$1"
        else
            echo "$2 is not available"
        fi
    else
        echo "Copying to remote"
        rsync -P $1 $dest \
        && echo "Copied to $dest$1"
    fi
}


# Check that sources folders exist
for source in "${SOURCES[@]}"; do
    if [ ! -d "$source" ]; then
        echo "Source $source does not exist"
        exit 1
    else
        echo "$source OK"
    fi
done

prepare

echo "Copying"
# Copy files from sources to documents
for source in ${SOURCES[@]}; do
    cp -R $source $STAGING
    if [ $? -ne 0 ]; then
        echo "Error copying files from $source to $STAGING"
        cleanup
        exit 1
    fi
done

echo "Building archive"
cd $WORKDIR

tar cf - $BACKUPS_FOLDER \
| pigz -9 \
| gpg --cipher-algo AES256 -c --passphrase-file $AUTH --batch > $ARCHIVE_ENCRYPTED

if [ $? -ne 0 ]; then
    echo "Error building archive"
    cleanup
    exit 1
fi

replicate $ARCHIVE_ENCRYPTED $REPLICATION_SITE_1
replicate $ARCHIVE_ENCRYPTED $REPLICATION_SITE_2 1 # Remote

cleanup
echo "Done"
