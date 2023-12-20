---------------------- Вставка 100000 строк ---------------------- 
CREATE OR REPLACE FUNCTION INSERT_LOTS() RETURNS VOID AS $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..100000 LOOP
        INSERT INTO Лоты (Наименование, Описание, Изображение)
        VALUES ('Наименование ' || i, 'Описание', 'Изображение');
    END LOOP;
END;
$$ LANGUAGE plpgsql;


SELECT INSERT_LOTS();
SELECT * FROM Лоты;


---------------------- Производительность ---------------------- 
-- EXPLAIN ANALYZE SELECT Наименование FROM Лоты WHERE Наименование ILIKE '%Наименование%';
EXPLAIN ANALYZE SELECT Наименование FROM Лоты WHERE Наименование = 'Наименование 1024';
CREATE INDEX idx_наименование ON Лоты (Наименование);
drop index idx_наименование;
select * from pg_indexes where tablename ILIKE('%Лоты%')