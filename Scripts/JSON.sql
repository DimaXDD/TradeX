---------------------- Импорт Экспорт в JSON ---------------------- 
CREATE EXTENSION if not exists ADMINPACK;
-- Мой способ
-- Экспорт
CREATE OR REPLACE FUNCTION EXPORT_LOTS_TO_JSON_FILE(FILE_PATH TEXT)
RETURNS VOID AS
$$
DECLARE
  JSON_DATA JSON;
BEGIN
  BEGIN
    SELECT JSON_AGG(ROW_TO_JSON(Лоты)) INTO JSON_DATA FROM Лоты;
    PERFORM PG_FILE_WRITE(FILE_PATH, JSON_DATA::TEXT, true);
  EXCEPTION WHEN OTHERS THEN
    RAISE 'Произошла ошибка: %', SQLERRM;
  END;
END;
$$
LANGUAGE PLPGSQL;


select EXPORT_LOTS_TO_JSON_FILE('E:\TradeX\JSON_data\lots.json')
select * from Лоты;
DROP FUNCTION EXPORT_LOTS_TO_JSON_FILE;


-- Импорт
CREATE OR REPLACE FUNCTION IMPORT_LOTS_FROM_JSON_FILE(FILE_PATH TEXT)
RETURNS TABLE (
  ID_Лота INTEGER,
  Наименование VARCHAR(255),
  Описание VARCHAR,
  Изображение VARCHAR(255)
) AS $$
DECLARE 
  FILE_CONTENT TEXT;
  JSON_DATA JSON;
  LOT_DATA JSON;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS temp_lots (
    ID_Лота INTEGER,
    Наименование VARCHAR(255),
    Описание VARCHAR,
    Изображение VARCHAR(255)
  );

  DELETE FROM temp_lots;

  BEGIN
    FILE_CONTENT := pg_read_file(FILE_PATH, 0, 1000000000);
  EXCEPTION WHEN OTHERS THEN
    RAISE 'Файл не найден: %', FILE_PATH;
  END;

  BEGIN
    JSON_DATA := FILE_CONTENT::JSON;
  EXCEPTION WHEN OTHERS THEN
    RAISE 'Некорректный JSON: %', SQLERRM;
  END;

  FOR LOT_DATA IN SELECT * FROM json_array_elements(JSON_DATA)
  LOOP
    IF NOT (LOT_DATA::jsonb ? 'id_Лота' AND LOT_DATA::jsonb ? 'Наименование' AND LOT_DATA::jsonb ? 'Описание' AND LOT_DATA::jsonb ? 'Изображение') THEN
      CONTINUE;
    END IF;

    INSERT INTO temp_lots (ID_Лота, Наименование, Описание, Изображение)
    VALUES (
      CAST(LOT_DATA->>'id_Лота' AS INTEGER), 
      LOT_DATA->>'Наименование', 
      LOT_DATA->>'Описание', 
      LOT_DATA->>'Изображение'
    );
  END LOOP;
  
  RETURN QUERY SELECT * FROM temp_lots;
END;
$$ LANGUAGE PLPGSQL;

select * from IMPORT_LOTS_FROM_JSON_FILE('E:\TradeX\JSON_data\lots.json')
DROP FUNCTION IMPORT_LOTS_FROM_JSON_FILE;