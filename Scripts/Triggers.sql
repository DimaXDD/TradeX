---------------------- Создание триггеров ----------------------
-- Триггер на проверку дату в аукционе
CREATE OR REPLACE FUNCTION check_auction_dates() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.Дата_Начала_Торгов > NEW.Дата_Конца_Торгов THEN
    RAISE EXCEPTION 'Дата начала торгов не может быть больше даты окончания торгов';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_auction_dates_trigger
BEFORE INSERT OR UPDATE ON Аукционы
FOR EACH ROW
EXECUTE FUNCTION check_auction_dates();

-- Проверка, что ставка не меньше максимальной ставки для аукциона
CREATE OR REPLACE FUNCTION check_bid() RETURNS TRIGGER AS $$
DECLARE
    max_bid numeric;
BEGIN
    SELECT MAX(Ставка) INTO max_bid
    FROM Ставки
    WHERE ID_аукциона = NEW.ID_аукциона;

    IF max_bid IS NULL OR NEW.Ставка >= max_bid THEN
        RETURN NEW;
    ELSE
        RAISE EXCEPTION 'Ставка должна быть не меньше предыдущей максимальной ставки';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_bid_trigger
BEFORE INSERT ON Ставки
FOR EACH ROW
EXECUTE FUNCTION check_bid();

-- Проверка на то, что нельзя делать ставки на закрытом аукционе
CREATE OR REPLACE FUNCTION check_auction_status() RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Аукционы WHERE ID_аукциона = NEW.ID_аукциона AND Статус = 0) THEN
        RAISE EXCEPTION 'Ставки на закрытом аукционе запрещены!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_auction_status_trigger
BEFORE INSERT ON Ставки
FOR EACH ROW
EXECUTE FUNCTION check_auction_status();