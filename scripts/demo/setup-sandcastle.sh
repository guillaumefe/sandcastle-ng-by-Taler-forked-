#!/usr/bin/env bash

# This scripts provisions all configuration and
# services for the Taler sandcastle container.
#
# Important: This script needs to be completely
# idempotent, nothing must break if it is executed
# multiple times.

set -eu
set -x

if [[ ! -z "${SANDCASTLE_SKIP_SETUP:-}" ]]; then
  echo "skipping sandcastle setup, requested by environment var SANDCASTLE_SKIP_SETUP"
  exit 1
fi

echo "Provisioning sandcastle"

# General configuration.
# Might eventually be moved to an external file.

# Source any ovverrides from external file
if [[ "${SANDCASTLE_OVERRIDE_NAME:-}" != "none" ]]; then
	cat /overrides
	source "/overrides" || true
fi
CURRENCY=${CURRENCY:="KUDOS"}
EXCHANGE_IBAN=DE159593
EXCHANGE_PLAIN_PAYTO=payto://iban/$EXCHANGE_IBAN
EXCHANGE_FULL_PAYTO="payto://iban/$EXCHANGE_IBAN?receiver-name=Sandcastle+Echange+Inc"
EXCHANGE_BANK_PASSWORD=sandbox

# Randomly generated IBANs for the merchants
MERCHANT_IBAN_DEFAULT=DE5135717
MERCHANT_IBAN_POS=DE4218710
MERCHANT_IBAN_BLOG=DE8292195
MERCHANT_IBAN_GNUNET=DE9709960
MERCHANT_IBAN_TALER=DE1740597
MERCHANT_IBAN_TOR=DE2648777
MERCHANT_IBAN_SURVEY=DE0793060

MYDOMAIN=${MYDOMAIN:="demo.taler.net"}
LANDING_DOMAIN=$MYDOMAIN
BANK_DOMAIN=bank.$MYDOMAIN
EXCHANGE_DOMAIN=exchange.$MYDOMAIN
MERCHANT_DOMAIN=backend.$MYDOMAIN
BLOG_DOMAIN=shop.$MYDOMAIN
DONATIONS_DOMAIN=donations.$MYDOMAIN
SURVEY_DOMAIN=survey.$MYDOMAIN

# Ports of the services running inside the container.
# Should be synchronized with the sandcastle-run script.
PORT_INTERNAL_EXCHANGE=8201
PORT_INTERNAL_MERCHANT=8301
PORT_INTERNAL_LIBEUFIN_BANK=8080
PORT_INTERNAL_LANDING=8501
PORT_INTERNAL_BLOG=8502
PORT_INTERNAL_DONATIONS=8503
PORT_INTERNAL_SURVEY=8504
PORT_INTERNAL_BANK_SPA=8505

# Just make sure the services are stopped
systemctl stop taler-exchange.target
systemctl stop taler-merchant-httpd.service
systemctl stop postgresql.service
systemctl stop taler-demo-landing.service
systemctl stop taler-demo-blog.service
systemctl stop taler-demo-donations.service
systemctl stop taler-demo-survey.service
systemctl stop libeufin-bank.service

# We now make sure that some important locations are symlinked to
# the persistent storage volume.
# Files that already exist in this location are moved to the storage volume
# and then symlinked.
# These locations are:
# /etc/taler
# /etc/libeufin
# /var/lib/taler
# postgres DB directory

function lift_dir() {
  src=$1
  target=$2
  if [[ -L "$src" ]]; then
    # be idempotent
    echo "$src is already a symlink"
  elif [[ -d /talerdata/$target ]]; then
    echo "symlinking existing /talerdata/$target"
    rm -rf "$src"
    ln -s "/talerdata/$target" "$src"
  else
    echo "symlinking new /talerdata/$target"
    mv "$src" "/talerdata/$target"
    ln -s "/talerdata/$target" "$src"
  fi
}

lift_dir /var/lib/taler var-lib-taler
lift_dir /etc/taler etc-taler
lift_dir /etc/libeufin etc-libeufin
lift_dir /var/lib/postgresql var-lib-postgresql

# Caddy configuration.
# We use the caddy reverse proxy with automatic
# internal TLS setup to ensure that the services are
# reachable inside the container without any external
# DNS setup under the same domain name and with TLS
# from inside the container.

systemctl stop caddy.service

cat <<EOF > /etc/caddy/Caddyfile
https://$BANK_DOMAIN {
  tls internal
  reverse_proxy :8080 {
    # libeufin-bank should eventually not require this anymore,
    # but currently doesn't work without this header.
    header_up X-Forwarded-Prefix ""
  }
}

https://$EXCHANGE_DOMAIN {
  tls internal
  reverse_proxy unix//run/taler/exchange-httpd/exchange-http.sock
}

