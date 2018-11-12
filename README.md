# Omni explorer in Docker

  This is setup in docker-compose for omnicore  explorer. Several services are launched:
  * [Omnicore node](https://github.com/OmniLayer/omnicore)
  * [Omnicore api](https://github.com/OmniLayer/omniapi)
  * [Omnicore engine](https://github.com/OmniLayer/omniEngine)
  * [Omnicore explorer](https://github.com/OmniLayer/omniexplorer)
  * Redis
  * Postgres

## Prerequisite
 * docker 
 * docker-compose
 
 
## Install


```
git clone https://github.com/APshenkin/omnilayer-explorer-docker.git
cd omnilayer-explorer-docker
// edit configurations if you want
docker-compose build
docker-compose up -d
```

## Configuration
  Each service has own configuration (list are below)

### API configuration

 - ./api/bitcoin.conf - Setup credetials to your omnicore node
 - ./api/sql.conf - Setup credetials to your postgres instance


### Engine configuration

 - ./engine/bitcoin.conf - Setup credetials to your omnicore node
 - ./engine/sql.conf - Setup credetials to your postgres instance

ENV variables:
 - NETWORK - `testnet` or any other value. Depents on your omnicore node configuration
 - FLYWAY_PLACEHOLDERS_OMNIAPIPASSWORD - password for omni api postgres user
 - FLYWAY_PLACEHOLDERS_OMNIENGINEPASSWORD - password for omni engine postgres user
 - PGUSER - default postgres user
 - PGPASSWORD - password for default postgres user
 - PGHOST - postgres instance host
 - PGPORT - postgres instance port
 - OMNIDB_DATABASE - omni database name


### Explorer configuration
 - [./explorer/addDevMiddlewares.js](https://github.com/APshenkin/omnilayer-explorer-docker/blob/master/explorer/addDevMiddlewares.js#L36) - set target in proxy to your api instance 
 - [./explorer/constants.js](https://github.com/APshenkin/omnilayer-explorer-docker/blob/master/explorer/constants.js#L20)  - set change api url rule to your api instance

### Postgres configuration
ENV variables:
 - POSTGRES_PASSWORD - set postgres default password
 
### Known issues

#### Testnet
 - Error on inserting transaction `8dd6e8c1e39e86f1d398db74eeaba800e02c6fd1a1b9e7eb93ded2c63e538c6a`. The best option is to insert block 306337 manually
    ```sql
    INSERT INTO public.transactions (id, txhash, protocol, txdbserialnum, txtype, txversion, ecosystem, txrecvtime, txstate, txerrorcode, txblocknumber, txseqinblock) VALUES (615, '8dd6e8c1e39e86f1d398db74eeaba800e02c6fd1a1b9e7eb93ded2c63e538c6a', 'Omni', 2669984, 50, 0, 'Production', '2014-11-04 01:49:27', 'not valid', null, 306337, 1);
    INSERT INTO public.txjson (id, txdbserialnum, protocol, txdata) VALUES (615, 2669984, 'Omni', '{"fee": "0.00010000", "url": "null", "data": "null", "txid": "8dd6e8c1e39e86f1d398db74eeaba800e02c6fd1a1b9e7eb93ded2c63e538c6a", "type": "Create Property - Fixed", "block": 306337, "valid": false, "amount": "-92233720368", "ismine": false, "version": 0, "category": "errtok", "type_int": 50, "blockhash": "00000000106c69183fd63dc6605da8bd6e27ecd1222d66dd840568eaa668bfb4", "blocktime": 1415065767, "ecosystem": "test", "subcategory": "ErrToken", "propertyname": "errtok", "propertytype": "divisible", "confirmations": 1136602, "invalidreason": "Value out of range or zero", "sendingaddress": "mfaiZGBkY4mBqt3PHPD2qWgbaafGa7vR64", "positioninblock": 1}');
    INSERT INTO public.blocks (blocknumber, protocol, blocktime, version, blockhash, prevblock, merkleroot, bits, nonce, size, txcount) VALUES (306337, 'Bitcoin', '2011-11-04 01:49:27', 2, '00000000106c69183fd63dc6605da8bd6e27ecd1222d66dd840568eaa668bfb4', '000000000df29936b576570f9e9f3e1b22efed881921d713d02981c532130836', '90cc13fc0e0ce43120ca66be3e0a0e4c733d6dbae7645966e56605398abf98e3', '1d00ffff', 3792769728, 786, 3);
    INSERT INTO public.txstats (id, protocol, blocknumber, blocktime, txcount, blockcount) VALUES (306390, 'Omni', 306337, '2014-11-04 01:49:27', 14, 1);
    ```
 - Omni and Test Omni properties are not listed in property list. Best option to insert them manually
    ```sql
    INSERT INTO public.smartproperties (protocol, propertyid, issuer, ecosystem, createtxdbserialnum, lasttxdbserialnum, propertyname, propertytype, prevpropertyid, propertyserviceurl, propertycategory, propertysubcategory, propertydata, registrationdata, flags) VALUES ('Omni', 1, 'mpexoDuSkGGqvqrkrjiFng38QPkJQVFyqv', 'Production', 0, 0, 'Omni', 2, 0, null, '', '', '{"url": "http://www.omnilayer.org", "data": "Omni serve as the binding between Bitcoin, smart properties and contracts created on the Omni Layer.", "name": "Omni", "issuer": "mpexoDuSkGGqvqrkrjiFng38QPkJQVFyqv", "category": "N/A", "blocktime": 1377994675, "divisible": true, "propertyid": 1, "subcategory": "N/A", "totaltokens": "243522.54399773", "creationtxid": "0000000000000000000000000000000000000000000000000000000000000000", "fixedissuance": false, "managedissuance": false}', null, null);
    INSERT INTO public.smartproperties (protocol, propertyid, issuer, ecosystem, createtxdbserialnum, lasttxdbserialnum, propertyname, propertytype, prevpropertyid, propertyserviceurl, propertycategory, propertysubcategory, propertydata, registrationdata, flags) VALUES ('Omni', 2, 'mpexoDuSkGGqvqrkrjiFng38QPkJQVFyqv', 'Test', 0, 0, 'Test Omni', 2, 0, null, '', '', '{"url": "http://www.omnilayer.org", "data": "Test Omni serve as the binding between Bitcoin, smart properties and contracts created on the Omni Layer.", "name": "Test Omni", "issuer": "mpexoDuSkGGqvqrkrjiFng38QPkJQVFyqv", "category": "N/A", "blocktime": 1377994675, "divisible": true, "propertyid": 2, "subcategory": "N/A", "totaltokens": "188740.46001459", "creationtxid": "0000000000000000000000000000000000000000000000000000000000000000", "fixedissuance": false, "managedissuance": false}', null, null);
    ```


