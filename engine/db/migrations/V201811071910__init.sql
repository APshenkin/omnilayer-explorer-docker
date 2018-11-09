/*
 * "omniwallet" schema
 *
 * The database name is no longer contained in this SQL script.
 * You'll need to specify it on the command-line or with whatever tool you're using to connect.
 */

/*
 * Notes:
 * 1. Need to define Cascade/Restrict behavior for foreign keys to maintain referential integrity
 * 2. Need to define & flesh out dictionary tables
 * 3. Need to identify tables & indexes for administrative purposes, e.g. analytics
 *
 * All token amounts are stored as 19 digit integers - numeric(19). The PropertyType indicates if the
 * currency (or smart property) is divisible or indivisible.
 */

/*
 * AddressRole type definitions:
 *	buyer accepted a DEx sell offer
 *	issuer created a smart property
 *	participant is an investor in a crowdsale
 *	payee received a Send to Owners amount
 *	recipient received a Simple Send
 *	seller created a DEx sell offer
 *	sender sent a Simple Send
 */
CREATE TYPE ADDRESSROLE AS ENUM ('buyer', 'issuer', 'participant', 'payee', 'recipient', 'seller', 'sender', 'payer', 'feepayer');
CREATE TYPE PROTOCOL AS ENUM ('Fiat', 'Bitcoin', 'Omni');
CREATE TYPE ECOSYSTEM AS ENUM ('Production', 'Test');
CREATE TYPE OBJECTTYPE AS ENUM ('address', 'property', 'tx_version_type');
CREATE TYPE TXSTATE AS ENUM ('pending', 'valid', 'not valid');
CREATE TYPE WALLETSTATE AS ENUM ('Active', 'Inactive', 'Suspended');
CREATE TYPE DEXSTATE AS ENUM ('invalid', 'unpaid', 'paid-partial', 'paid-complete');
CREATE TYPE OFFERSTATE AS ENUM ('active', 'cancelled', 'replaced', 'sold');

CREATE TABLE IF NOT EXISTS sessions (
  sessionid  TEXT NOT NULL,
  challenge  TEXT,
  pchallenge TEXT,
  pubkey     TEXT,
  timestamp  TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
  PRIMARY KEY (sessionid)
);

/* Wallets have addresses with private keys. Objects being watched are in the Following table */
CREATE TABLE IF NOT EXISTS wallets (
  walletid        UUID,
  created         TIMESTAMP(0) NULL,
  lastlogin       TIMESTAMP(0) NULL,
  lastbackup      TIMESTAMP(0) NULL,
  issignedin      BOOLEAN      NOT NULL DEFAULT FALSE,                /* signed in now? */
  walletstate     WALLETSTATE  NOT NULL DEFAULT 'Active',
  walletstatedate TIMESTAMP(0) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  walletblob      TEXT         NULL,                                  /* encrypted w/ wallet password */
  username        VARCHAR(32)  NULL,                                  /* (future) encrypted */
  email           VARCHAR(64)  NULL,                                  /* (future) encrypted */
  settings        JSON         NULL,                                  /* (future) user preferences */
  PRIMARY KEY (walletid)
);

/* Timestamped backup of wallets everytime they are modified/changed */
CREATE TABLE IF NOT EXISTS walletbackups (
  walletid   UUID        NOT NULL,
  created    TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT now(),
  walletblob TEXT        NOT NULL,
  username   VARCHAR(32) NULL,
  email      VARCHAR(64) NULL,
  settings   JSON        NULL,
  id         SERIAL,
  PRIMARY KEY (id)
);

/*
 * Balances for each PropertyID (currency) owned by an Address
 * for all addresses we know about, even if they're not in a wallet
 */
CREATE TABLE IF NOT EXISTS addressbalances (
  address           VARCHAR(64),                              /* Bitcoin addresses are 34 chars */
  protocol          PROTOCOL    NOT NULL DEFAULT 'Bitcoin',   /* initially 'Bitcoin' or 'Omni' */
  propertyid        BIGINT      NOT NULL DEFAULT 0,           /* Bitcoin */
  ecosystem         ECOSYSTEM   NULL,
  balanceavailable  NUMERIC(19) NOT NULL DEFAULT 0,
  balancereserved   NUMERIC(19) NOT NULL DEFAULT 0,
  balanceaccepted   NUMERIC(19) NOT NULL DEFAULT 0,
  balancefrozen     NUMERIC(19) NOT NULL DEFAULT 0,
  lasttxdbserialnum INT8        NULL,                         /* last tx that affected this currency for this address, null if no tx's */
  PRIMARY KEY (address, protocol, propertyid)
);

/* to get balance list by pid */
CREATE INDEX ab_nonzero
  ON addressbalances (balanceavailable, balancereserved, balancefrozen, address) WHERE (balanceavailable > 0 OR balancereserved > 0 OR
                                                                                        balancefrozen > 0);

/*
 * Stats for each address we've seen
 */
