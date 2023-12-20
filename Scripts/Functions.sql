---------------------- Создание функций ----------------------
-- Функция для аутентификации
CREATE OR REPLACE FUNCTION authenticate_user (
  input_email VARCHAR,
  input_password VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE 
  stored_password VARCHAR(100);
BEGIN 
  SELECT Пароль INTO stored_password FROM Пользователи WHERE email = input_email;
  IF stored_password IS NULL THEN
    RAISE NOTICE 'Пользователь с email % не найден, подключение невозможно', input_email;
    RETURN false;
  ELSE
    IF crypt(input_password, stored_password) = stored_password THEN
      RAISE NOTICE 'Пользователь с email % существует и пароль верный, подключение возможно', input_email;
      RETURN true;
    ELSE
      RAISE NOTICE 'Пользователь с email % существует, но пароль неверный, подключение невозможно', input_email;
      RETURN false;
    END IF;
  END IF;
EXCEPTION WHEN others THEN
  RAISE EXCEPTION 'Произошла ошибка: %', SQLERRM;
  RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Создание лота
CREATE OR REPLACE FUNCTION create_lot(
    _name VARCHAR(255),
    _description VARCHAR,
    _image_path VARCHAR(255)
) RETURNS INTEGER AS $$
DECLARE
    _lot_id INTEGER;
BEGIN
    IF _name IS NULL OR _name = '' OR _description IS NULL OR _description = '' THEN
        RAISE EXCEPTION 'Наименование и Описание не могут быть NULL или пустыми строками';
    END IF;
    BEGIN
        INSERT INTO Лоты (Наименование, Описание, Изображение)
        VALUES (_name, _description, _image_path)
        RETURNING ID_Лота INTO _lot_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN NULL;
    END;
    RETURN _lot_id;
END;
$$ LANGUAGE plpgsql;

-- Если будут какие-то проблемы, просто убираем блок "EXCEPTION-END"
-- Функция для вывода всех лотов в бд
CREATE OR REPLACE FUNCTION get_lots_list() RETURNS TABLE (
    lot_id INTEGER,
    name VARCHAR(255),
    description VARCHAR,
    image VARCHAR(255)
) AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT ID_Лота, Наименование, Описание, Изображение FROM Лоты;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Поиск лота по частичному названию
CREATE OR REPLACE FUNCTION search_lots_by_name(input_name VARCHAR) RETURNS TABLE (
    lot_id INTEGER,
    name VARCHAR(255),
    description VARCHAR,
    image VARCHAR(255)
) AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT ID_Лота, Наименование, Описание, Изображение FROM Лоты WHERE Наименование ILIKE '%' || input_name || '%';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция для вывода всех пользователей в бд
CREATE OR REPLACE FUNCTION get_all_users() RETURNS SETOF Пользователи AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Пользователи;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция для вывода всех аукционов в бд
CREATE OR REPLACE FUNCTION get_all_auctions() RETURNS SETOF Аукционы AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Аукционы;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;


-- Функция для вывода всех ставок в бд
CREATE OR REPLACE FUNCTION get_all_bets() RETURNS SETOF Ставки AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Ставки;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция получения списка активных аукционов 
-- Данная функция позволит получить список всех активных аукционов. 
-- Аукцион считается активным, если его дата окончания еще не наступила 
-- и его статус 1.
CREATE OR REPLACE FUNCTION get_active_auctions() RETURNS SETOF Аукционы AS $$
BEGIN
    CALL update_auction_status();
    RETURN QUERY SELECT * FROM Аукционы WHERE Статус = 1;
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE update_auction_status() AS $$
BEGIN
    UPDATE Аукционы SET Статус = 0 WHERE Дата_Конца_Торгов <= NOW() AND Статус = 1;
END;
$$ LANGUAGE plpgsql;


-- Функция определения победителя аукциона
CREATE OR REPLACE FUNCTION get_auction_winner(
    p_id_auction integer
) RETURNS Пользователи AS $$
DECLARE
    v_winner Пользователи%ROWTYPE;
    v_status INTEGER;
    auction_exists BOOLEAN;
    bids_exist BOOLEAN;
BEGIN
    IF p_id_auction <= 0 THEN
        RAISE EXCEPTION 'ID аукциона должен быть положительным числом';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Аукционы WHERE ID_аукциона = p_id_auction) INTO auction_exists;
    IF NOT auction_exists THEN
        RAISE EXCEPTION 'Аукцион с ID % не найден', p_id_auction;
    END IF;
    SELECT Статус INTO v_status FROM Аукционы WHERE ID_аукциона = p_id_auction;
    IF v_status = 1 THEN
        RAISE NOTICE 'Аукцион еще активен, победителя пока нельзя определить';
        RETURN NULL;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Ставки WHERE ID_аукциона = p_id_auction) INTO bids_exist;
    IF NOT bids_exist THEN
        RAISE NOTICE 'Аукцион закончен, ставок не было произведено. Этот лот будет доступен для последующего аукциона';
        DELETE FROM Аукционы WHERE ID_аукциона = p_id_auction;
        RETURN NULL;
    END IF;
    BEGIN
        SELECT Пользователи.*
        INTO v_winner
        FROM Пользователи
        JOIN Ставки ON Пользователи.ID_Пользователя = Ставки.ID_Пользователя
        WHERE Ставки.ID_аукциона = p_id_auction
        ORDER BY Ставки.Ставка DESC
        LIMIT 1;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN NULL;
    END;
    RETURN v_winner;