https://$MERCHANT_DOMAIN {
  tls internal
  reverse_proxy unix//run/taler/merchant-httpd/merchant-http.sock
}

# Services that only listen on unix domain sockets
# are reverse-proxied to serve on a TCP port.

:$PORT_INTERNAL_EXCHANGE {
  reverse_proxy unix//run/taler/exchange-httpd/exchange-http.sock
}

:$PORT_INTERNAL_MERCHANT {
  reverse_proxy unix//run/taler/merchant-httpd/merchant-http.sock {
    # Set this, or otherwise wrong taler://pay URIs will be generated.
    header_up X-Forwarded-Proto "https"
  }
}

:$PORT_INTERNAL_BANK_SPA {
  root * /usr/share/libeufin/spa
  root /settings.json /etc/libeufin/
  file_server
}
EOF

cat <<EOF >> /etc/hosts
# Start of Taler Sandcastle Domains
127.0.0.1 $LANDING_DOMAIN
127.0.0.1 $BANK_DOMAIN
127.0.0.1 $EXCHANGE_DOMAIN
127.0.0.1 $MERCHANT_DOMAIN
127.0.0.1 $BLOG_DOMAIN
127.0.0.1 $DONATIONS_DOMAIN
127.0.0.1 $SURVEY_DOMAIN
# End of Taler Sandcastle Domains
EOF

systemctl start caddy.service

# Install local, internal CA certs for caddy
caddy trust

systemctl start postgresql.service

# Set up bank


# FIXME: user libeufin-dbconf instead of manual setup

BANK_DB=libeufinbank
# Use "|| true" to continue if these already exist.
sudo -i -u postgres createuser -d libeufin-bank || true
sudo -i -u postgres createdb -O libeufin-bank $BANK_DB || true

cat <<EOF >/etc/libeufin/libeufin-bank.conf
[libeufin-bankdb-postgres]
# DB connection string
CONFIG = postgresql:///$BANK_DB

[libeufin-bank]
CURRENCY = $CURRENCY
DEFAULT_DEBT_LIMIT = $CURRENCY:500
REGISTRATION_BONUS = $CURRENCY:100
SPA_CAPTCHA_URL = https://$BANK_DOMAIN/webui/#/operation/{woid}
SUGGESTED_WITHDRAWAL_EXCHANGE = https://$EXCHANGE_DOMAIN/
ALLOW_REGISTRATION = yes
SERVE = tcp
PORT = 8080

[currency-$CURRENCY]
ENABLED = YES
name = "$CURRENCY (Taler Demonstrator)"
code = "$CURRENCY"
decimal_separator = "."
fractional_input_digits = 2
fractional_normal_digits = 2
fractional_trailing_zero_digits = 2
is_currency_name_leading = NO
alt_unit_names = {"0":"$CURRENCY"}
EOF

cat <<EOF >/etc/libeufin/settings.json
{
  "topNavSites": {
    "Landing": "https://$LANDING_DOMAIN/",
    "Bank": "https://$BANK_DOMAIN",
    "Essay Shop": "https://$BLOG_DOMAIN",
    "Donations": "https://$DONATIONS_DOMAIN",
    "Survey": "https://$SURVEY_DOMAIN"
  }
}
EOF

sudo -i -u libeufin-bank libeufin-bank dbinit

systemctl enable --now libeufin-bank.service

taler-harness deployment wait-taler-service libeufin-bank https://$BANK_DOMAIN/config

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login exchange --exchange --public \
  --payto $EXCHANGE_PLAIN_PAYTO \
  --name Exchange \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-default --public \
  --payto "payto://iban/$MERCHANT_IBAN_DEFAULT" \
  --name "Default Demo Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-pos --public \
  --payto "payto://iban/$MERCHANT_IBAN_POS" \
  --name "PoS Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-blog --public \
  --payto "payto://iban/$MERCHANT_IBAN_BLOG" \
  --name "Blog Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-gnunet --public \
  --payto "payto://iban/$MERCHANT_IBAN_GNUNET" \
  --name "GNUnet Donations Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-taler --public \
  --payto "payto://iban/$MERCHANT_IBAN_TALER" \
  --name "Taler Donations Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-tor --public \
  --payto "payto://iban/$MERCHANT_IBAN_TOR" \
  --name "Tor Donations Merchant" \
  --password sandbox

taler-harness deployment provision-bank-account https://$BANK_DOMAIN/ \
  --login merchant-survey --public \
  --payto "payto://iban/$MERCHANT_IBAN_SURVEY" \
  --name "Tor Survey Merchant" \
  --password sandbox

sudo -i -u libeufin-bank libeufin-bank edit-account admin --debit_threshold=$CURRENCY:1000000
sudo -i -u libeufin-bank libeufin-bank passwd admin sandbox

