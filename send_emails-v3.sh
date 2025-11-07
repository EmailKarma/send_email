#!/bin/bash
set -euo pipefail

# Prompt for required inputs
read -p "Enter SMTP Server: " SMTP_SERVER
read -p "Enter SMTP Port (default 587): " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587} # Default to 587 if no port is entered
read -p "Enter SMTP User ID: " AUTH_USER
read -sp "Enter SMTP Password: " AUTH_PASS
echo
read -p "Enter Sender Email: " FROM_EMAIL
read -p "Enter Subject: " SUBJECT
read -p "Enter Path to CSV File: " CSV_FILE
read -p "Enter Path to Email Body File: " Body_file

# Generate the unique batch ID based on the current date and time
BATCH_ID=$(date +"%Y%m%d%H%M")

# Helper: trim whitespace and ensure a single trailing ">"
normalize_rcpt () {
  local raw="$1"
  # strip leading/trailing spaces, quotes, and newline chars
  raw="${raw//$'\r'/}"
  raw="${raw//$'\n'/}"
  raw="${raw//$'\t'/}"
  raw="${raw% }"
  raw="${raw# }"
  raw="${raw%\"}"
  raw="${raw#\"}"

  # ensure exactly one trailing ">"
  # remove any existing trailing ">", then append one
  raw="${raw%>}>"
  printf '%s' "$raw"
}

# Read the CSV file line by line
# Expecting columns: email,first_name
while IFS=, read -r email first_name; do
  # Skip the header row
  if [[ "${email,,}" != "email" && -n "$email" ]]; then
    RCPT=$(normalize_rcpt "$email")

    # Send email using SWAKS with TLS enabled
    swaks \
      --to "$RCPT" \
      --from "$FROM_EMAIL" \
      --server "$SMTP_SERVER" \
      --port "$SMTP_PORT" \
      --tls \
      --tls-protocol tlsv1_2 \
      --auth-user "$AUTH_USER" \
      --auth-password "$AUTH_PASS" \
      --header "Content-Type: text/html" \
      --header "Subject: $SUBJECT" \
      --header "X-250ok-CID: $BATCH_ID" \
      --body "$(cat "$Body_file")"
  fi
done < "$CSV_FILE"
