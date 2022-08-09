#!/usr/bin/env zsh

SCRIPT_DIR=$(dirname $0:A)
source $SCRIPT_DIR/config.env

AUTH="$SCRIPT_DIR/auth.env"
WORKDIR="$SCRIPT_DIR/.tmp"
SOURCES=($SOURCE_1 $SOURCE_2)
ARCHIVE_ENCRYPTED="backup.tar.gz.gpg"


cleanup() {
    rm -rf $WORKDIR
}

trap cleanup SIGINT
trap cleanup EXIT

prepare() {
    cleanup
    mkdir -p $WORKDIR
}

# $1 target file
# $2 destination
# $3 is remote
replicate() {
    send() {
        rsync -aP $1 $2 \
        && echo "Copied to $2$1"
    }

    echo "Destination: $2"
    dest="$2/$BACKUPS_FOLDER/"

    if [ -z ${3+x} ]; then
        echo "Copying to local"
        if [ -d "$2" ]; then
            mkdir -p $dest && \
            send $1 $dest
        else
            echo "$2 is not available"
        fi
    else
        echo "Copying to remote"
        send $1 $dest
    fi
}

# Check that sources folders exist
for source in "${SOURCES[@]}"; do
    src="$SOURCE_DIRECTORY/$source"
    if [ ! -d "$src" ]; then
        echo "Source $src does not exist"
        exit 1
    else
        echo "$src OK"
    fi
done

prepare

echo "Building archive"
cd $WORKDIR

tar -C $SOURCE_DIRECTORY -cf - $SOURCE_1 $SOURCE_2 \
| pigz -9 \
| pv | gpg --cipher-algo AES256 -c --passphrase-file $AUTH --batch -o $ARCHIVE_ENCRYPTED

if [ $? -ne 0 ]; then
    echo "Error building archive"
    exit 1
fi

replicate $ARCHIVE_ENCRYPTED $REPLICATION_SITE_1
replicate $ARCHIVE_ENCRYPTED $REPLICATION_SITE_2

echo "Done"
