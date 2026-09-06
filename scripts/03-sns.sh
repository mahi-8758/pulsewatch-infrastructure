#!/bin/bash
set -e
source "$(dirname "$0")/../config/variables.sh"

echo "=== Phase 3: SES Alert Email Setup ==="
if [ -z "${ALERT_EMAIL:-}" ]; then
  echo "ALERT_EMAIL is missing. Set it first: export ALERT_EMAIL='your-email@example.com'"
  exit 1
fi
echo "Verifying SES email identity for sender: $ALERT_EMAIL"
aws ses verify-email-identity --email-address "$ALERT_EMAIL" >/dev/null
export SENDER_EMAIL="$ALERT_EMAIL"
echo "SENDER_EMAIL: $SENDER_EMAIL"
echo "Check inbox for SES verification link if this address is newly registered in SES Sandbox."