CREATE TABLE IF NOT EXISTS addressstats (
  id                SERIAL,
  address           VARCHAR(64)                    NOT NULL,                        /* Bitcoin addresses are 34 chars */
  protocol          PROTOCOL                       NOT NULL DEFAULT 'Omni',         /* initially 'Bitcoin' or 'Omni' */
  txcount           NUMERIC(19)                    NOT NULL DEFAULT 0,              /* Count of txs address is involved in */
  lasttxdbserialnum INT8                           NOT NULL DEFAULT 0,              /* last tx that affected this currency for this address, null if no tx's */
  blocknumber       INTEGER                        NOT NULL,                        /* Last block address was seen in */
  lastupdate        TIMESTAMP(0) WITHOUT TIME ZONE NULL     DEFAULT now(),          /* last timestamp updated */
  PRIMARY KEY (id, address, protocol),
  UNIQUE (address, protocol)
);

/* Addresses with private keys owned by each Wallet. See Following table for objects watched by a wallet. */
CREATE TABLE IF NOT EXISTS addressesinwallets (		                                  /* many-to-many */
    address VARCHAR(64) NOT NULL,		                                                /* Address must exist in the AddressBalances table */
    walletid UUID	NOT NULL,		                                                      /* WalletID must exist in the Wallets table */
    protocol          PROTOCOL    NOT NULL DEFAULT 'Bitcoin',                       /* initially 'Bitcoin' or 'Omni' */
    propertyid        BIGINT      NOT NULL DEFAULT 0,                               /* Bitcoin */
    PRIMARY KEY (walletid, address),
    FOREIGN KEY (walletid) REFERENCES wallets ON DELETE CASCADE ON UPDATE CASCADE, 	/* del/upd rows here if corresponding row is deleted/updated */
  FOREIGN KEY (address, protocol, propertyid) REFERENCES addressbalances
);

/* to find the wallets that have a particular address. */
CREATE INDEX addressindex ON addressesinwallets (address, protocol, propertyid);

/* block header information, from https://en.bitcoin.it/wiki/Protocol_specification & getblock RPC JSON */
CREATE TABLE IF NOT EXISTS blocks (
  blocknumber INTEGER      NOT NULL,
  protocol    PROTOCOL     NOT NULL,    /* initially 'Bitcoin' */
  blocktime   TIMESTAMP(0) NOT NULL,    /* timestamp recording when this block was created (Will overflow in 2106) */
  version     INTEGER      NULL,        /* Block version information, based upon the software version creating this block */
  blockhash   VARCHAR(64)  NULL,
  prevblock   VARCHAR(64)  NULL,        /* hash value of the previous block this block references */
  merkleroot  VARCHAR(64)  NULL,        /* reference to a Merkle tree collection which is a hash of all transactions related to this block */
  bits        BYTEA        NULL,        /* The calculated difficulty target being used for this block */
  nonce       BIGINT       NULL,        /* The nonce used to generate this block… to allow variations of the header and compute different hashes */
  size        INTEGER      NULL,
  txcount     INTEGER      NULL,        /* Number of transaction entries */
  PRIMARY KEY (protocol, blocknumber)
);

/* to find block info by block number */
CREATE INDEX blocknumtime  ON blocks (blocknumber, protocol, blocktime);

/* transaction stats */
CREATE TABLE IF NOT EXISTS txstats (
  id          SERIAL,
  protocol    PROTOCOL     NOT NULL DEFAULT 'Omni',     /* initially 'Omni' */
  blocknumber INTEGER      NOT NULL,
  blocktime   TIMESTAMP(0) NOT NULL,                    /* timestamp recording when this block was created (Will overflow in 2106) */
  txcount     INTEGER      NULL,                        /* Number of transaction entries in past 24 hours */
  blockcount  INTEGER      NULL,                        /* Number of transaction in block */
  PRIMARY KEY (id)
);

/* to find block info by block number */
CREATE INDEX txstats_block  ON txstats (blocknumber, protocol, blocktime);

/* all the transactions we know about; keeping them (forever?) even after an address or wallet is de-activated */
CREATE TABLE IF NOT EXISTS transactions (
  id            SERIAL,
  txhash        VARCHAR(64)                    NOT NULL,                    /* varchar so we can use LIKE & other string matching  */
  protocol      PROTOCOL                       NOT NULL,                    /* initially 'Bitcoin' or 'Omni' */
  txdbserialnum SERIAL8 UNIQUE,                                             /* db internal identifier for each tx, for faster joins */
  txtype        INTEGER                        NOT NULL,                    /* from the RPC result for an 'Omni' tx, 0 for 'Bitcoin' tx's */
  txversion     SMALLINT                       NOT NULL,                    /* from the RPC result */
  ecosystem     ECOSYSTEM                      NULL,                        /* Null for 'Bitcoin' tx's */
  txrecvtime    TIMESTAMP(0) WITHOUT TIME ZONE NULL     DEFAULT now(),      /* when it was sent, if known */
  txstate       TXSTATE                        NOT NULL DEFAULT 'pending',  /* pending, valid, not valid */
  txerrorcode   SMALLINT                       NULL,                        /* successful? if not, why not? (see ErrorCodes) */
  txblocknumber INTEGER                        NULL,
  txseqinblock  INTEGER                        NULL,                        /* determined by order of tx's in the block */
  PRIMARY KEY (id)
  /*	, foreign key (Protocol, TxBlockNumber) references Blocks */
);

/* index for searching hash and protocol */
CREATE INDEX tx_hash_prot_block  ON transactions (txhash, protocol, txblocknumber);

/* to find transactions by the db internal id */
CREATE UNIQUE INDEX txdbserials  ON transactions (txdbserialnum, protocol);