# Set up exchange

MASTER_PUBLIC_KEY=$(sudo -i -u taler-exchange-offline taler-exchange-offline -LDEBUG setup)

EXCHANGE_DB=talerexchange
# Use "|| true" to continue if these already exist.
sudo -i -u postgres createuser -d taler-exchange-httpd || true
sudo -i -u postgres createuser taler-exchange-wire || true
sudo -i -u postgres createuser taler-exchange-closer || true
sudo -i -u postgres createuser taler-exchange-aggregator || true
sudo -i -u postgres createdb -O taler-exchange-httpd $EXCHANGE_DB || true

# Generate /etc/taler/conf.d/setup.conf
cat <<EOF > /etc/taler/conf.d/setup.conf
[taler]
CURRENCY = $CURRENCY
CURRENCY_ROUND_UNIT = $CURRENCY:0.01

[currency-$CURRENCY]
ENABLED = YES
name = "$CURRENCY (Taler Demonstrator)"
code = "$CURRENCY"
decimal_separator = "."
fractional_input_digits = 2
fractional_normal_digits = 2
fractional_trailing_zero_digits = 2
is_currency_name_leading = NO
alt_unit_names = {"0":"$CURRENCY"}

[exchange]
AML_THRESHOLD = $CURRENCY:1000000
MASTER_PUBLIC_KEY = $MASTER_PUBLIC_KEY
BASE_URL = https://$EXCHANGE_DOMAIN/

[exchange-account-default]
PAYTO_URI = $EXCHANGE_FULL_PAYTO
ENABLE_DEBIT = YES
ENABLE_CREDIT = YES
@inline-secret@ exchange-accountcredentials-default ../secrets/exchange-accountcredentials-default.secret.conf
EOF

cat <<EOF >/etc/taler/secrets/exchange-db.secret.conf
[exchangedb-postgres]
CONFIG=postgres:///${EXCHANGE_DB}
EOF
chmod 440 /etc/taler/secrets/exchange-db.secret.conf
chown root:taler-exchange-db /etc/taler/secrets/exchange-db.secret.conf

cat <<EOF > /etc/taler/secrets/exchange-accountcredentials-default.secret.conf
[exchange-accountcredentials-default]
WIRE_GATEWAY_URL = https://$BANK_DOMAIN/accounts/exchange/taler-wire-gateway/
WIRE_GATEWAY_AUTH_METHOD = basic
USERNAME = exchange
PASSWORD = ${EXCHANGE_BANK_PASSWORD}
EOF
chmod 400 /etc/taler/secrets/exchange-accountcredentials-default.secret.conf
chown taler-exchange-wire:taler-exchange-db /etc/taler/secrets/exchange-accountcredentials-default.secret.conf

if [[ ! -e /etc/taler/conf.d/$CURRENCY-coins.conf ]]; then
  # Only create if necessary, as each [COIN-...] section
  # has a unique name with a timestamp.
  taler-harness deployment gen-coin-config \
    --min-amount "${CURRENCY}:0.01" \
    --max-amount "${CURRENCY}:100" \
      >"/etc/taler/conf.d/$CURRENCY-coins.conf"
fi

echo "Initializing exchange database"
sudo -u taler-exchange-httpd taler-exchange-dbinit -LDEBUG -c /etc/taler/taler.conf

echo 'GRANT USAGE ON SCHEMA exchange TO "taler-exchange-wire";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA exchange TO "taler-exchange-wire";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT USAGE ON SCHEMA _v TO "taler-exchange-wire";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT ON ALL TABLES IN SCHEMA _v TO "taler-exchange-wire";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}

echo 'GRANT USAGE ON SCHEMA exchange TO "taler-exchange-closer";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA exchange TO "taler-exchange-closer";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT USAGE ON SCHEMA _v TO "taler-exchange-closer";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT ON ALL TABLES IN SCHEMA _v TO "taler-exchange-closer";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}

echo 'GRANT USAGE ON SCHEMA exchange TO "taler-exchange-aggregator";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA exchange TO "taler-exchange-aggregator";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT USAGE ON SCHEMA _v TO "taler-exchange-aggregator";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}
echo 'GRANT SELECT ON ALL TABLES IN SCHEMA _v TO "taler-exchange-aggregator";' | sudo -i -u postgres psql -f - ${EXCHANGE_DB}


taler-terms-generator -i /usr/share/taler/terms/exchange-tos-v0
taler-terms-generator -i /usr/share/taler/terms/exchange-pp-v0

systemctl enable --now taler-exchange.target

taler-harness deployment wait-taler-service taler-exchange https://$EXCHANGE_DOMAIN/config
taler-harness deployment wait-endpoint https://$EXCHANGE_DOMAIN/management/keys

