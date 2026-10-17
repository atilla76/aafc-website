#!/usr/bin/env bash
# AAFC — ÜTS + İTS relay setup (safe to re-run; keeps its key) (Ubuntu 24.04). Forwards AAFC's ÜTS notifications from a fixed Turkish IP.
# Holds no patient data and no secrets in this file: the relay key is fetched once from AAFC,
# which hands it out only to the registered relay IP.
set -euo pipefail
HOST="uts.aafclinic.com"
ENROLL="https://hugxacklprzujswtaike.supabase.co/functions/v1/uts-relay-enroll"

echo "== AAFC ÜTS relay setup =="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ufw debian-keyring debian-archive-keyring apt-transport-https gnupg unattended-upgrades

# Caddy (HTTPS with automatic Let's Encrypt certificate)
if ! command -v caddy >/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -y
  apt-get install -y caddy
fi

# relay key: keep the existing one on re-runs, otherwise fetch it once
KEY=""
if [ -f /etc/caddy/Caddyfile ]; then
  KEY="$(sed -n 's/.*X-Relay-Key "\([0-9a-f]\{64\}\)".*/\1/p' /etc/caddy/Caddyfile | head -1)"
fi
if [ -z "$KEY" ]; then
  RESP="$(curl -sS -X POST "$ENROLL")"
  KEY="$(printf '%s' "$RESP" | sed -n 's/.*"key":"\([0-9a-f]\{64\}\)".*/\1/p')"
fi
if [ -z "$KEY" ]; then
  echo "!! Relay key could not be fetched: $RESP"
  exit 1
fi

cat > /etc/caddy/Caddyfile <<EOF
{
	email support@aafclinic.com
}

$HOST {
	@auth header X-Relay-Key "$KEY"
	handle @auth {
		handle /ping {
			respond "ok" 200
		}
		handle_path /test/* {
			reverse_proxy https://utstest.saglik.gov.tr {
				header_up Host utstest.saglik.gov.tr
				header_up -X-Relay-Key
				header_up -X-Forwarded-For
			}
		}
		handle_path /its-test/* {
			reverse_proxy https://itstest2.saglik.gov.tr {
				header_up Host itstest2.saglik.gov.tr
				header_up -X-Relay-Key
				header_up -X-Forwarded-For
			}
		}
		handle_path /its/* {
			reverse_proxy https://its2.saglik.gov.tr {
				header_up Host its2.saglik.gov.tr
				header_up -X-Relay-Key
				header_up -X-Forwarded-For
			}
		}
		handle_path /prod/* {
			reverse_proxy https://utsuygulama.saglik.gov.tr {
				header_up Host utsuygulama.saglik.gov.tr
				header_up -X-Relay-Key
				header_up -X-Forwarded-For
			}
		}
	}
	respond 403
	log {
		output discard
	}
}
EOF
chown root:caddy /etc/caddy/Caddyfile
chmod 640 /etc/caddy/Caddyfile

# firewall: SSH + web only
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

systemctl enable caddy
systemctl restart caddy
dpkg-reconfigure -f noninteractive unattended-upgrades || true

echo
echo "== Bitti. Kurulum tamamlandi (AAFC UTS relay ready). =="
