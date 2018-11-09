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


