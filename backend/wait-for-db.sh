#!/bin/sh
# wait-for-db.sh: wait for PostgreSQL and exit successful to continue startup commands

# Usage: wait-for-db.sh <db_host> <db_port>
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <db_host> <db_port>" >&2
  exit 1
fi

host="$1"
port="$2"

echo "⏳ Waiting for Postgres on $host:$port"

# Wait until PostgreSQL is accepting connections
until nc -z "$host" "$port"; do
  echo "❌ Postgres is unavailable - sleeping"
  sleep 1
done

echo "✅ Postgres is up - continuing"
# Exit successfully to allow the calling shell to proceed
exit 0