SET SESSION gold.compression_codec = 'ZSTD';

CREATE OR REPLACE TABLE gold.lakehouse.large_volume_customer
WITH (format = 'PARQUET')
AS SELECT
     c.name,
     f.custkey,
     f.orderkey,
     f.orderdate,
     f.totalprice,
     f.total_quantity
   FROM silver.lakehouse.fact_order AS f
   JOIN silver.lakehouse.dim_customer AS c
     ON c.custkey = f.custkey AND c.is_current = true
   ORDER BY f.totalprice DESC, f.orderdate
   LIMIT 100;