END;
$$ LANGUAGE plpgsql;

-- Функция обновления статуса аукциона
CREATE OR REPLACE FUNCTION update_auction_status(
    p_id_auction integer,
    p_new_status integer
) RETURNS VOID AS $$
BEGIN
    IF p_id_auction <= 0 THEN
        RAISE EXCEPTION 'ID аукциона должен быть положительным числом';
    END IF;
    IF p_new_status != 0 AND p_new_status != 1 THEN
        RAISE EXCEPTION 'Новый статус должен быть равен 0 или 1';
    END IF;
    BEGIN
        UPDATE Аукционы
        SET Статус = p_new_status
        WHERE ID_аукциона = p_id_auction;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;


-- Получение максимальной ставки на аукционе
CREATE OR REPLACE FUNCTION get_max_bid_for_auction(auction_id INTEGER) RETURNS NUMERIC(32,2) AS $$
DECLARE
    max_bid NUMERIC(32,2);
BEGIN
    IF auction_id <= 0 THEN
        RAISE EXCEPTION 'ID аукциона должен быть положительным числом';
    END IF;
    BEGIN
        SELECT MAX(Ставка) INTO max_bid FROM Ставки WHERE ID_аукциона = auction_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN NULL;
    END;
    RETURN max_bid;
END;
$$ LANGUAGE plpgsql;


-- Получение минимальной ставки на аукционе
CREATE OR REPLACE FUNCTION get_min_bid_for_auction(auction_id INTEGER) RETURNS NUMERIC(32,2) AS $$
DECLARE
    min_bid NUMERIC(32,2);
BEGIN
    IF auction_id <= 0 THEN
        RAISE EXCEPTION 'ID аукциона должен быть положительным числом';
    END IF;
    BEGIN
        SELECT MIN(Ставка) INTO min_bid FROM Ставки WHERE ID_аукциона = auction_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN NULL;
    END;
    RETURN min_bid;
END;
$$ LANGUAGE plpgsql;

-- Функция получения списка всех ставок для конкретного лота
CREATE OR REPLACE FUNCTION get_bids_for_lot(lot_id INTEGER) RETURNS TABLE (
    ID_Ставки INTEGER,
    ID_Пользователя INTEGER,
    Ставка NUMERIC(32,2),
    Время_ставки TIMESTAMP,
    Статус INTEGER,
    ID_Аукциона INTEGER
) AS $$
DECLARE
    auction_exists BOOLEAN;
BEGIN
    IF lot_id <= 0 THEN
        RAISE EXCEPTION 'ID лота должен быть положительным числом';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Аукционы WHERE ID_Лота = lot_id) INTO auction_exists;
    IF NOT auction_exists THEN
        RAISE EXCEPTION 'Аукцион для лота с ID % не найден', lot_id;
    END IF;
    BEGIN
        RETURN QUERY SELECT * FROM Ставки WHERE ID_аукциона IN (
            SELECT ID_аукциона FROM Аукционы WHERE ID_Лота = lot_id
        );
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция получения списка всех аукционов для конкретного пользователя
CREATE OR REPLACE FUNCTION get_auctions_for_user(user_id INTEGER) RETURNS TABLE (
    ID_Аукциона INTEGER
) AS $$
BEGIN
    IF user_id <= 0 THEN
        RAISE EXCEPTION 'ID пользователя должен быть положительным числом';
    END IF;
    BEGIN
        RETURN QUERY SELECT ID_аукциона FROM Аукционы WHERE ID_Пользователя = user_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция повышения ставки
