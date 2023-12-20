-- pg_dump -U postgres -d tradex > E:\TradeX\Reserve\backup.sql
drop database tradex;
create database tradex;

SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'tradex'
  AND pid <> pg_backend_pid();
  
 
-- psql -U postgres -d tradex < E:\TradeX\Reserve\backup.sql