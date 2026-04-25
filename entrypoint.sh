#!/bin/sh

if [ -n "$GAME_PATH" ]; then
    echo "Welcome to Pamplona Future."
    echo "Copying MITM files to $GAME_PATH..."
    cp /mitm/EA-MITM.ini "$GAME_PATH/"
    cp /mitm/dinput8.dll "$GAME_PATH/"
fi

cleanup() {
    if [ -n "$GAME_PATH" ]; then
        echo "Cleaning up MITM files and logs from $GAME_PATH..."
        rm -f "$GAME_PATH/EA-MITM.ini"
        rm -f "$GAME_PATH/EA-MITM.log"
        rm -f "$GAME_PATH/dinput8.dll"
        rm -f "$GAME_PATH"/protossl_dump*.acp
    fi
    exit 0
}

trap cleanup SIGTERM SIGINT

export DATABASE_URL="${DATABASE_URL:-postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOSTNAME}:${POSTGRES_PORT}/${POSTGRES_DB}}"

pnpm exec prisma db push && pnpm exec prisma db seed && pnpm exec tsx ./src/ &

wait $!