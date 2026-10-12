SET SESSION silver.compression_codec = 'ZSTD';

CREATE OR REPLACE TABLE silver.lakehouse.dim_customer
WITH (format = 'PARQUET')
AS SELECT
     custkey,
     trim(name)       AS name,
     trim(mktsegment) AS mktsegment,
     nationkey,
     acctbal,
     loaded_at        AS valid_from,
     LEAD(loaded_at) OVER (PARTITION BY custkey ORDER BY loaded_at) AS valid_to,
     (LEAD(loaded_at) OVER (PARTITION BY custkey ORDER BY loaded_at) IS NULL) AS is_current
   FROM bronze.lakehouse.raw_customer
   WHERE custkey IS NOT NULL AND name IS NOT NULL;

CREATE OR REPLACE TABLE silver.lakehouse.large_orders
WITH (format = 'PARQUET')
AS SELECT
     orderkey,
     sum(quantity) AS total_quantity
   FROM bronze.lakehouse.raw_lineitem
   WHERE orderkey IS NOT NULL AND quantity > 0
   GROUP BY orderkey
   HAVING sum(quantity) > 300;

CREATE OR REPLACE TABLE silver.lakehouse.fact_order
WITH (format = 'PARQUET', partitioning = ARRAY['year(orderdate)'])
AS SELECT
     o.orderkey,
     o.custkey,
     o.orderdate,
     o.totalprice,
     lo.total_quantity
   FROM bronze.lakehouse.raw_orders AS o
   JOIN silver.lakehouse.large_orders AS lo ON lo.orderkey = o.orderkey
   WHERE o.custkey IS NOT NULL AND o.totalprice > 0;
