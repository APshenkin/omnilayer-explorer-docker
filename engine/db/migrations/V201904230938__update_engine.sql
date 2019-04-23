ALTER TABLE txstats
    ADD value JSONB NULL;

ALTER TABLE exchangerates
    RENAME TO exchangerateshistory;


/* directional exchange rates between pairs of properties; can work with fiat currencies as well */
/* rate for 1 --> 2 not necessarily the same as the reciprocal of rate for 2 --> 1 */
CREATE TABLE IF NOT EXISTS exchangerates (
    protocol1   PROTOCOL /* see Protocols */
    ,
    propertyid1 BIGINT /* need exchange rates for fiat currencies */
    ,
    protocol2   PROTOCOL,
    propertyid2 BIGINT,
    rate1for2   FLOAT /* (1 for 2) */
    ,
    asof        TIMESTAMP(0) DEFAULT now( ),
    source      VARCHAR(256) /* URL */
    ,
    id          SERIAL,
    PRIMARY KEY (id, propertyid1, propertyid2, protocol1, protocol2)
);

/* create trigger to backup exchangerate data everytime it's modified */
CREATE OR REPLACE FUNCTION backupprices () RETURNS TRIGGER AS
$prices_backups$
BEGIN
    INSERT INTO exchangerateshistory(protocol1, propertyid1, protocol2, propertyid2, rate1for2, asof, source)
    VALUES (old.protocol1, old.propertyid1, old.protocol2, old.propertyid2, old.rate1for2, old.asof, old.source);
    RETURN new;
END;
$prices_backups$
    LANGUAGE plpgsql;

CREATE TRIGGER backup_prices
    BEFORE DELETE OR UPDATE OF rate1for2
    ON exchangerates
    FOR EACH ROW
EXECUTE PROCEDURE backupprices( );
