#!/bin/bash
set -ex

fetch_head() {
	git ls-remote -q -h "${1}" master | cut -f1
}

GNUNET_HEAD=$(fetch_head "git://git.gnunet.org/gnunet")
EXCHANGE_HEAD=$(fetch_head "git://git.taler.net/exchange")
MERCHANT_HEAD=$(fetch_head "git://git.taler.net/merchant")
LIBEUFIN_HEAD=$(fetch_head "git://git.taler.net/libeufin")
MERCHANT_DEMOS_HEAD=$(fetch_head "git://git.taler.net/taler-merchant-demos")
WALLET_HEAD=$(fetch_head "git://git.taler.net/wallet-core")
SYNC_HEAD=$(fetch_head "git://git.taler.net/sync")

echo "master" > buildconfig/gnunet.tag
echo "master" > buildconfig/exchange.tag
echo "master" > buildconfig/merchant.tag
echo "master" > buildconfig/libeufin.tag
echo "master" > buildconfig/merchant-demos.tag
echo "master" > buildconfig/wallet.tag
echo "master" > buildconfig/sync.tag

rm -f buildconfig/*.checkout
echo $GNUNET_HEAD > buildconfig/gnunet.checkout
echo $EXCHANGE_HEAD > buildconfig/exchange.checkout
echo $MERCHANT_HEAD > buildconfig/merchant.checkout
echo $LIBEUFIN_HEAD > buildconfig/libeufin.checkout
echo $MERCHANT_DEMOS_HEAD > buildconfig/merchant-demos.checkout
echo $WALLET_HEAD > buildconfig/wallet.checkout
echo $SYNC_HEAD > buildconfig/sync.checkout