/* to find transactions by type & version */
CREATE INDEX txtypes  ON transactions (txtype, txversion, protocol);

/* to find transactions by serialnum */
CREATE INDEX txdbserialnum  ON transactions (txdbserialnum);

/* to find transactions by order in the blockchain */
CREATE INDEX txseq  ON transactions (txblocknumber, txseqinblock);

/* data that is specific to the particular transaction type, as a JSON object */
CREATE TABLE IF NOT EXISTS txjson (
  id            SERIAL,
  txdbserialnum INT8     NOT NULL,                              /* db internal identifier for each tx, for faster joins */
  protocol      PROTOCOL NOT NULL,                              /* initially 'Bitcoin' or 'Omni' */
  txdata        JSONB    NOT NULL,                              /* the tx message fields */
  PRIMARY KEY (id)
  /*	, foreign key (TxDBSerialNum, Protocol) references Transactions(TxDBSerialNum, Protocol) */
);

/* add index for serialnum and protocol */
CREATE INDEX txj_txdbser_prot  ON txjson (txdbserialnum, protocol);

/* index to search/filter by txtype */
CREATE INDEX txj_json_type  ON txjson (cast(txdata ->> 'type_int' AS NUMERIC));

/* index to search/filter by txid */
CREATE INDEX txj_json_txid  ON txjson (cast(txdata ->> 'txid' AS TEXT));

/* index to search/filter by address */
CREATE INDEX txj_json_saddress  ON txjson (cast(txdata ->> 'sendingaddress' AS TEXT));
CREATE INDEX txj_json_raddress  ON txjson (cast(txdata ->> 'referenceaddress' AS TEXT));

/* Addresses that are involved in each transaction, with their role and changes to balances */
CREATE TABLE IF NOT EXISTS addressesintxs (                     /* many-to-many */
  address                     VARCHAR(64) NOT NULL,
  propertyid                  BIGINT      NOT NULL,
  protocol                    PROTOCOL    NOT NULL,             /* initially 'Bitcoin' or 'Omni' */
  txdbserialnum               INT8        NOT NULL DEFAULT -1,  /* db internal identifier for each tx, for faster joins */
  addresstxindex              INT2        NOT NULL,             /* position in the input or output list */
  addressrole                 ADDRESSROLE NOT NULL,
  balanceavailablecreditdebit NUMERIC(19) NULL,                 /* how much the balance changed */
  balancereservedcreditdebit  NUMERIC(19) NULL,                 /* how much the balance changed */
  balanceacceptedcreditdebit  NUMERIC(19) NULL,                 /* how much the balance changed */
  balancefrozencreditdebit    NUMERIC(19) NULL,                 /* how much the balance changed */
  linkedtxdbserialnum         INT8        NOT NULL DEFAULT -1,  /* tx with the associated output for inputs, or with the associated input for outputs */
  PRIMARY KEY (address, txdbserialnum, propertyid, addressrole, addresstxindex)
  /*	, foreign key (Address, Protocol, PropertyID) references AddressBalances */
  /*	, foreign key (TxDBSerialNum, Protocol) references Transactions (TxDBSerialNum, Protocol) */
);

/* to find info about addresses affected by a particular transaction */
CREATE INDEX addr_idx  ON addressesintxs (address, txdbserialnum, propertyid);

/* to find by txdbserialnum */
CREATE INDEX aitdbser_idx  ON addressesintxs (txdbserialnum);

/* "temporary" table for pre-populating the LinkedTxDBSerialNum field when doing bulk loads of AddressesInTxs */
CREATE TABLE IF NOT EXISTS tolinkaddressesintxs (           /* many-to-many */
  address             VARCHAR(64) NOT NULL,
  propertyid          BIGINT      NOT NULL,
  protocol            PROTOCOL    NOT NULL,                 /* initially 'Bitcoin' or 'Omni' */
  txdbserialnum       INT8        NOT NULL DEFAULT -1,      /* db internal identifier for each tx, for faster joins */
  addresstxindex      INT2        NOT NULL,                 /* position in the input or output list */
  linkedtxdbserialnum INT8        NOT NULL DEFAULT -1,      /* tx with the associated output for inputs, or with the associated input for outputs */
  addressrole         ADDRESSROLE NOT NULL,
  thistxhash          VARCHAR(64),
  linkedtxhash        VARCHAR(64),
  PRIMARY KEY (address, txdbserialnum, propertyid, addressrole)
);

/* to find info about addresses affected by a particular transaction */
CREATE INDEX txdbseriallink  ON tolinkaddressesintxs (txdbserialnum, propertyid);

/* to find info about addresses affected by a particular transaction */
CREATE INDEX thistxhash  ON tolinkaddressesintxs (thistxhash, protocol);

