#!/bin/bash
set -e


# set some folders and permissions

mkdir -p "$MBDATA" "$PGDATA"
chown abc:abc "$DATA_ROOT"

mkdir -p /var/run/postgresql
chown -R abc:abc /var/run/postgresql /app

set_listen_addresses() {
	sedEscapedValue="$(echo "*" | sed 's/[\/&]/\\&/g')"
	sed -ri "s/^#?(listen_addresses\s*=\s*)\S+/\1'$sedEscapedValue'/" "$PGDATA/postgresql.conf"
}

# initialise empty database structure and change temporary ownership config files
if [ ! -s "$PGDATA/PG_VERSION" ]; then
chown -R abc:abc "$DATA_ROOT"

dumpver=$(curl -s "$URL_ROOT"/LATEST)
DUMP_URL="$URL_ROOT"/"$dumpver"
DUMP_DEST="$MBDATA"/"$dumpver"
mkdir -p "$DUMP_DEST"
chown abc:abc "$DUMP_DEST"
echo "fetching latest dump from musicbrainz, if this section fails try again later as musicbrainz dump may not be fully uploaded 
to their site"

# /sbin/setuser abc curl -o "$DUMP_DEST"/MD5SUMS -L -C - "$DUMP_URL"/MD5SUMS
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-cdstubs.tar.bz2 -L -C - "$DUMP_URL"/mbdump-cdstubs.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-cover-art-archive.tar.bz2 -L -C - "$DUMP_URL"/mbdump-cover-art-archive.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-derived.tar.bz2 -L -C - "$DUMP_URL"/mbdump-derived.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-editor.tar.bz2 -L -C - "$DUMP_URL"/mbdump-editor.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-stats.tar.bz2 -L -C - "$DUMP_URL"/mbdump-stats.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-wikidocs.tar.bz2 -L -C - "$DUMP_URL"/mbdump-wikidocs.tar.bz2
/sbin/setuser abc curl -o "$DUMP_DEST"/mbdump.tar.bz2 -L -C - "$DUMP_URL"/mbdump.tar.bz2
# /sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-sitemaps.tar.bz2 -L -C - "$DUMP_URL"/mbdump-sitemaps.tar.bz2
# /sbin/setuser abc curl -o "$DUMP_DEST"/mbdump-edit.tar.bz2 -L -C - "$DUMP_URL"/mbdump-edit.tar.bz2

echo "initialising empty databases"
/sbin/setuser abc initdb >/dev/null 2>&1
echo "completed postgres initialise"

echo "local   all    all    trust" >> "$PGDATA/pg_hba.conf"
echo "host all  all    0.0.0.0/0  md5" >> "$PGDATA/pg_hba.conf"
set_listen_addresses ''

/sbin/setuser abc postgres  >/dev/null 2>&1 &
pid="$!"
sleep 5s
/sbin/setuser abc createdb  >/dev/null 2>&1
/sbin/setuser abc psql --command "ALTER USER abc WITH SUPERUSER PASSWORD 'abc';"  >/dev/null 2>&1
sleep 5s
echo "BEGINNING INITIAL DATABASE IMPORT ROUTINE, THIS COULD TAKE SEVERAL HOURS AND THE DOCKER MAY LOOK UNRESPONSIVE"
echo "DO NOT STOP DOCKER UNTIL IT IS COMPLETED"

cd /app/musicbrainz || exit
/sbin/setuser abc ./admin/InitDb.pl --createdb --import "$DUMP_DEST"/mbdump*.tar.bz2 --tmp-dir "$DUMP_DEST" --echo
echo "INITIAL IMPORT IS COMPLETE, MOVING TO NEXT PHASE"

kill "$pid"  >/dev/null 2>&1
wait "$pid"
set_listen_addresses '*'
sleep 1s
fi

mkdir -p "$PGCONF"
[[ ! -f "$PGCONF"/postgresql.conf ]] && cp "$PGDATA"/postgresql.conf "$PGCONF"/postgresql.conf
chown abc:abc "$PGCONF"/postgresql.conf
chmod 666 "$PGCONF"/postgresql.conf

crontab /defaults/musicbrainz

