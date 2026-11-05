#!/bin/bash

# ============================================================
# SWAKS Batch Email Testing Script
# ============================================================

# Prompt for SMTP settings
read -p "Enter SMTP Server: " SMTP_SERVER

read -p "Enter SMTP Port (default 587): " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}

read -p "Enter SMTP User ID: " AUTH_USER

read -sp "Enter SMTP Password: " AUTH_PASS
echo

# Prompt for sender information
read -p "Enter Envelope From (MAIL FROM): " FROM_EMAIL

read -p "Enter Header From email (default $FROM_EMAIL): " HEADER_FROM_EMAIL
HEADER_FROM_EMAIL=${HEADER_FROM_EMAIL:-$FROM_EMAIL}

read -p "Enter Friendly From name: " FRIENDLY_NAME

# Construct RFC 5322 From header
if [[ -n "$FRIENDLY_NAME" ]]; then
    HEADER_FROM="\"$FRIENDLY_NAME\" <$HEADER_FROM_EMAIL>"
else
    HEADER_FROM="$HEADER_FROM_EMAIL"
fi

# Message settings
read -p "Enter Subject Line: " SUBJECT

read -p "Enter Path to CSV File: " CSV_FILE

read -p "Enter Path to Email Body File: " BODY_FILE


# ============================================================
# Validate required values
# ============================================================

if [[ -z "$SMTP_SERVER" ]]; then
    echo "ERROR: SMTP server cannot be blank."
    exit 1
fi

if [[ -z "$AUTH_USER" ]]; then
    echo "ERROR: SMTP user cannot be blank."
    exit 1
fi

if [[ -z "$AUTH_PASS" ]]; then
    echo "ERROR: SMTP password cannot be blank."
    exit 1
fi

if [[ -z "$FROM_EMAIL" ]]; then
    echo "ERROR: Envelope From cannot be blank."
    exit 1
fi

if [[ -z "$HEADER_FROM_EMAIL" ]]; then
    echo "ERROR: Header From email cannot be blank."
    exit 1
fi

if [[ -z "$SUBJECT" ]]; then
    echo "ERROR: Subject cannot be blank."
    exit 1
fi


# ============================================================
# Validate input files
# ============================================================

if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: CSV file not found: $CSV_FILE"
    exit 1
fi

if [[ ! -f "$BODY_FILE" ]]; then
    echo "ERROR: Email body file not found: $BODY_FILE"
    exit 1
fi


# ============================================================
# Generate batch ID
# ============================================================

# Generated once so every message in this run has the same ID
BATCH_ID=$(date +"%Y%m%d%H%M")


# ============================================================
# Display test configuration
# ============================================================

echo
echo "============================================================"
echo "Starting email test"
echo "============================================================"
echo "SMTP Server:    $SMTP_SERVER:$SMTP_PORT"
echo "Envelope From:  $FROM_EMAIL"
echo "Header From:    $HEADER_FROM"
echo "Subject:        $SUBJECT"
echo "CSV File:       $CSV_FILE"
echo "Body File:      $BODY_FILE"
echo "X-250ok-CID:    $BATCH_ID"
echo "============================================================"
echo


# ============================================================
# Process recipient CSV
# ============================================================

SENT_COUNT=0
FAILED_COUNT=0

# Use file descriptor 3 for the CSV.
# This prevents SWAKS from consuming the remaining CSV data.
while IFS=, read -r email first_name <&3; do

    # Remove Windows carriage returns if CSV uses CRLF
    email=${email//$'\r'/}
    first_name=${first_name//$'\r'/}

    # Skip CSV header
    if [[ "$email" == "email" ]]; then
        continue
    fi

    # Skip blank rows
    if [[ -z "$email" ]]; then
        continue
    fi

    echo
    echo "------------------------------------------------------------"
    echo "Sending test to: $email"
    echo "------------------------------------------------------------"

    ./swaks \
        --to "$email" \
        --from "$FROM_EMAIL" \
        --server "$SMTP_SERVER" \
        --port "$SMTP_PORT" \
        --auth-user "$AUTH_USER" \
        --auth-password "$AUTH_PASS" \
        --header "From: $HEADER_FROM" \
        --header "Content-Type: text/html; charset=UTF-8" \
        --header "Subject: $SUBJECT" \
        --header "X-250ok-CID: $BATCH_ID" \
        --body "$(cat "$BODY_FILE")" \
        < /dev/null

    SWAKS_EXIT=$?

    if [[ $SWAKS_EXIT -eq 0 ]]; then
        ((SENT_COUNT++))
        echo "SUCCESS: $email"
    else
        ((FAILED_COUNT++))
        echo "FAILED: $email (SWAKS exit code $SWAKS_EXIT)"
    fi

done 3< "$CSV_FILE"


# ============================================================
# Test summary
# ============================================================

echo
echo "============================================================"
echo "Email test complete"
echo "============================================================"
echo "Batch ID:          $BATCH_ID"
echo "Successful sends:  $SENT_COUNT"
echo "Failed sends:      $FAILED_COUNT"
echo "============================================================"