/* current state of Smart Properties (and currencies??); 1 row for each SP */
CREATE TABLE IF NOT EXISTS smartproperties (
  protocol            PROTOCOL,                             /* Protocol plus PropertyID uniquely identify a property */
  propertyid          BIGINT,                               /* signed 64-bit, to store unsigned 32 bit values */
  issuer              VARCHAR(64)   NOT NULL,               /* Address that created it */
  ecosystem           ECOSYSTEM     NULL,                   /* Production or Test (for now) */
  createtxdbserialnum INT8          NOT NULL,               /* the tx that created this SP, for faster joins */
  lasttxdbserialnum   INT8          NOT NULL,               /* the last tx that updated this SP, for faster joins */
  propertyname        VARCHAR(256)  NULL,
  propertytype        SMALLINT      NULL,
  prevpropertyid      BIGINT        NULL DEFAULT 0,
  propertyserviceurl  VARCHAR(256)  NULL,
  propertycategory    VARCHAR(256)  NULL,                   /* see PropertyCategories - TBD */
  propertysubcategory VARCHAR(256)  NULL,                   /* see PropertyCategories - TBD */
  propertydata        JSONB         NULL,                   /* with the current data for this SP, varies by SP type */
  registrationdata    VARCHAR(5000) NULL,                   /* allow extra data for registered properties */
  flags               JSONB         NULL,                   /* if we need to set any flags/warnings for the property */
  PRIMARY KEY (propertyid, protocol)
  /*	, foreign key (Issuer, Protocol, PropertyID) references AddressBalances (Address, Protocol, PropertyID) */
  /*	, foreign key (CreateTxDBSerialNum, Protocol) references Transactions (TxDBSerialNum, Protocol) */
  /*	, foreign key (LastTxDBSerialNum, Protocol) references Transactions (TxDBSerialNum, Protocol) */
);

/* to find Smart Properties by issuing address */
CREATE UNIQUE INDEX sp_issuer  ON smartproperties (issuer, propertyid, protocol);
/* to order properties in searches  */
CREATE UNIQUE INDEX sp_name_id_prot  ON smartproperties (propertyname, propertyid, protocol);
CREATE INDEX sp_json_crowdsale_state  ON smartproperties ((propertydata ->> 'active'));

/* the list of transactions that affected each SP */
CREATE TABLE IF NOT EXISTS propertyhistory (
  protocol      PROTOCOL NOT NULL,                          /* Protocol plus PropertyID uniquely identify a property */
  propertyid    BIGINT   NOT NULL,                          /* signed 64-bit, to store unsigned 32 bit values */
  txdbserialnum INT8     NOT NULL,                          /* the tx that affected this SP, for faster joins */
  PRIMARY KEY (propertyid, protocol, txdbserialnum)
  /*	, foreign key (PropertyID, Protocol) references SmartProperties */
);

/* to find Smart Properties by TxDBSerialNum */
CREATE INDEX txdbserialnumhist  ON propertyhistory (txdbserialnum);

/* A wallet can watch any object - address, SP, tx type (even a blocknumber?) */
CREATE TABLE IF NOT EXISTS following (
  walletid   UUID,
  objecttype OBJECTTYPE,
  objectid   VARCHAR(64),                                   /* works with Addresses initially */
  /* future - Event, see EventTypes (to generate alerts/notifications) */
  PRIMARY KEY (walletid),
  FOREIGN KEY (walletid) REFERENCES wallets
);

/* directional exchange rates between pairs of properties; can work with fiat currencies as well */
/* rate for 1 --> 2 not necessarily the same as the reciprocal of rate for 2 --> 1 */
CREATE TABLE IF NOT EXISTS exchangerates (
  protocol1   PROTOCOL,                                     /* see Protocols */
  propertyid1 BIGINT,                                       /* need exchange rates for fiat currencies */
  protocol2   PROTOCOL,
  propertyid2 BIGINT,
  rate1for2   FLOAT,                                        /* (1 for 2) */
  asof        TIMESTAMP(0) DEFAULT now(),
  source      VARCHAR(256),                                 /* URL */
  id          SERIAL,
  PRIMARY KEY (id, propertyid1, propertyid2, protocol1, protocol2)
);

CREATE TABLE IF NOT EXISTS matchedtrades (
  txdbserialnum      INT8        NOT NULL DEFAULT -1,       /* tx with the associated sale information */
  txhash             VARCHAR(64) NOT NULL,                  /* our txhash */
  propertyidsold     BIGINT      NOT NULL,                  /* Property ID sold  */
  propertyidreceived BIGINT      NOT NULL,                  /* Property ID bought   */
  amountsold         VARCHAR(20) NOT NULL,                  /* amount sold */
  amountreceived     VARCHAR(20) NOT NULL,                  /* amount bought */
  block              INTEGER     NOT NULL,                  /* block match took place */
  tradingfee         VARCHAR(20) NOT NULL DEFAULT 0,        /* any associated trading fees */
  matchedtxhash      VARCHAR(64) NOT NULL,
  PRIMARY KEY (txdbserialnum, propertyidsold, propertyidreceived, matchedtxhash),
  FOREIGN KEY (txdbserialnum) REFERENCES transactions (txdbserialnum)
);

