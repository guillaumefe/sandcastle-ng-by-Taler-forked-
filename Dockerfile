FROM docker.io/library/debian:bookworm AS base-system

# FIXMEs:
# - debian packages should be built with a nightly tag
# - the final image contains all build dependencies, this isn't really necessary
# - the final image contains -dev packages, not really necessary
# - GNUnet build dependencies are excessive, maybe we can just build the required libs?

RUN apt-get update && apt-get -y upgrade && apt-get --no-install-recommends install -y \
  autoconf \
  autopoint \
  build-essential \
  po-debconf \
  debhelper-compat \
  apt-utils \
  libtool \
  texinfo \
  libgcrypt-dev \
  libidn11-dev \
  zlib1g-dev \
  libunistring-dev \
  libjansson-dev \
  git \
  recutils \
  libsqlite3-dev \
  libpq-dev \
  libmicrohttpd-dev \
  libsodium-dev \
  libqrencode-dev \
  zip \
  unzip \
  jq \
  npm \
  openjdk-17-jre-headless \
  openjdk-17-jdk-headless \
  default-jre-headless \
  nano \
  procps \
  python3-jinja2 \
  python3-pip \
  python3-sphinx \
  python3-sphinx-rtd-theme \
  python3-venv \
  python3-dev \
  nodejs \
  iptables \
  miniupnpc \
  libextractor-dev \
  libbluetooth-dev \
  libcurl4-gnutls-dev \
  libogg-dev \
  libopus-dev \
  libpulse-dev \
  fakeroot \
  libzbar-dev \
  libltdl-dev \
  net-tools \
  python3-flask \
  python3-flask-babel \
  uwsgi \
  python3-bs4 \
  pybuild-plugin-pyproject

# old: libzbar-dev

# FIXME: Try to use debian packages where possible and otherwise really use
# a venv or per-user installation of the package.
RUN pip3 install --break-system-packages requests click poetry uwsgi htmlark sphinx-book-theme

# GNUnet
FROM base-system AS gnunet

COPY buildconfig/gnunet.tag /buildconfig/
WORKDIR /build
RUN TAG=$(cat /buildconfig/gnunet.tag) && \
  git clone git://git.gnunet.org/gnunet \
  --branch $TAG
WORKDIR /build/gnunet
RUN ./bootstrap
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/gnunet
RUN mv /build/*.deb /packages/gnunet
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/gnunet/*.deb
WORKDIR /

# Exchange
FROM gnunet as exchange

COPY buildconfig/exchange.tag /buildconfig/
WORKDIR /build
RUN TAG=$(cat /buildconfig/exchange.tag) && \
  git clone git://git.taler.net/exchange \
  --branch $TAG
WORKDIR /build/exchange
RUN ./bootstrap
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/exchange
RUN mv /build/*.deb /packages/exchange
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/exchange/*.deb
WORKDIR /

# Merchant
FROM exchange as merchant

COPY buildconfig/merchant.tag /buildconfig/
WORKDIR /build
RUN TAG=$(cat /buildconfig/merchant.tag) && \
  git clone git://git.taler.net/merchant \
  --branch $TAG
WORKDIR /build/merchant
RUN ./bootstrap
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/merchant
RUN mv /build/*.deb /packages/merchant
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/merchant/*.deb
WORKDIR /

# Libeufin
FROM base-system as libeufin

WORKDIR /build
COPY buildconfig/libeufin.tag /buildconfig/
RUN TAG=$(cat /buildconfig/libeufin.tag) && \
  git clone git://git.taler.net/libeufin \
  --branch $TAG
WORKDIR /build/libeufin
RUN ./bootstrap
RUN ./configure --prefix=/usr
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/libeufin
RUN mv /build/*.deb /packages/libeufin
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/libeufin/*.deb

# Merchant demos
FROM base-system as merchant-demos

WORKDIR /build
COPY buildconfig/merchant-demos.tag /buildconfig/
RUN TAG=$(cat /buildconfig/merchant-demos.tag) && \
  git clone git://git.taler.net/taler-merchant-demos \
  --branch $TAG
WORKDIR /build/taler-merchant-demos
RUN ./bootstrap
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/merchant-demos
RUN mv /build/*.deb /packages/merchant-demos
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/merchant-demos/*.deb

# wallet-core tools (taler-wallet-cli and taler-harness)
FROM base-system as wallet
WORKDIR /build
COPY buildconfig/wallet.tag /buildconfig/
RUN TAG=$(cat /buildconfig/wallet.tag) && \
  git clone git://git.taler.net/wallet-core \
  --branch $TAG
RUN npm install -g pnpm@^8.7.0
WORKDIR /build/wallet-core
RUN ./bootstrap
# taler-wallet-cli
WORKDIR /build/wallet-core/packages/taler-wallet-cli
RUN ./configure --prefix=/usr/local
RUN make deps
RUN dpkg-buildpackage -rfakeroot -b -uc -us
# taler-harness
WORKDIR /build/wallet-core/packages/taler-harness
RUN ./configure --prefix=/usr/local
RUN pnpm install --frozen-lockfile --filter @gnu-taler/taler-harness...
RUN pnpm run --filter @gnu-taler/taler-harness... compile
RUN dpkg-buildpackage -rfakeroot -b -uc -us
# copy debs
WORKDIR /
RUN mkdir -p /packages/wallet
RUN mv /build/wallet-core/packages/*.deb /packages/wallet
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/wallet/*.deb

# Sync
FROM merchant as sync
COPY buildconfig/sync.tag /buildconfig/
WORKDIR /build
RUN TAG=$(cat /buildconfig/sync.tag) && \
  git clone git://git.taler.net/sync \
  --branch $TAG
WORKDIR /build/sync
RUN ./bootstrap
RUN dpkg-buildpackage -rfakeroot -b -uc -us
WORKDIR /
RUN mkdir -p /packages/sync
RUN mv /build/*.deb /packages/sync
RUN rm -rf /build
RUN apt-get install --no-install-recommends -y /packages/sync/*.deb
WORKDIR /


# Final image
FROM base-system as taler-final
RUN apt-get update && apt-get -y upgrade && apt-get --no-install-recommends install -y \
  gpg
COPY apt/caddy-stable.list /etc/apt/sources.list.d/caddy-stable.list
COPY apt/caddy-stable-archive-keyring.gpg /tmp/caddy-stable-archive-keyring.gpg
RUN gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg /tmp/caddy-stable-archive-keyring.gpg
RUN apt-get update && apt-get -y upgrade && apt-get --no-install-recommends install -y \
  emacs \
  vim \
  curl \
  postgresql \
  bash-completion \
  sudo \
  less \
  caddy \
  systemd-coredump \
  libnss3-tools \
  latexmk \
  texlive-latex-extra \
  tex-gyre
RUN mkdir -p /packages
COPY --from=gnunet /packages/gnunet/* /packages/
COPY --from=exchange /packages/exchange/* /packages/
COPY --from=merchant /packages/merchant/* /packages/
COPY --from=wallet /packages/wallet/* /packages/
COPY --from=libeufin /packages/libeufin/* /packages/
COPY --from=merchant-demos /packages/merchant-demos/* /packages/
RUN apt-get install --no-install-recommends -y /packages/*.deb
COPY systemd/setup-sandcastle.service /etc/systemd/system/
RUN systemctl enable setup-sandcastle.service
# Disable potentially problem-causing services
RUN systemctl disable postgresql && \
    systemctl disable apache2 || true
