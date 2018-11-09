import os

#Blocktrail API Key (used for lookups of utxo's)
BTAPIKEY = None

#Redis Connection Info
REDIS_HOST='omni_redis'
REDIS_PORT=6379
REDIS_DB=0

#How long, in seconds, to cache BTC balance info for new addresses, Default 10min (600)
BTCBAL_CACHE=600

# Set to True to switch to processing testnet

TESTNET = True if os.environ['NETWORK'] == 'testnet' else False