CREATE TABLE IF NOT EXISTS activeoffers (
  amountaccepted      NUMERIC(19)    NOT NULL,              /* Amount available that has been accepted but not purchased */
  amountavailable     NUMERIC(19)    NOT NULL,              /* Amount available for sale that can be accepted */
  amountdesired       NUMERIC(19)    NOT NULL,              /* If total amountavailable where purchased, this would be cost */
  minimumfee          NUMERIC(19)    NOT NULL,              /* Min fee buyer has to pay */
  /*      , ProtocolSelling Protocol not null  */           /* Protocol plus PropertyID uniquely identify a property */
  propertyidselling   BIGINT         NOT NULL,              /* Property ID for sale  */
  /*      , ProtocolDesired Protocol not null  */           /* Protocol plus PropertyID uniquely identify a property */
  propertyiddesired   BIGINT         NOT NULL DEFAULT 0,    /* Defaults to 0 for btc for now, allows MetaDEx support ? */
  seller              VARCHAR(64)    NOT NULL,              /* Sellers address */
  timelimit           SMALLINT       NOT NULL,              /* Block time buyer has to pay for any accepts */
  createtxdbserialnum INT8           NOT NULL DEFAULT -1 ,  /* tx with the associated sale information */
  unitprice           NUMERIC(27, 8) NOT NULL,              /* Amount of PropertyIdDesired per one token of PropertyIdSelling */
  offerstate          OFFERSTATE     NOT NULL,              /* active, cancelled, replaced, soldout  */
  lasttxdbserialnum   INT8           NOT NULL DEFAULT -1,   /* last tx that produced a cancelled, replaced or soldout state */
  totalselling        NUMERIC(19)    NOT NULL               /* Total Amount put up for sale regardless of current accepts/sales */

  /*      , primary key (PropertyIdSelling, PropertyIdDesired, Seller) */
  /*      , foreign key (PropertyIdSelling, Protocol) references SmartProperties */
  /*      , foreign key (PropertyIdDesired, Protocol) references SmartProperties */
);

CREATE INDEX sellers  ON activeoffers (seller);
CREATE INDEX idsellingdesired  ON activeoffers (propertyidselling, propertyiddesired);

CREATE TABLE IF NOT EXISTS offeraccepts (
  buyer               VARCHAR(64) NOT NULL,                     /* Buyers address */
  amountaccepted      NUMERIC(19) NOT NULL,           /* amount accepted by buyer */
  linkedtxdbserialnum INT8        NOT NULL,            /* tx with the associated accept offer */
  saletxdbserialnum   INT8        NOT NULL,             /* tx the offer is actually accepting against */
  block               INT         NOT NULL,                         /* Block the accept was received in */
  dexstate            DEXSTATE    NOT NULL,                /* invalid, unpaid, paid-partial, paid-complete */
  expireblock         INT         NOT NULL,                 /* Last block payment for this accept can be received in */
  expiredstate        BOOLEAN              DEFAULT FALSE,             /* true/false if this accept is expired */
  amountpurchased     NUMERIC(19) NOT NULL DEFAULT 0, /* amount user has purchsed/paid for so far */
  PRIMARY KEY (saletxdbserialnum, linkedtxdbserialnum)
  /*      , foreign key (SaleTxDbSerialNum) references ActiveOffers (CreateTxDBSerialNum) */
  /*      , foreign key (LinkedTxDBSerialNum) references Transactions (TxDBSerialNum) */
);

CREATE INDEX buyers  ON offeraccepts (buyer);

/* dictionary of known protocols */
CREATE TABLE IF NOT EXISTS protocols (
  protocol     PROTOCOL UNIQUE NOT NULL,
  baseprotocol PROTOCOL        NOT NULL,  /* e.g. Bitcoin is the base of Omni, Protocol = BaseProtocol if a base protocol */
  url          VARCHAR(256)    NULL
);

/*
 * dictionary of categories & subcategories
 * based on International Standard Industrial Classification of All Economic Activities, Rev.4 (ISIC)
 * Categories are rows where Division is null
 * Divisions are other rows, grouped by Section value
 * http://unstats.un.org/unsd/cr/registry/regcst.asp?Cl=27&Lg=1
 */
CREATE TABLE IF NOT EXISTS categories (
  section  VARCHAR(2)   NOT NULL,
  division VARCHAR(4)   NOT NULL,
  name     VARCHAR(256) NOT NULL,
  PRIMARY KEY (section, division)
);

/*
 * Generic settings table to be used for global omniwallet settings/features
 */
CREATE TABLE IF NOT EXISTS settings (
  key        VARCHAR(32) NOT NULL,
  value      VARCHAR(64) NOT NULL,
  note       VARCHAR(256),
  updated_at TIMESTAMP(0) DEFAULT now(),
  PRIMARY KEY (key)
);

/*
 * Market data for DEx markets
 */
CREATE TABLE IF NOT EXISTS markets (
  propertyiddesired  BIGINT                         NOT NULL,
  desiredname        VARCHAR(256)                   NULL,
  propertyidselling  BIGINT                         NOT NULL,
  sellingname        VARCHAR(256)                   NULL,
  unitprice          NUMERIC(27, 8)                 NOT NULL DEFAULT 0,
  supply             NUMERIC(27, 8)                 NOT NULL DEFAULT 0,
  lastprice          NUMERIC(27, 8)                 NOT NULL DEFAULT 0,
  marketpropertytype SMALLINT                       NULL,
  lasttxdbserialnum  INT8                           NOT NULL,
  lastupdated        TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
  PRIMARY KEY (propertyiddesired, propertyidselling)
);


/* Load the initial known protocols */
INSERT INTO protocols VALUES ('Bitcoin', 'Bitcoin', 'http://bitcoin.org');

INSERT INTO protocols VALUES ('Omni', 'Bitcoin', 'http://omnilayer.org');

