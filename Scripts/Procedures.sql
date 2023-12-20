---------------------- Создание процедур ----------------------
-------- Процедуры с пользователями --------
-- Создание пользователей
CREATE OR REPLACE PROCEDURE Add_user (
  "Имя" VARCHAR,
  "Фамилия" VARCHAR,
  "Пароль" VARCHAR,
  "email" VARCHAR,
  "роль" VARCHAR
) AS $$
BEGIN 
  IF "Имя" IS NULL OR "Имя" = '' OR "Фамилия" IS NULL OR "Фамилия" = '' OR "Пароль" IS NULL OR "Пароль" = '' OR "email" IS NULL OR "email" = '' OR "роль" IS NULL OR "роль" = '' THEN
    RAISE EXCEPTION 'Все поля должны быть заполнены';
  END IF;
  IF "Имя" !~ '^[А-Яа-яЁёA-Za-z-]*$' OR "Фамилия" !~ '^[А-Яа-яЁёA-Za-z-]*$' THEN
    RAISE EXCEPTION 'Имя и Фамилия должны содержать только буквы';
  END IF;
  IF "роль" NOT IN ('Администратор', 'Пользователь', 'Менеджер') THEN
    RAISE EXCEPTION 'Роль должна быть либо Администратор, либо Пользователь, либо Менеджер';
  END IF;
  INSERT INTO "Пользователи"("Имя", "Фамилия", "Пароль", "email", "Роль")
  VALUES ("Имя", "Фамилия", "Пароль", "email", "роль");
EXCEPTION WHEN others THEN
  RAISE EXCEPTION 'Произошла ошибка: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Удаление пользователей
CREATE OR REPLACE PROCEDURE delete_user(user_id INT)
AS $$
DECLARE 
    user_exists INT;
BEGIN
    SELECT COUNT(*) INTO user_exists FROM Пользователи WHERE ID_Пользователя = user_id;
    IF user_exists = 0 THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', user_id;
    ELSE
		DELETE FROM Ставки WHERE ID_Пользователя = user_id;
        DELETE FROM Аукционы WHERE ID_Пользователя = user_id;
        DELETE FROM Пользователи WHERE ID_Пользователя = user_id;
        RAISE NOTICE 'Пользователь с ID % успешно удален', user_id;
    END IF;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Редактирование пользователя
CREATE OR REPLACE PROCEDURE update_user(
    user_id INT,
    new_name VARCHAR(50),
    new_last_name VARCHAR,
    new_password VARCHAR(100),
    new_email VARCHAR,
    new_role VARCHAR
)
AS $$
DECLARE
    email_pattern VARCHAR := '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$';
    name_pattern VARCHAR := '^[A-Za-zА-Яа-я]+$';
BEGIN
    IF new_name IS NULL OR new_name = '' OR new_last_name IS NULL OR new_last_name = '' OR new_password IS NULL OR new_password = '' OR new_email IS NULL OR new_email = '' OR new_role IS NULL OR new_role = '' THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены';
    END IF;
    IF new_role NOT IN ('Администратор', 'Пользователь', 'Менеджер') THEN
        RAISE EXCEPTION 'Роль должна быть либо Администратор, либо Пользователь, либо Менеджер';
    END IF;
    IF NOT new_email ~ email_pattern THEN
        RAISE EXCEPTION 'Email должен быть корректным';
    END IF;
    IF NOT new_name ~ name_pattern OR NOT new_last_name ~ name_pattern THEN
        RAISE EXCEPTION 'Имя и фамилия должны быть русскими или английскими символами';
    END IF;
    UPDATE Пользователи 
    SET 
        Имя = new_name,
        Фамилия = new_last_name,
        Пароль = new_password,
        email = new_email,
        Роль = new_role
    WHERE 
        ID_Пользователя = user_id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при обновлении пользователя: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-------- Процедуры с аукционами --------
-- Создание аукциона
CREATE OR REPLACE PROCEDURE create_auction(
    lot_id INT,
    user_id INT,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    start_price NUMERIC(32,2),
    status INT
)
AS $$
DECLARE 
  lot_exists BOOLEAN;
  user_exists BOOLEAN;
  auction_exists BOOLEAN;