sudo -i -u taler-exchange-offline \
  taler-exchange-offline \
  -c /etc/taler/taler.conf \
  download \
  sign \
  upload

sudo -i -u taler-exchange-offline \
  taler-exchange-offline \
  enable-account "${EXCHANGE_FULL_PAYTO}" \
  wire-fee now iban "${CURRENCY}":0 "${CURRENCY}":0 \
  global-fee now "${CURRENCY}":0 "${CURRENCY}":0 "${CURRENCY}":0 1h 6a 0 \
  upload

# Set up merchant backend

MERCHANT_DB=talermerchant
# Use "|| true" to continue if these already exist.
sudo -i -u postgres createuser -d taler-merchant-httpd || true
sudo -i -u postgres createdb -O taler-merchant-httpd $MERCHANT_DB || true

cat <<EOF >/etc/taler/secrets/merchant-db.secret.conf
[merchantdb-postgres]
CONFIG=postgres:///${MERCHANT_DB}
EOF
chmod 440 /etc/taler/secrets/merchant-db.secret.conf
chown taler-merchant-httpd:root /etc/taler/secrets/merchant-db.secret.conf

sudo -u taler-merchant-httpd taler-merchant-dbinit -c /etc/taler/taler.conf

# The config shipped with the package can conflict with the
# trusted sandcastle exchange if the currency is KUDOS.
rm /usr/share/taler/config.d/kudos.conf

cat <<EOF >/etc/taler/conf.d/merchant-exchanges.conf
[merchant-exchange-sandcastle]
EXCHANGE_BASE_URL = https://$EXCHANGE_DOMAIN/
MASTER_KEY = $MASTER_PUBLIC_KEY
CURRENCY = $CURRENCY
EOF

systemctl enable --now taler-merchant-httpd
taler-harness deployment wait-taler-service taler-merchant https://$MERCHANT_DOMAIN/config

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name Merchant \
  --id default \
  --payto "payto://iban/$MERCHANT_IBAN_DEFAULT?receiver-name=Merchant"

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name "POS Merchant" \
  --id pos \
  --payto "payto://iban/$MERCHANT_IBAN_POS?receiver-name=POS+Merchant"

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name "Blog Merchant" \
  --id blog \
  --payto "payto://iban/$MERCHANT_IBAN_BLOG?receiver-name=Blog+Merchant"

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name "GNUnet Merchant" \
  --id gnunet \
  --payto "payto://iban/$MERCHANT_IBAN_GNUNET?receiver-name=GNUnet+Merchant"

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name "Taler Merchant" \
  --id taler \
  --payto "payto://iban/$MERCHANT_IBAN_TALER?receiver-name=Taler+Merchant"

taler-harness deployment provision-merchant-instance \
  https://$MERCHANT_DOMAIN/ \
  --management-token secret-token:sandbox \
  --instance-token secret-token:sandbox \
  --name "Tor Merchant" \
  --id tor \
  --payto "payto://iban/$MERCHANT_IBAN_TOR?receiver-name=Tor+Merchant"


# Now we set up the taler-merchant-demos

cat <<EOF >/etc/taler/taler-merchant-frontends.conf
# Different entry point, we need to repeat some settings.
# In the future, taler-merchant-demos should become
# robust enough to read from the main config.
[taler]
CURRENCY = $CURRENCY
[frontends]
BACKEND = https://$MERCHANT_DOMAIN/
BACKEND_APIKEY = secret-token:sandbox
[landing]
SERVE = http
HTTP_PORT = $PORT_INTERNAL_LANDING
[blog]
SERVE = http
HTTP_PORT = $PORT_INTERNAL_BLOG
[donations]
SERVE = http
HTTP_PORT = $PORT_INTERNAL_DONATIONS
[survey]
SERVE = http
HTTP_PORT = $PORT_INTERNAL_SURVEY
EOF

# This really should not exist, the taler-merchant-frontends
# should be easier to configure!
cat <<EOF >/etc/taler/taler-merchant-frontends.env
TALER_ENV_URL_INTRO=https://$LANDING_DOMAIN/
TALER_ENV_URL_LANDING=https://$LANDING_DOMAIN/
TALER_ENV_URL_BANK=https://$BANK_DOMAIN/
TALER_ENV_URL_MERCHANT_BLOG=https://$BLOG_DOMAIN/
TALER_ENV_URL_MERCHANT_DONATIONS=https://$DONATIONS_DOMAIN/
TALER_ENV_URL_MERCHANT_SURVEY=https://$SURVEY_DOMAIN/
EOF

systemctl enable --now taler-demo-landing
systemctl enable --now taler-demo-blog
systemctl enable --now taler-demo-donations
systemctl enable --now taler-demo-survey


# FIXME: Maybe do some taler-wallet-cli test?
# FIXME: How do we report errors occurring during the setup script?