INSERT INTO protocols VALUES ('Fiat', 'Fiat', 'http://en.wikipedia.org/wiki/Fiat_money');

/*Load the Bitcoin property*/
INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname, propertytype, propertydata)
VALUES ('Bitcoin', 0, 'Satoshi Nakamoto', -1, -1, 'BTC', 2, '{"name":"BTC", "blocktime":1231006505, "data":"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks", "issuer":"Satoshi Nakamoto", "url":"http://www.bitcoin.org", "propertyid":0 ,"divisible": true}');

/*Load the list of Fiat Currencies we track */

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 0, 'United States Dollar', -1, -1, 'USD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 1, 'Canadian Dollar', -1, -1, 'CAD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 2, 'Euro', -1, -1, 'EUR');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 3, 'Australian Dollar', -1, -1, 'AUD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 4, 'Indonesian Rupiah', -1, -1, 'IDR');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 5, 'Israeli New Sheqel', -1, -1, 'ILS');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 6, 'British Pound Sterling', -1, -1, 'GBP');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 7, 'Romanian Leu', -1, -1, 'RON');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 8, 'Swedish Krona', -1, -1, 'SEK');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 9, 'Singapore Dollar', -1, -1, 'SGD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 10, 'Hong Kong Dollar', -1, -1, 'HKD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 11, 'Swiss Franc', -1, -1, 'CHF');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 12, 'Chinese Yuan', -1, -1, 'CNY');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 13, 'Turkish Lira', -1, -1, 'TRY');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 14, 'New Zealand Dollar', -1, -1, 'NZD');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 15, 'Norwegian Krone', -1, -1, 'NOK');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 16, 'Russian Ruble', -1, -1, 'RUB');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 17, 'Mexican Peso', -1, -1, 'MXN');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 18, 'Brazilian Real', -1, -1, 'BRL');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 19, 'Polish Zloty', -1, -1, 'PLN');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 20, 'South African Rand', -1, -1, 'ZAR');

INSERT INTO smartproperties (protocol, propertyid, issuer, createtxdbserialnum, lasttxdbserialnum, propertyname)
VALUES ('Fiat', 21, 'Japanese Yen', -1, -1, 'JPY');


/* load the Category and Subcategory values. 'zz' values are not part of ISIC */
INSERT INTO categories (section, division, name) VALUES ('A', '00', 'Agriculture, forestry and fishing');

INSERT INTO categories (section, division, name) VALUES ('A', '01', 'Crop and animal production, hunting and related service activities');

INSERT INTO categories (section, division, name) VALUES ('A', '02', 'Forestry and logging');

INSERT INTO categories (section, division, name) VALUES ('A', '03', 'Fishing and aquaculture');

