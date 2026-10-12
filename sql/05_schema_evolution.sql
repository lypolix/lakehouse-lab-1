SHOW COLUMNS FROM silver.lakehouse.dim_customer;

ALTER TABLE silver.lakehouse.dim_customer ADD COLUMN segment_rank integer;

ALTER TABLE silver.lakehouse.dim_customer RENAME COLUMN acctbal TO account_balance;

SHOW COLUMNS FROM silver.lakehouse.dim_customer;

SELECT custkey, name, account_balance, segment_rank
FROM silver.lakehouse.dim_customer
ORDER BY custkey
LIMIT 5;

UPDATE silver.lakehouse.dim_customer
SET segment_rank = CASE mktsegment
      WHEN 'AUTOMOBILE' THEN 1 WHEN 'BUILDING' THEN 2 WHEN 'FURNITURE' THEN 3
      WHEN 'HOUSEHOLD' THEN 4 WHEN 'MACHINERY' THEN 5 ELSE 9 END;

SELECT segment_rank, mktsegment, count(*) AS cnt
FROM silver.lakehouse.dim_customer
GROUP BY segment_rank, mktsegment
ORDER BY segment_rank;

SELECT snapshot_id, parent_id, operation, committed_at
FROM silver.lakehouse."dim_customer$snapshots"
ORDER BY committed_at;
