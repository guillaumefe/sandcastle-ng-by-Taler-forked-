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

echo $GNUNET_HEAD > buildconfig/gnunet.tag
echo $EXCHANGE_HEAD > buildconfig/exchange.tag
echo $MERCHANT_HEAD > buildconfig/merchant.tag
echo $LIBEUFIN_HEAD > buildconfig/libeufin.tag
echo $MERCHANT_DEMOS_HEAD > buildconfig/merchant-demos.tag
echo $WALLET_HEAD > buildconfig/wallet.tag
echo $SYNC_HEAD > buildconfig/sync.tag