CREATE OR REPLACE FUNCTION increase_bid(
    auction_id INTEGER,
    user_id INTEGER,
    new_bid NUMERIC(32,2)
) RETURNS VOID AS $$
DECLARE
    v_status INTEGER;
    bid_exists BOOLEAN;
BEGIN
    IF auction_id <= 0 OR user_id <= 0 OR new_bid <= 0 THEN
        RAISE EXCEPTION 'ID аукциона, ID пользователя и новая ставка должны быть положительными числами';
    END IF;
    SELECT Статус INTO v_status FROM Аукционы WHERE ID_аукциона = auction_id;
    IF v_status = 0 THEN
        RAISE NOTICE 'Аукцион завершен, ставки делать нельзя';
        RETURN;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Ставки WHERE ID_аукциона = auction_id AND ID_Пользователя = user_id) INTO bid_exists;
    IF NOT bid_exists THEN
        RAISE EXCEPTION 'Ставка пользователя на данный аукцион не найдена';
    END IF;
    BEGIN
        UPDATE Ставки SET Ставка = Ставка + new_bid, Время_ставки = NOW()
        WHERE ID_аукциона = auction_id AND ID_Пользователя = user_id;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;


-- Функция экстренного прекращения аукциона (для админов)
CREATE OR REPLACE FUNCTION end_auction(auction_id INTEGER) 
RETURNS VOID AS $$
DECLARE 
  current_status INTEGER;
BEGIN
    IF auction_id <= 0 THEN
        RAISE EXCEPTION 'ID аукциона должен быть положительным числом';
    END IF;
    BEGIN
        SELECT Статус INTO current_status FROM Аукционы WHERE ID_аукциона = auction_id;
        IF current_status = 0 THEN
            RAISE NOTICE 'Статус аукциона уже находится в состоянии 0';
        ELSE
            UPDATE Аукционы SET Статус = 0 WHERE ID_аукциона = auction_id;
        END IF;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
    END;
END;
$$ LANGUAGE PLPGSQL;

-- Вывод всех пользователей и лоты, которые они выиграли
CREATE OR REPLACE FUNCTION get_users_with_won_lots() RETURNS TABLE (
    ID_Пользователя INTEGER,
    Имя_Пользователя VARCHAR,
    ID_Лота INTEGER,
    Наименование_Лота VARCHAR
) AS $$
DECLARE
    auction_exists BOOLEAN;
BEGIN
    RETURN QUERY 
    SELECT Пользователи.ID_Пользователя, Пользователи.Имя, Лоты.ID_Лота, Лоты.Наименование
    FROM Пользователи
    JOIN Аукционы ON Пользователи.ID_Пользователя = (
        SELECT Ставки.ID_Пользователя
        FROM Ставки
        WHERE Ставки.ID_аукциона = Аукционы.ID_аукциона
        ORDER BY Ставки.Ставка DESC
        LIMIT 1
    )
    JOIN Лоты ON Аукционы.ID_Лота = Лоты.ID_Лота
    WHERE Аукционы.Статус = 0
    ORDER BY Пользователи.ID_Пользователя, Лоты.ID_Лота;
END;
$$ LANGUAGE plpgsql;

-- Функция-триггер на регистрации на одну почту 
CREATE OR REPLACE FUNCTION check_duplicate_email() 
RETURNS TRIGGER 
AS $$
BEGIN
    IF EXISTS (SELECT * FROM Пользователи WHERE email = NEW.email) THEN
        RAISE EXCEPTION 'Пользователь с таким email уже зарегистрирован';
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_duplicate_email
BEFORE INSERT ON Пользователи
FOR EACH ROW
EXECUTE FUNCTION check_duplicate_email();


CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Функция хеширования паролей 
CREATE OR REPLACE FUNCTION hash_password(password TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN crypt(password, gen_salt('bf'));
END;
$$ LANGUAGE plpgsql;

-- Функция для триггера хеширования паролей
CREATE OR REPLACE FUNCTION hash_password_trigger()
RETURNS TRIGGER AS $$
BEGIN
  NEW.Пароль = hash_password(NEW.Пароль);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера позволяющего хешировать пароли
CREATE TRIGGER trigger_users_hash_password
BEFORE INSERT OR UPDATE ON Пользователи
FOR EACH ROW
EXECUTE FUNCTION hash_password_trigger();