INSERT INTO categories (section, division, name) VALUES ('A', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('B', '00', 'Mining and quarrying');

INSERT INTO categories (section, division, name) VALUES ('B', '05', 'Forestry and logging');

INSERT INTO categories (section, division, name) VALUES ('B', '06', 'Extraction of crude petroleum and natural gas');

INSERT INTO categories (section, division, name) VALUES ('B', '07', 'Mining of metal ores');

INSERT INTO categories (section, division, name) VALUES ('B', '08', 'Other mining and quarrying');

INSERT INTO categories (section, division, name) VALUES ('B', '09', 'Mining support service activities');

INSERT INTO categories (section, division, name) VALUES ('B', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('C', '00', 'Manufacturing');

INSERT INTO categories (section, division, name) VALUES ('C', '10', 'Manufacture of food products');

INSERT INTO categories (section, division, name) VALUES ('C', '11', 'Manufacture of beverages');

INSERT INTO categories (section, division, name) VALUES ('C', '12', 'Manufacture of tobacco products');

INSERT INTO categories (section, division, name) VALUES ('C', '13', 'Manufacture of textiles');

INSERT INTO categories (section, division, name) VALUES ('C', '14', 'Manufacture of wearing apparel');

INSERT INTO categories (section, division, name) VALUES ('C', '15', 'Manufacture of leather and related products');

INSERT INTO categories (section, division, name) VALUES ('C', '16', 'Manufacture of wood and of products of wood and cork, except furniture; manufacture of articles of straw and plaiting materials');

INSERT INTO categories (section, division, name) VALUES ('C', '17', 'Manufacture of paper and paper products');

INSERT INTO categories (section, division, name) VALUES ('C', '18', 'Printing and reproduction of recorded media');

INSERT INTO categories (section, division, name) VALUES ('C', '19', 'Manufacture of coke and refined petroleum products');

INSERT INTO categories (section, division, name) VALUES ('C', '20', 'Manufacture of chemicals and chemical products');

INSERT INTO categories (section, division, name) VALUES ('C', '21', 'Manufacture of basic pharmaceutical products and pharmaceutical preparations');

INSERT INTO categories (section, division, name) VALUES ('C', '22', 'Manufacture of rubber and plastics products');

INSERT INTO categories (section, division, name) VALUES ('C', '23', 'Manufacture of other non-metallic mineral products');

INSERT INTO categories (section, division, name) VALUES ('C', '24', 'Manufacture of basic metals');

INSERT INTO categories (section, division, name) VALUES ('C', '25', 'Manufacture of fabricated metal products, except machinery and equipment');

INSERT INTO categories (section, division, name) VALUES ('C', '26', 'Manufacture of computer, electronic and optical products');

INSERT INTO categories (section, division, name) VALUES ('C', '27', 'Manufacture of electrical equipment');

INSERT INTO categories (section, division, name) VALUES ('C', '28', 'Manufacture of machinery and equipment n.e.c.');

INSERT INTO categories (section, division, name) VALUES ('C', '29', 'Manufacture of motor vehicles, trailers and semi-trailers');

INSERT INTO categories (section, division, name) VALUES ('C', '30', 'Manufacture of other transport equipment');

INSERT INTO categories (section, division, name) VALUES ('C', '31', 'Manufacture of furniture');

INSERT INTO categories (section, division, name) VALUES ('C', '32', 'Other manufacturing');

INSERT INTO categories (section, division, name) VALUES ('C', '33', 'Repair and installation of machinery and equipment');

INSERT INTO categories (section, division, name) VALUES ('C', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('D', '00', 'Electricity, gas, steam and air conditioning supply');

INSERT INTO categories (section, division, name) VALUES ('D', '35', 'Electricity, gas, steam and air conditioning supply');

INSERT INTO categories (section, division, name) VALUES ('D', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('E', '00', 'Water supply; sewerage, waste management and remediation activities');

INSERT INTO categories (section, division, name) VALUES ('E', '36', 'Water collection, treatment and supply');

INSERT INTO categories (section, division, name) VALUES ('E', '37', 'Sewerage');

INSERT INTO categories (section, division, name) VALUES ('E', '38', 'Waste collection, treatment and disposal activities; materials recovery');

INSERT INTO categories (section, division, name) VALUES ('E', '39', 'Remediation activities and other waste management services');

INSERT INTO categories (section, division, name) VALUES ('E', 'ZZ', 'Other');


INSERT INTO categories (section, division, name) VALUES ('F', '00', 'Construction');

INSERT INTO categories (section, division, name) VALUES ('F', '41', 'Construction of buildings');

INSERT INTO categories (section, division, name) VALUES ('F', '42', 'Civil engineering');

INSERT INTO categories (section, division, name) VALUES ('F', '43', 'Specialized construction activities');

INSERT INTO categories (section, division, name) VALUES ('F', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('G', '00', 'Wholesale and retail trade; repair of motor vehicles and motorcycles');

INSERT INTO categories (section, division, name) VALUES ('G', '45', 'Wholesale and retail trade and repair of motor vehicles and motorcycles');

INSERT INTO categories (section, division, name) VALUES ('G', '46', 'Wholesale trade, except of motor vehicles and motorcycles');

INSERT INTO categories (section, division, name) VALUES ('G', '47', 'Retail trade, except of motor vehicles and motorcycles');

INSERT INTO categories (section, division, name) VALUES ('G', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('H', '00', 'Transportation and storage');

INSERT INTO categories (section, division, name) VALUES ('H', '49', 'Land transport and transport via pipelines');

INSERT INTO categories (section, division, name) VALUES ('H', '50', 'Water transport');

INSERT INTO categories (section, division, name) VALUES ('H', '51', 'Air transport');

INSERT INTO categories (section, division, name) VALUES ('H', '52', 'Warehousing and support activities for transportation');

INSERT INTO categories (section, division, name) VALUES ('H', '53', 'Postal and courier activities');

INSERT INTO categories (section, division, name) VALUES ('H', 'ZZ', 'Other');


INSERT INTO categories (section, division, name) VALUES ('I', '00', 'Accommodation and food service activities');

INSERT INTO categories (section, division, name) VALUES ('I', '55', 'Accommodation');

INSERT INTO categories (section, division, name) VALUES ('I', '56', 'Food and beverage service activities');

INSERT INTO categories (section, division, name) VALUES ('I', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('J', '00', 'Information and communication');

INSERT INTO categories (section, division, name) VALUES ('J', '58', 'Publishing activities');

INSERT INTO categories (section, division, name) VALUES ('J', '59', 'Motion picture, video and television programme production, sound recording and music publishing activities');

INSERT INTO categories (section, division, name) VALUES ('J', '60', 'Programming and broadcasting activities');

INSERT INTO categories (section, division, name) VALUES ('J', '61', 'Telecommunications');

INSERT INTO categories (section, division, name) VALUES ('J', '62', 'Computer programming, consultancy and related activities');

INSERT INTO categories (section, division, name) VALUES ('J', '63', 'Information service activities');

INSERT INTO categories (section, division, name) VALUES ('J', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('K', '00', 'Financial and insurance activities');

INSERT INTO categories (section, division, name) VALUES ('K', '64', 'Financial service activities, except insurance and pension funding');

INSERT INTO categories (section, division, name) VALUES ('K', '65', 'Insurance, reinsurance and pension funding, except compulsory social security');

INSERT INTO categories (section, division, name) VALUES ('K', '66', 'Activities auxiliary to financial service and insurance activities');

INSERT INTO categories (section, division, name) VALUES ('K', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('L', '00', 'Real estate activities');

INSERT INTO categories (section, division, name) VALUES ('L', '68', 'Real estate activities');

INSERT INTO categories (section, division, name) VALUES ('L', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('M', '00', 'Professional, scientific and technical activities');

INSERT INTO categories (section, division, name) VALUES ('M', '69', 'Legal and accounting activities');

INSERT INTO categories (section, division, name) VALUES ('M', '70', 'Activities of head offices; management consultancy activities');

INSERT INTO categories (section, division, name) VALUES ('M', '71', 'Architectural and engineering activities; technical testing and analysis');

INSERT INTO categories (section, division, name) VALUES ('M', '72', 'Scientific research and development');

INSERT INTO categories (section, division, name) VALUES ('M', '73', 'Advertising and market research');

INSERT INTO categories (section, division, name) VALUES ('M', '74', 'Other professional, scientific and technical activities');

INSERT INTO categories (section, division, name) VALUES ('M', '75', 'Veterinary activities');

INSERT INTO categories (section, division, name) VALUES ('M', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('N', '00', 'Administrative and support service activities');

INSERT INTO categories (section, division, name) VALUES ('N', '77', 'Rental and leasing activities');

INSERT INTO categories (section, division, name) VALUES ('N', '78', 'Employment activities');

INSERT INTO categories (section, division, name) VALUES ('N', '79', 'Travel agency, tour operator, reservation service and related activities');

INSERT INTO categories (section, division, name) VALUES ('N', '80', 'Security and investigation activities');

INSERT INTO categories (section, division, name) VALUES ('N', '81', 'Services to buildings and landscape activities');

INSERT INTO categories (section, division, name) VALUES ('N', '82', 'Office administrative, office support and other business support activities');

INSERT INTO categories (section, division, name) VALUES ('N', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('O', '00', 'Public administration and defence; compulsory social security');

INSERT INTO categories (section, division, name) VALUES ('O', '84', 'Public administration and defence; compulsory social security');

INSERT INTO categories (section, division, name) VALUES ('O', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('P', '00', 'Education');

INSERT INTO categories (section, division, name) VALUES ('P', '85', 'Education');

INSERT INTO categories (section, division, name) VALUES ('P', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('Q', '00', 'Human health and social work activities');

INSERT INTO categories (section, division, name) VALUES ('Q', '86', 'Human health activities');

INSERT INTO categories (section, division, name) VALUES ('Q', '87', 'Residential care activities');

INSERT INTO categories (section, division, name) VALUES ('Q', '88', 'Social work activities without accommodation');

INSERT INTO categories (section, division, name) VALUES ('Q', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('R', '00', 'Arts, entertainment and recreation');

INSERT INTO categories (section, division, name) VALUES ('R', '90', 'Creative, arts and entertainment activities');

INSERT INTO categories (section, division, name) VALUES ('R', '91', 'Libraries, archives, museums and other cultural activities');

INSERT INTO categories (section, division, name) VALUES ('R', '92', 'Gambling and betting activities');

INSERT INTO categories (section, division, name) VALUES ('R', '93', 'Sports activities and amusement and recreation activities');

INSERT INTO categories (section, division, name) VALUES ('R', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('S', '00', 'Other service activities');

INSERT INTO categories (section, division, name) VALUES ('S', '94', 'Activities of membership organizations');

INSERT INTO categories (section, division, name) VALUES ('S', '95', 'Repair of computers and personal and household goods');

INSERT INTO categories (section, division, name) VALUES ('S', '96', 'Other personal service activities');

INSERT INTO categories (section, division, name) VALUES ('S', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('T', '00', 'Activities of households as employers; undifferentiated goods- and services-producing activities of households for own use');

INSERT INTO categories (section, division, name) VALUES ('T', '97', 'Activities of households as employers of domestic personnel');

INSERT INTO categories (section, division, name) VALUES ('T', '98', 'Undifferentiated goods- and services-producing activities of private households for own use');

INSERT INTO categories (section, division, name) VALUES ('T', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('U', '00', 'Activities of extraterritorial organizations and bodies');

INSERT INTO categories (section, division, name) VALUES ('U', '99', 'Activities of extraterritorial organizations and bodies');
INSERT INTO categories (section, division, name) VALUES ('U', 'zz', 'Other');


INSERT INTO categories (section, division, name) VALUES ('zz', '99', 'Other');
INSERT INTO categories (section, division, name) VALUES ('zz', 'zz', 'Other');


/* the following user commands should be executed while connected to your omniwallet database */

/*
   Your command line or other tool that invokes this script should connect to
   the correct database, typically 'omniwallet'.

   It should also set the username & password variables:
        :omniengine, :omnienginePassword, :omniwww, and :omniwwwPassword
   See scripts/db-init.sh for an example.
*/

DROP ROLE IF EXISTS omni, omniengine;
CREATE USER omni PASSWORD '${omniapipassword}';
CREATE USER omniengine PASSWORD '${omnienginepassword}';

/*  If you change usernames make sure to update them below */

GRANT CONNECT ON DATABASE omni TO omniengine, omni;

GRANT USAGE ON SCHEMA public TO omniengine, omni;
GRANT SELECT,UPDATE ON ALL SEQUENCES IN SCHEMA public TO omniengine;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA public TO omni;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO omniengine;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO omni;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE following, addressesinwallets, sessions, wallets TO omni;
GRANT INSERT ON txjson TO omni;
GRANT INSERT (txhash, protocol, txdbserialnum, txtype, txversion) ON transactions TO omni;
GRANT INSERT ON addressesintxs TO omni;
GRANT INSERT ON walletbackups TO omni;
