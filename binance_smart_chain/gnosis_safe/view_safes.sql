BEGIN;
DROP MATERIALIZED VIEW IF EXISTS gnosis_safe.view_safes;

CREATE MATERIALIZED VIEW gnosis_safe.view_safes AS
    SELECT
    	et.from AS address,
    	et.block_time AS creation_time
    FROM bsc.traces et 
    WHERE et.success = True
        AND et.call_type = 'delegatecall' -- The delegate call to the master copy is the Safe address
        AND substring(et."input" for 4) = '\xb63e800d' -- setup method of v1.1.1
        AND et."to" = '\x34cfac646f301356faa8b21e94227e3583fe3f5f'  -- mastercopy v1.1.1
        AND gas_used > 0  -- to ensure the setup call was successful
    
    UNION ALL
    
    SELECT contract_address AS address, evt_block_time AS creation_time
    FROM gnosis_safe."GnosisSafeL2_v1_3_0_evt_SafeSetup";

COMMIT;

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS view_safes_unique_idx ON gnosis_safe.view_safes (address);

INSERT INTO cron.job (schedule, command)
VALUES ('0 0 * * *', 'REFRESH MATERIALIZED VIEW CONCURRENTLY gnosis_safe.view_safes')
ON CONFLICT (command) DO UPDATE SET schedule=EXCLUDED.schedule;