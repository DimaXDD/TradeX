-- заходить в CMD по пути C:\Program Files\PostgreSQL\16\bin

-- команда для бэкапа
-- pg_dump -Fc -U postgres -d tradex> E:\TradeX\Reserve\backup.dump

-- команда для восстановления
-- pg_restore -Fc -U postgres -p 5432 -d tradex < E:\TradeX\Reserve\backup.dump