BEGIN
    IF lot_id IS NULL OR user_id IS NULL OR start_time IS NULL OR end_time IS NULL OR start_price IS NULL OR status IS NULL THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены';
    END IF;
    IF start_time::text = '' OR end_time::text = '' OR start_price::text = '' OR status::text = '' THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены и не должны быть пустыми строками';
    END IF;
    IF status != 1 THEN
        RAISE EXCEPTION 'Статус должен быть равен 1';
    END IF;
    IF end_time <= NOW() THEN
        RAISE EXCEPTION 'Дата окончания аукциона должна быть больше текущей даты';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Лоты WHERE ID_Лота = lot_id) INTO lot_exists;
    IF NOT lot_exists THEN
        RAISE EXCEPTION 'Лот с ID % не найден', lot_id;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Пользователи WHERE ID_Пользователя = user_id) INTO user_exists;
    IF NOT user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', user_id;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Аукционы WHERE ID_Лота = lot_id) INTO auction_exists;
    IF auction_exists THEN
        RAISE EXCEPTION 'Лот с ID % уже выставлен на аукцион', lot_id;
    END IF;
    INSERT INTO Аукционы (ID_Лота, ID_Пользователя, Дата_Начала_Торгов, Дата_Конца_Торгов, Начальная_цена, Статус)
    VALUES (lot_id, user_id, start_time, end_time, start_price, status);
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при создании аукциона: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Редактирования аукциона
CREATE OR REPLACE PROCEDURE edit_auction(
    _id INT,
    _lot_id INT,
    _user_id INT,
    _start_time TIMESTAMP,
    _end_time TIMESTAMP,
    _start_price NUMERIC(32,2),
    _status INT
)
AS $$
DECLARE 
  lot_exists BOOLEAN;
  user_exists BOOLEAN;
BEGIN
    IF _id IS NULL OR _lot_id IS NULL OR _user_id IS NULL OR _start_time IS NULL OR _end_time IS NULL OR _start_price IS NULL OR _status IS NULL THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены';
    END IF;
    IF _id::text = '' OR _lot_id::text = '' OR _user_id::text = '' OR _start_time::text = '' OR _end_time::text = '' OR _start_price::text = '' OR _status::text = '' THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены и не должны быть пустыми строками';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Лоты WHERE ID_Лота = _lot_id) INTO lot_exists;
    IF NOT lot_exists THEN
        RAISE EXCEPTION 'Лот с ID % не найден', _lot_id;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Пользователи WHERE ID_Пользователя = _user_id) INTO user_exists;
    IF NOT user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', _user_id;
    END IF;
    UPDATE Аукционы
    SET ID_Лота = _lot_id,
        ID_Пользователя = _user_id,
        Дата_Начала_Торгов = _start_time,
        Дата_Конца_Торгов = _end_time,
        Начальная_цена = _start_price,
        Статус = _status
    WHERE ID_аукциона = _id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при редактировании аукциона: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;


-- Удаление аукциона
CREATE OR REPLACE PROCEDURE delete_auction(auction_id INT)
AS $$
DECLARE 
  auction_exists BOOLEAN;
BEGIN
    IF auction_id IS NULL THEN
        RAISE EXCEPTION 'ID аукциона должен быть указан';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Аукционы WHERE ID_аукциона = auction_id) INTO auction_exists;
    IF NOT auction_exists THEN
        RAISE EXCEPTION 'Аукцион с ID % не найден', auction_id;
    END IF;
    DELETE FROM Ставки WHERE ID_аукциона = auction_id;
    DELETE FROM Аукционы WHERE ID_аукциона = auction_id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при удалении аукциона: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

------- Процедуры с лотами --------
-- Редактирование лота
CREATE OR REPLACE PROCEDURE update_lot(
    lot_id INTEGER,
    name VARCHAR(255),
    description VARCHAR,
    image VARCHAR(255)
)
AS $$
DECLARE 
  lot_exists BOOLEAN;
BEGIN
    IF lot_id IS NULL OR name IS NULL OR description IS NULL THEN
        RAISE EXCEPTION 'ID лота, имя и описание должны быть заполнены';
    END IF;
    IF name = '' OR description = '' THEN
        RAISE EXCEPTION 'Имя и описание не должны быть пустыми строками';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Лоты WHERE ID_Лота = lot_id) INTO lot_exists;
    IF NOT lot_exists THEN
        RAISE EXCEPTION 'Лот с ID % не найден', lot_id;
    END IF;
    UPDATE Лоты 
    SET Наименование = name, Описание = description, Изображение = image
    WHERE ID_Лота = lot_id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при редактировании лота: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Удаление лота
