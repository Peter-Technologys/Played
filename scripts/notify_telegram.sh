#!/usr/bin/env bash
# scripts/notify_telegram.sh
# Reusable helper: send a Telegram HTML message from any CI step or locally.
#
# Required env vars:
#   TELEGRAM_BOT_TOKEN  — bot token from @BotFather
#   TELEGRAM_CHAT_ID    — channel or group chat ID
#   TG_MESSAGE          — HTML-formatted message text
# Optional:
#   TG_DISABLE_PREVIEW  — set to "true" to disable link previews (default: true)

set -euo pipefail

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "INFO: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set — skipping."
  exit 0
fi

if [ -z "${TG_MESSAGE:-}" ]; then
  echo "ERROR: TG_MESSAGE is required."
  exit 1
fi

python3 - <<'PYEOF'
import os, urllib.request, urllib.parse, json
bot_token       = os.environ['TELEGRAM_BOT_TOKEN']
chat_id         = os.environ['TELEGRAM_CHAT_ID']
message         = os.environ['TG_MESSAGE']
disable_preview = os.environ.get('TG_DISABLE_PREVIEW', 'true').lower() == 'true'
data = urllib.parse.urlencode({
    'chat_id': chat_id, 'text': message,
    'parse_mode': 'HTML',
    'disable_web_page_preview': str(disable_preview).lower(),
}).encode()
req = urllib.request.Request(
    f'https://api.telegram.org/bot{bot_token}/sendMessage',
    data=data, method='POST'
)
try:
    with urllib.request.urlopen(req, timeout=15) as resp:
        result = json.load(resp)
        print('Telegram message sent, id:', result['result']['message_id'])
except Exception as e:
    print(f'WARNING: Telegram notification failed: {e}')
PYEOF
