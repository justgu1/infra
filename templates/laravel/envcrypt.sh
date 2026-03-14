#!/bin/bash
# Encrypts or decrypts .env using AES-256-CBC.
#
# Usage:
#   ENCRYPT_KEY=yourkey ./envcrypt.sh encrypt   → .env → .env.encrypted
#   ENCRYPT_KEY=yourkey ./envcrypt.sh decrypt   → .env.encrypted → .env
#
# The ENCRYPT_KEY must be stored as a GitHub Secret.
# Never commit the key or the decrypted .env.

set -e

COMMAND="${1:-}"
ENV_FILE=".env"
ENCRYPTED_FILE=".env.encrypted"

if [ -z "$ENCRYPT_KEY" ]; then
    echo "Error: ENCRYPT_KEY is not set."
    exit 1
fi

case "$COMMAND" in
    encrypt)
        if [ ! -f "$ENV_FILE" ]; then
            echo "Error: $ENV_FILE not found."
            exit 1
        fi
        openssl enc -aes-256-cbc -salt -pbkdf2 \
            -in  "$ENV_FILE" \
            -out "$ENCRYPTED_FILE" \
            -pass pass:"$ENCRYPT_KEY"
        echo "Encrypted: $ENV_FILE → $ENCRYPTED_FILE"
        echo "You can safely commit $ENCRYPTED_FILE"
        ;;
    decrypt)
        if [ ! -f "$ENCRYPTED_FILE" ]; then
            echo "Error: $ENCRYPTED_FILE not found."
            exit 1
        fi
        openssl enc -aes-256-cbc -d -pbkdf2 \
            -in  "$ENCRYPTED_FILE" \
            -out "$ENV_FILE" \
            -pass pass:"$ENCRYPT_KEY"
        echo "Decrypted: $ENCRYPTED_FILE → $ENV_FILE"
        ;;
    *)
        echo "Usage: ENCRYPT_KEY=yourkey ./envcrypt.sh [encrypt|decrypt]"
        exit 1
        ;;
esac