CREATE OR REPLACE PROCEDURE delete_lot(
    lot_id INT
)
AS $$
DECLARE 
  lot_exists BOOLEAN;
BEGIN
    IF lot_id IS NULL THEN
        RAISE EXCEPTION 'ID лота должен быть указан';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Лоты WHERE ID_Лота = lot_id) INTO lot_exists;
    IF NOT lot_exists THEN
        RAISE EXCEPTION 'Лот с ID % не найден', lot_id;
    END IF;
    DELETE FROM Лоты WHERE ID_Лота = lot_id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при удалении лота: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

------- Процедуры со ставками --------
-- Создание ставки
CREATE OR REPLACE PROCEDURE create_bid(
    user_id INTEGER,
    bid_amount NUMERIC(32,2),
    bid_time TIMESTAMP WITH TIME ZONE,
    auction_id INTEGER,
    status INTEGER
) LANGUAGE plpgsql AS $$
DECLARE 
  user_exists BOOLEAN;
  auction_exists BOOLEAN;
  auction_owner_id INTEGER;
  start_price NUMERIC(32,2);
  max_bid NUMERIC(32,2);
  auction_end_time TIMESTAMP;
BEGIN
    IF user_id IS NULL OR bid_amount IS NULL OR bid_time IS NULL OR auction_id IS NULL OR status IS NULL THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены';
    END IF;
    IF user_id::text = '' OR bid_amount::text = '' OR bid_time::text = '' OR auction_id::text = '' OR status::text = '' THEN
        RAISE EXCEPTION 'Все поля должны быть заполнены и не должны быть пустыми строками';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Пользователи WHERE ID_Пользователя = user_id) INTO user_exists;
    IF NOT user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID % не найден', user_id;
    END IF;
    SELECT EXISTS(SELECT 1 FROM Аукционы WHERE ID_аукциона = auction_id) INTO auction_exists;
    IF NOT auction_exists THEN
        RAISE EXCEPTION 'Аукцион с ID % не найден', auction_id;
    END IF;
    SELECT ID_Пользователя FROM Аукционы WHERE ID_аукциона = auction_id INTO auction_owner_id;
    IF user_id = auction_owner_id THEN
        RAISE EXCEPTION 'Пользователь не может делать ставки на свой собственный аукцион';
    END IF;
    SELECT Начальная_цена FROM Аукционы WHERE ID_аукциона = auction_id INTO start_price;
    IF bid_amount <= start_price THEN
        RAISE EXCEPTION 'Ставка должна быть равна или больше начальной цены аукциона';
    END IF;
    SELECT MAX(Ставка) FROM Ставки WHERE ID_аукциона = auction_id INTO max_bid;
    IF max_bid IS NOT NULL AND bid_amount <= max_bid THEN
        RAISE EXCEPTION 'Ставка должна быть больше текущей максимальной ставки';
    END IF;
    -- Получаем время окончания аукциона
    SELECT Дата_Конца_Торгов FROM Аукционы WHERE ID_аукциона = auction_id INTO auction_end_time;
    -- Проверяем, что время ставки не превышает время окончания аукциона
    IF bid_time >= auction_end_time THEN
        RAISE EXCEPTION 'Время ставки не может быть больше или равно времени окончания торгов на аукционе';
    END IF;
    INSERT INTO Ставки (ID_Пользователя, Ставка, Время_ставки, Статус, ID_аукциона)
    VALUES (user_id, bid_amount, bid_time, status, auction_id);
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при создании ставки: %', SQLERRM;
END;
$$;

-- Удаление ставки
CREATE OR REPLACE PROCEDURE delete_bid(
    bid_id INTEGER
) LANGUAGE plpgsql AS $$
DECLARE 
  bid_exists BOOLEAN;
BEGIN
    IF bid_id IS NULL THEN
        RAISE EXCEPTION 'ID ставки должен быть указан';
    END IF;
    SELECT EXISTS(SELECT 1 FROM Ставки WHERE ID_Ставки = bid_id) INTO bid_exists;
    IF NOT bid_exists THEN
        RAISE EXCEPTION 'Ставка с ID % не найдена', bid_id;
    END IF;
    DELETE FROM Ставки WHERE ID_Ставки = bid_id;
EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'Произошла ошибка при удалении ставки: %', SQLERRM;
END;
$$;