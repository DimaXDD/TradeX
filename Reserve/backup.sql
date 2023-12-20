--
-- PostgreSQL database dump
--

-- Dumped from database version 16.0
-- Dumped by pg_dump version 16.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: add_user(character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_user(IN "Имя" character varying, IN "Фамилия" character varying, IN "Пароль" character varying, IN email character varying, IN "роль" character varying)
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER PROCEDURE public.add_user(IN "Имя" character varying, IN "Фамилия" character varying, IN "Пароль" character varying, IN email character varying, IN "роль" character varying) OWNER TO postgres;

--
-- Name: authenticate_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.authenticate_user(input_email character varying, input_password character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.authenticate_user(input_email character varying, input_password character varying) OWNER TO postgres;

--
-- Name: check_auction_dates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_auction_dates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.Дата_Начала_Торгов > NEW.Дата_Конца_Торгов THEN
    RAISE EXCEPTION 'Дата начала торгов не может быть больше даты окончания торгов';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_auction_dates() OWNER TO postgres;

--
-- Name: check_auction_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_auction_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Аукционы WHERE ID_аукциона = NEW.ID_аукциона AND Статус = 0) THEN
        RAISE EXCEPTION 'Ставки на закрытом аукционе запрещены!';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_auction_status() OWNER TO postgres;

--
-- Name: check_bid(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_bid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.check_bid() OWNER TO postgres;

--
-- Name: check_duplicate_email(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_duplicate_email() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (SELECT * FROM Пользователи WHERE email = NEW.email) THEN
        RAISE EXCEPTION 'Пользователь с таким email уже зарегистрирован';
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.check_duplicate_email() OWNER TO postgres;

--
-- Name: create_auction(integer, integer, timestamp without time zone, timestamp without time zone, numeric, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_auction(IN lot_id integer, IN user_id integer, IN start_time timestamp without time zone, IN end_time timestamp without time zone, IN start_price numeric, IN status integer)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.create_auction(IN lot_id integer, IN user_id integer, IN start_time timestamp without time zone, IN end_time timestamp without time zone, IN start_price numeric, IN status integer) OWNER TO postgres;

--
-- Name: create_bid(integer, numeric, timestamp with time zone, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_bid(IN user_id integer, IN bid_amount numeric, IN bid_time timestamp with time zone, IN auction_id integer, IN status integer)
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE public.create_bid(IN user_id integer, IN bid_amount numeric, IN bid_time timestamp with time zone, IN auction_id integer, IN status integer) OWNER TO postgres;

--
-- Name: create_lot(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_lot(_name character varying, _description character varying, _image_path character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.create_lot(_name character varying, _description character varying, _image_path character varying) OWNER TO postgres;

--
-- Name: delete_auction(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_auction(IN auction_id integer)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.delete_auction(IN auction_id integer) OWNER TO postgres;

--
-- Name: delete_bid(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_bid(IN bid_id integer)
    LANGUAGE plpgsql
    AS $$
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


ALTER PROCEDURE public.delete_bid(IN bid_id integer) OWNER TO postgres;

--
-- Name: delete_lot(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_lot(IN lot_id integer)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.delete_lot(IN lot_id integer) OWNER TO postgres;

--
-- Name: delete_user(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_user(IN user_id integer)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.delete_user(IN user_id integer) OWNER TO postgres;

--
-- Name: edit_auction(integer, integer, integer, timestamp without time zone, timestamp without time zone, numeric, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.edit_auction(IN _id integer, IN _lot_id integer, IN _user_id integer, IN _start_time timestamp without time zone, IN _end_time timestamp without time zone, IN _start_price numeric, IN _status integer)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.edit_auction(IN _id integer, IN _lot_id integer, IN _user_id integer, IN _start_time timestamp without time zone, IN _end_time timestamp without time zone, IN _start_price numeric, IN _status integer) OWNER TO postgres;

--
-- Name: end_auction(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.end_auction(auction_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.end_auction(auction_id integer) OWNER TO postgres;

SET default_tablespace = "Аукционы";

SET default_table_access_method = heap;

--
-- Name: Аукционы; Type: TABLE; Schema: public; Owner: postgres; Tablespace: Аукционы
--

CREATE TABLE public."Аукционы" (
    "id_аукциона" integer NOT NULL,
    "id_Пользователя" integer NOT NULL,
    "Дата_Начала_Торгов" timestamp without time zone NOT NULL,
    "Дата_Конца_Торгов" timestamp without time zone NOT NULL,
    "Статус" integer,
    "id_Лота" integer NOT NULL,
    "Начальная_цена" numeric(32,2),
    CONSTRAINT "Аукционы_Начальная_цена_check" CHECK (("Начальная_цена" > (0)::numeric))
);


ALTER TABLE public."Аукционы" OWNER TO postgres;

--
-- Name: get_active_auctions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_active_auctions() RETURNS SETOF public."Аукционы"
    LANGUAGE plpgsql
    AS $$
BEGIN
    CALL update_auction_status();
    RETURN QUERY SELECT * FROM Аукционы WHERE Статус = 1;
EXCEPTION WHEN others THEN
    RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
    RETURN;
END;
$$;


ALTER FUNCTION public.get_active_auctions() OWNER TO postgres;

--
-- Name: get_all_auctions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_auctions() RETURNS SETOF public."Аукционы"
    LANGUAGE plpgsql
    AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Аукционы;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$;


ALTER FUNCTION public.get_all_auctions() OWNER TO postgres;

SET default_tablespace = "Ставки";

--
-- Name: Ставки; Type: TABLE; Schema: public; Owner: postgres; Tablespace: Ставки
--

CREATE TABLE public."Ставки" (
    "id_Ставки" integer NOT NULL,
    "id_Пользователя" integer NOT NULL,
    "Ставка" numeric(32,2),
    "Время_ставки" timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "Статус" integer,
    "id_аукциона" integer NOT NULL,
    CONSTRAINT "Ставки_Ставка_check" CHECK (("Ставка" > (0)::numeric))
);


ALTER TABLE public."Ставки" OWNER TO postgres;

--
-- Name: get_all_bets(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_bets() RETURNS SETOF public."Ставки"
    LANGUAGE plpgsql
    AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Ставки;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$;


ALTER FUNCTION public.get_all_bets() OWNER TO postgres;

SET default_tablespace = "Пользователи";

--
-- Name: Пользователи; Type: TABLE; Schema: public; Owner: postgres; Tablespace: Пользователи
--

CREATE TABLE public."Пользователи" (
    "id_Пользователя" integer NOT NULL,
    "Имя" character varying(50) NOT NULL,
    "Фамилия" character varying NOT NULL,
    "Пароль" character varying(100) NOT NULL,
    email character varying NOT NULL,
    "Роль" character varying NOT NULL
);


ALTER TABLE public."Пользователи" OWNER TO postgres;

--
-- Name: get_all_users(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_users() RETURNS SETOF public."Пользователи"
    LANGUAGE plpgsql
    AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT * FROM Пользователи;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$;


ALTER FUNCTION public.get_all_users() OWNER TO postgres;

--
-- Name: get_auction_winner(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_auction_winner(p_id_auction integer) RETURNS public."Пользователи"
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_auction_winner(p_id_auction integer) OWNER TO postgres;

--
-- Name: get_auctions_for_user(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_auctions_for_user(user_id integer) RETURNS TABLE("id_Аукциона" integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_auctions_for_user(user_id integer) OWNER TO postgres;

--
-- Name: get_bids_for_lot(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_bids_for_lot(lot_id integer) RETURNS TABLE("id_Ставки" integer, "id_Пользователя" integer, "Ставка" numeric, "Время_ставки" timestamp without time zone, "Статус" integer, "id_Аукциона" integer)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_bids_for_lot(lot_id integer) OWNER TO postgres;

--
-- Name: get_lots_list(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_lots_list() RETURNS TABLE(lot_id integer, name character varying, description character varying, image character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT ID_Лота, Наименование, Описание, Изображение FROM Лоты;
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$;


ALTER FUNCTION public.get_lots_list() OWNER TO postgres;

--
-- Name: get_max_bid_for_auction(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_max_bid_for_auction(auction_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_max_bid_for_auction(auction_id integer) OWNER TO postgres;

--
-- Name: get_min_bid_for_auction(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_min_bid_for_auction(auction_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_min_bid_for_auction(auction_id integer) OWNER TO postgres;

--
-- Name: get_users_with_won_lots(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_users_with_won_lots() RETURNS TABLE("id_Пользователя" integer, "Имя_Пользователя" character varying, "id_Лота" integer, "Наименование_Лота" character varying)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.get_users_with_won_lots() OWNER TO postgres;

--
-- Name: hash_password(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.hash_password(password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN crypt(password, gen_salt('bf'));
END;
$$;


ALTER FUNCTION public.hash_password(password text) OWNER TO postgres;

--
-- Name: hash_password_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.hash_password_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.Пароль = hash_password(NEW.Пароль);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.hash_password_trigger() OWNER TO postgres;

--
-- Name: increase_bid(integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.increase_bid(auction_id integer, user_id integer, new_bid numeric) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.increase_bid(auction_id integer, user_id integer, new_bid numeric) OWNER TO postgres;

--
-- Name: insert_lots(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_lots() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
BEGIN
    FOR i IN 1..100000 LOOP
        INSERT INTO Лоты (Наименование, Описание, Изображение)
        VALUES ('Наименование ' || i, 'Описание', 'Изображение');
    END LOOP;
END;
$$;


ALTER FUNCTION public.insert_lots() OWNER TO postgres;

--
-- Name: search_lots_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_lots_by_name(input_name character varying) RETURNS TABLE(lot_id integer, name character varying, description character varying, image character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    BEGIN
        RETURN QUERY SELECT ID_Лота, Наименование, Описание, Изображение FROM Лоты WHERE Наименование ILIKE '%' || input_name || '%';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'Произошла ошибка: %', SQLERRM;
        RETURN;
    END;
END;
$$;


ALTER FUNCTION public.search_lots_by_name(input_name character varying) OWNER TO postgres;

--
-- Name: update_auction_status(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_auction_status()
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE Аукционы SET Статус = 0 WHERE Дата_Конца_Торгов <= NOW() AND Статус = 1;
END;
$$;


ALTER PROCEDURE public.update_auction_status() OWNER TO postgres;

--
-- Name: update_auction_status(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_auction_status(p_id_auction integer, p_new_status integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_auction_status(p_id_auction integer, p_new_status integer) OWNER TO postgres;

--
-- Name: update_lot(integer, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_lot(IN lot_id integer, IN name character varying, IN description character varying, IN image character varying)
    LANGUAGE plpgsql
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
$$;


ALTER PROCEDURE public.update_lot(IN lot_id integer, IN name character varying, IN description character varying, IN image character varying) OWNER TO postgres;

--
-- Name: update_user(integer, character varying, character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_user(IN user_id integer, IN new_name character varying, IN new_last_name character varying, IN new_password character varying, IN new_email character varying, IN new_role character varying)
    LANGUAGE plpgsql
    AS $_$
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
$_$;


ALTER PROCEDURE public.update_user(IN user_id integer, IN new_name character varying, IN new_last_name character varying, IN new_password character varying, IN new_email character varying, IN new_role character varying) OWNER TO postgres;

SET default_tablespace = "Аукционы";

--
-- Name: Лоты; Type: TABLE; Schema: public; Owner: postgres; Tablespace: Аукционы
--

CREATE TABLE public."Лоты" (
    "id_Лота" integer NOT NULL,
    "Наименование" character varying(255) NOT NULL,
    "Описание" character varying NOT NULL,
    "Изображение" character varying(255)
);


ALTER TABLE public."Лоты" OWNER TO postgres;

--
-- Name: last_bid_for_lot; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.last_bid_for_lot AS
 SELECT "Л"."id_Лота",
    "Л"."Наименование",
    s."Ставка",
    s."Время_ставки",
    s."id_Пользователя"
   FROM (public."Лоты" "Л"
     LEFT JOIN public."Ставки" s ON (("Л"."id_Лота" = s."id_аукциона")))
  WHERE (s."id_Ставки" = ( SELECT max("Ставки"."id_Ставки") AS max
           FROM public."Ставки"
          WHERE ("Ставки"."id_аукциона" = "Л"."id_Лота")));


ALTER VIEW public.last_bid_for_lot OWNER TO postgres;

--
-- Name: num_bids_per_user; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.num_bids_per_user AS
 SELECT count(*) AS num_bids,
    "id_Пользователя"
   FROM public."Ставки"
  GROUP BY "id_Пользователя";


ALTER VIEW public.num_bids_per_user OWNER TO postgres;

--
-- Name: num_lots_on_auction; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.num_lots_on_auction AS
 SELECT count(*) AS num_lots,
    "id_аукциона"
   FROM public."Аукционы"
  GROUP BY "id_аукциона";


ALTER VIEW public.num_lots_on_auction OWNER TO postgres;

--
-- Name: user_role_and_num_bids; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_role_and_num_bids AS
 SELECT p."id_Пользователя",
    p."Имя",
    p."Фамилия",
    p."Роль",
    count(*) AS num_bids
   FROM (public."Пользователи" p
     JOIN public."Ставки" s ON ((p."id_Пользователя" = s."id_Пользователя")))
  GROUP BY p."id_Пользователя", p."Имя", p."Фамилия", p."Роль";


ALTER VIEW public.user_role_and_num_bids OWNER TO postgres;

--
-- Name: Аукционы_id_Лота_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Аукционы_id_Лота_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Аукционы_id_Лота_seq" OWNER TO postgres;

--
-- Name: Аукционы_id_Лота_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Аукционы_id_Лота_seq" OWNED BY public."Аукционы"."id_Лота";


--
-- Name: Аукционы_id_Пользователя_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Аукционы_id_Пользователя_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Аукционы_id_Пользователя_seq" OWNER TO postgres;

--
-- Name: Аукционы_id_Пользователя_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Аукционы_id_Пользователя_seq" OWNED BY public."Аукционы"."id_Пользователя";


--
-- Name: Аукционы_id_аукциона_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Аукционы_id_аукциона_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Аукционы_id_аукциона_seq" OWNER TO postgres;

--
-- Name: Аукционы_id_аукциона_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Аукционы_id_аукциона_seq" OWNED BY public."Аукционы"."id_аукциона";


--
-- Name: Лоты_id_Лота_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Лоты_id_Лота_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Лоты_id_Лота_seq" OWNER TO postgres;

--
-- Name: Лоты_id_Лота_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Лоты_id_Лота_seq" OWNED BY public."Лоты"."id_Лота";


--
-- Name: Пользователи_id_Пользователя_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Пользователи_id_Пользователя_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Пользователи_id_Пользователя_seq" OWNER TO postgres;

--
-- Name: Пользователи_id_Пользователя_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Пользователи_id_Пользователя_seq" OWNED BY public."Пользователи"."id_Пользователя";


--
-- Name: Ставки_id_Пользователя_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Ставки_id_Пользователя_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Ставки_id_Пользователя_seq" OWNER TO postgres;

--
-- Name: Ставки_id_Пользователя_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Ставки_id_Пользователя_seq" OWNED BY public."Ставки"."id_Пользователя";


--
-- Name: Ставки_id_Ставки_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Ставки_id_Ставки_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Ставки_id_Ставки_seq" OWNER TO postgres;

--
-- Name: Ставки_id_Ставки_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Ставки_id_Ставки_seq" OWNED BY public."Ставки"."id_Ставки";


--
-- Name: Ставки_id_аукциона_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Ставки_id_аукциона_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Ставки_id_аукциона_seq" OWNER TO postgres;

--
-- Name: Ставки_id_аукциона_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Ставки_id_аукциона_seq" OWNED BY public."Ставки"."id_аукциона";


--
-- Name: Аукционы id_аукциона; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы" ALTER COLUMN "id_аукциона" SET DEFAULT nextval('public."Аукционы_id_аукциона_seq"'::regclass);


--
-- Name: Аукционы id_Пользователя; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы" ALTER COLUMN "id_Пользователя" SET DEFAULT nextval('public."Аукционы_id_Пользователя_seq"'::regclass);


--
-- Name: Аукционы id_Лота; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы" ALTER COLUMN "id_Лота" SET DEFAULT nextval('public."Аукционы_id_Лота_seq"'::regclass);


--
-- Name: Лоты id_Лота; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Лоты" ALTER COLUMN "id_Лота" SET DEFAULT nextval('public."Лоты_id_Лота_seq"'::regclass);


--
-- Name: Пользователи id_Пользователя; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Пользователи" ALTER COLUMN "id_Пользователя" SET DEFAULT nextval('public."Пользователи_id_Пользователя_seq"'::regclass);


--
-- Name: Ставки id_Ставки; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки" ALTER COLUMN "id_Ставки" SET DEFAULT nextval('public."Ставки_id_Ставки_seq"'::regclass);


--
-- Name: Ставки id_Пользователя; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки" ALTER COLUMN "id_Пользователя" SET DEFAULT nextval('public."Ставки_id_Пользователя_seq"'::regclass);


--
-- Name: Ставки id_аукциона; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки" ALTER COLUMN "id_аукциона" SET DEFAULT nextval('public."Ставки_id_аукциона_seq"'::regclass);


--
-- Data for Name: Аукционы; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Аукционы" ("id_аукциона", "id_Пользователя", "Дата_Начала_Торгов", "Дата_Конца_Торгов", "Статус", "id_Лота", "Начальная_цена") FROM stdin;
1	9	2023-12-19 10:00:00	2023-12-19 16:00:00	0	3	800.00
2	9	2023-12-19 10:00:00	2023-12-19 19:00:00	0	2	500.00
\.


--
-- Data for Name: Лоты; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Лоты" ("id_Лота", "Наименование", "Описание", "Изображение") FROM stdin;
1	Mercedes-Benz 300 SLR Uhlenhaut	Раритетный автомобиль 1955 года выпуска	https://www.ixbt.com/img/n1/news/2022/4/5/300SLR_large.jpg
2	Алмаз 9 карат	Нашел алмаз у себя дома	https://s3.eu-central-1.amazonaws.com/img.hromadske.ua/posts/197477/kinardfriendshipcard1jpg/large.jpg
3	Медальон	Нагрудной медальон со времен СССР	https://i.pinimg.com/736x/a5/25/fd/a525fd6e12ecbdb29db602f3c88a6331.jpg
4	Золотая монета	Монета 1801 года в хорошей сохранности	https://static.raritetus.ru/storage/lots/rusnumismat/98/51/248154598.jpg
\.


--
-- Data for Name: Пользователи; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Пользователи" ("id_Пользователя", "Имя", "Фамилия", "Пароль", email, "Роль") FROM stdin;
6	Dmitry	Trubach	$2a$06$1sEu9MQ7VzKHnpvMyPYzEOLC329L8.FZKC.FExDOsR0CguUNRU9N6	dimatruba@mail.ru	Администратор
10	Ilya	Semkin	$2a$06$I4Uq5GTwxlqUFUlFdX89IeI9UHf9jfSHro7zb91by5BKtTtmHloju	semkin123@mail.ru	Пользователь
11	Maksim	Daniletskiy	$2a$06$3DCPc3j32Qtqi0PgzSBh3O3E/gXyfNkM0YFTVh.x2ZlsXF3UhqHzi	maksic321@mail.ru	Пользователь
9	Dmitry	Gaykov	$2a$06$XVz5o0BAnQ90TVfcXzDhzOGYtK7udt//ozBnjKNI8/V/mtX4t.8xa	dmitryg2004@mail.ru	Пользователь
\.


--
-- Data for Name: Ставки; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."Ставки" ("id_Ставки", "id_Пользователя", "Ставка", "Время_ставки", "Статус", "id_аукциона") FROM stdin;
\.


--
-- Name: Аукционы_id_Лота_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Аукционы_id_Лота_seq"', 1, false);


--
-- Name: Аукционы_id_Пользователя_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Аукционы_id_Пользователя_seq"', 1, false);


--
-- Name: Аукционы_id_аукциона_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Аукционы_id_аукциона_seq"', 11, true);


--
-- Name: Лоты_id_Лота_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Лоты_id_Лота_seq"', 4, true);


--
-- Name: Пользователи_id_Пользователя_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Пользователи_id_Пользователя_seq"', 11, true);


--
-- Name: Ставки_id_Пользователя_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Ставки_id_Пользователя_seq"', 1, false);


--
-- Name: Ставки_id_Ставки_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Ставки_id_Ставки_seq"', 6, true);


--
-- Name: Ставки_id_аукциона_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Ставки_id_аукциона_seq"', 1, false);


SET default_tablespace = '';

--
-- Name: Аукционы Аукционы_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы"
    ADD CONSTRAINT "Аукционы_pkey" PRIMARY KEY ("id_аукциона");


--
-- Name: Лоты Лоты_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Лоты"
    ADD CONSTRAINT "Лоты_pkey" PRIMARY KEY ("id_Лота");


--
-- Name: Пользователи Пользователи_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Пользователи"
    ADD CONSTRAINT "Пользователи_pkey" PRIMARY KEY ("id_Пользователя");


--
-- Name: Ставки Ставки_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки"
    ADD CONSTRAINT "Ставки_pkey" PRIMARY KEY ("id_Ставки");


--
-- Name: Аукционы check_auction_dates_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_auction_dates_trigger BEFORE INSERT OR UPDATE ON public."Аукционы" FOR EACH ROW EXECUTE FUNCTION public.check_auction_dates();


--
-- Name: Ставки check_auction_status_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_auction_status_trigger BEFORE INSERT ON public."Ставки" FOR EACH ROW EXECUTE FUNCTION public.check_auction_status();


--
-- Name: Ставки check_bid_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_bid_trigger BEFORE INSERT ON public."Ставки" FOR EACH ROW EXECUTE FUNCTION public.check_bid();


--
-- Name: Пользователи trg_check_duplicate_email; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_duplicate_email BEFORE INSERT ON public."Пользователи" FOR EACH ROW EXECUTE FUNCTION public.check_duplicate_email();


--
-- Name: Пользователи trigger_users_hash_password; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_users_hash_password BEFORE INSERT OR UPDATE ON public."Пользователи" FOR EACH ROW EXECUTE FUNCTION public.hash_password_trigger();


--
-- Name: Аукционы fk_id_Пользователя; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы"
    ADD CONSTRAINT "fk_id_Пользователя" FOREIGN KEY ("id_Пользователя") REFERENCES public."Пользователи"("id_Пользователя");


--
-- Name: Ставки fk_id_аукциона; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки"
    ADD CONSTRAINT "fk_id_аукциона" FOREIGN KEY ("id_аукциона") REFERENCES public."Аукционы"("id_аукциона");


--
-- Name: Аукционы fk_id_лот; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы"
    ADD CONSTRAINT "fk_id_лот" FOREIGN KEY ("id_Лота") REFERENCES public."Лоты"("id_Лота");


--
-- Name: Аукционы Аукционы_id_Лота_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы"
    ADD CONSTRAINT "Аукционы_id_Лота_fkey" FOREIGN KEY ("id_Лота") REFERENCES public."Лоты"("id_Лота");


--
-- Name: Аукционы Аукционы_id_Пользователя_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Аукционы"
    ADD CONSTRAINT "Аукционы_id_Пользователя_fkey" FOREIGN KEY ("id_Пользователя") REFERENCES public."Пользователи"("id_Пользователя");


--
-- Name: Ставки Ставки_id_Пользователя_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки"
    ADD CONSTRAINT "Ставки_id_Пользователя_fkey" FOREIGN KEY ("id_Пользователя") REFERENCES public."Пользователи"("id_Пользователя");


--
-- Name: Ставки Ставки_id_аукциона_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."Ставки"
    ADD CONSTRAINT "Ставки_id_аукциона_fkey" FOREIGN KEY ("id_аукциона") REFERENCES public."Аукционы"("id_аукциона");


--
-- Name: PROCEDURE add_user(IN "Имя" character varying, IN "Фамилия" character varying, IN "Пароль" character varying, IN email character varying, IN "роль" character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.add_user(IN "Имя" character varying, IN "Фамилия" character varying, IN "Пароль" character varying, IN email character varying, IN "роль" character varying) TO "Пользователь";
GRANT ALL ON PROCEDURE public.add_user(IN "Имя" character varying, IN "Фамилия" character varying, IN "Пароль" character varying, IN email character varying, IN "роль" character varying) TO "Гость";


--
-- Name: FUNCTION armor(bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.armor(bytea) TO "Администратор";


--
-- Name: FUNCTION armor(bytea, text[], text[]); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.armor(bytea, text[], text[]) TO "Администратор";


--
-- Name: FUNCTION authenticate_user(input_email character varying, input_password character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.authenticate_user(input_email character varying, input_password character varying) TO "Администратор";
GRANT ALL ON FUNCTION public.authenticate_user(input_email character varying, input_password character varying) TO "Пользователь";
GRANT ALL ON FUNCTION public.authenticate_user(input_email character varying, input_password character varying) TO "Гость";


--
-- Name: FUNCTION check_auction_dates(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_auction_dates() TO "Администратор";
GRANT ALL ON FUNCTION public.check_auction_dates() TO "Пользователь";


--
-- Name: FUNCTION check_auction_status(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_auction_status() TO "Администратор";
GRANT ALL ON FUNCTION public.check_auction_status() TO "Пользователь";


--
-- Name: FUNCTION check_bid(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_bid() TO "Администратор";
GRANT ALL ON FUNCTION public.check_bid() TO "Пользователь";


--
-- Name: FUNCTION check_duplicate_email(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_duplicate_email() TO "Администратор";
GRANT ALL ON FUNCTION public.check_duplicate_email() TO "Пользователь";
GRANT ALL ON FUNCTION public.check_duplicate_email() TO "Гость";


--
-- Name: PROCEDURE create_auction(IN lot_id integer, IN user_id integer, IN start_time timestamp without time zone, IN end_time timestamp without time zone, IN start_price numeric, IN status integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.create_auction(IN lot_id integer, IN user_id integer, IN start_time timestamp without time zone, IN end_time timestamp without time zone, IN start_price numeric, IN status integer) TO "Пользователь";


--
-- Name: PROCEDURE create_bid(IN user_id integer, IN bid_amount numeric, IN bid_time timestamp with time zone, IN auction_id integer, IN status integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.create_bid(IN user_id integer, IN bid_amount numeric, IN bid_time timestamp with time zone, IN auction_id integer, IN status integer) TO "Пользователь";


--
-- Name: FUNCTION create_lot(_name character varying, _description character varying, _image_path character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_lot(_name character varying, _description character varying, _image_path character varying) TO "Администратор";
GRANT ALL ON FUNCTION public.create_lot(_name character varying, _description character varying, _image_path character varying) TO "Пользователь";


--
-- Name: FUNCTION crypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.crypt(text, text) TO "Администратор";


--
-- Name: FUNCTION dearmor(text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.dearmor(text) TO "Администратор";


--
-- Name: FUNCTION decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.decrypt(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION decrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) TO "Администратор";


--
-- Name: PROCEDURE delete_bid(IN bid_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_bid(IN bid_id integer) TO "Пользователь";


--
-- Name: PROCEDURE delete_lot(IN lot_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_lot(IN lot_id integer) TO "Пользователь";


--
-- Name: PROCEDURE delete_user(IN user_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.delete_user(IN user_id integer) TO "Пользователь";


--
-- Name: FUNCTION digest(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.digest(bytea, text) TO "Администратор";


--
-- Name: FUNCTION digest(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.digest(text, text) TO "Администратор";


--
-- Name: PROCEDURE edit_auction(IN _id integer, IN _lot_id integer, IN _user_id integer, IN _start_time timestamp without time zone, IN _end_time timestamp without time zone, IN _start_price numeric, IN _status integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.edit_auction(IN _id integer, IN _lot_id integer, IN _user_id integer, IN _start_time timestamp without time zone, IN _end_time timestamp without time zone, IN _start_price numeric, IN _status integer) TO "Пользователь";


--
-- Name: FUNCTION encrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.encrypt(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION encrypt_iv(bytea, bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION end_auction(auction_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.end_auction(auction_id integer) TO "Администратор";


--
-- Name: FUNCTION gen_random_bytes(integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_random_bytes(integer) TO "Администратор";


--
-- Name: FUNCTION gen_random_uuid(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_random_uuid() TO "Администратор";


--
-- Name: FUNCTION gen_salt(text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_salt(text) TO "Администратор";


--
-- Name: FUNCTION gen_salt(text, integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.gen_salt(text, integer) TO "Администратор";


--
-- Name: TABLE "Аукционы"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Аукционы" TO "Администратор";
GRANT SELECT,INSERT ON TABLE public."Аукционы" TO "Пользователь";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Аукционы" TO "Менеджер";
GRANT SELECT ON TABLE public."Аукционы" TO "Гость";


--
-- Name: FUNCTION get_active_auctions(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_active_auctions() TO "Администратор";
GRANT ALL ON FUNCTION public.get_active_auctions() TO "Пользователь";


--
-- Name: FUNCTION get_all_auctions(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_all_auctions() TO "Администратор";
GRANT ALL ON FUNCTION public.get_all_auctions() TO "Пользователь";


--
-- Name: TABLE "Ставки"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Ставки" TO "Администратор";
GRANT SELECT,INSERT ON TABLE public."Ставки" TO "Пользователь";
GRANT SELECT ON TABLE public."Ставки" TO "Гость";


--
-- Name: FUNCTION get_all_bets(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_all_bets() TO "Администратор";
GRANT ALL ON FUNCTION public.get_all_bets() TO "Пользователь";


--
-- Name: TABLE "Пользователи"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Пользователи" TO "Администратор";
GRANT SELECT,INSERT,UPDATE ON TABLE public."Пользователи" TO "Пользователь";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Пользователи" TO "Менеджер";
GRANT SELECT,INSERT ON TABLE public."Пользователи" TO "Гость";


--
-- Name: FUNCTION get_all_users(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_all_users() TO "Администратор";
GRANT ALL ON FUNCTION public.get_all_users() TO "Пользователь";


--
-- Name: FUNCTION get_auction_winner(p_id_auction integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_auction_winner(p_id_auction integer) TO "Администратор";


--
-- Name: FUNCTION get_auctions_for_user(user_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_auctions_for_user(user_id integer) TO "Администратор";
GRANT ALL ON FUNCTION public.get_auctions_for_user(user_id integer) TO "Пользователь";


--
-- Name: FUNCTION get_bids_for_lot(lot_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_bids_for_lot(lot_id integer) TO "Администратор";
GRANT ALL ON FUNCTION public.get_bids_for_lot(lot_id integer) TO "Пользователь";


--
-- Name: FUNCTION get_lots_list(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_lots_list() TO "Администратор";
GRANT ALL ON FUNCTION public.get_lots_list() TO "Пользователь";
GRANT ALL ON FUNCTION public.get_lots_list() TO "Гость";


--
-- Name: FUNCTION get_max_bid_for_auction(auction_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_max_bid_for_auction(auction_id integer) TO "Администратор";
GRANT ALL ON FUNCTION public.get_max_bid_for_auction(auction_id integer) TO "Пользователь";


--
-- Name: FUNCTION get_min_bid_for_auction(auction_id integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_min_bid_for_auction(auction_id integer) TO "Администратор";
GRANT ALL ON FUNCTION public.get_min_bid_for_auction(auction_id integer) TO "Пользователь";


--
-- Name: FUNCTION get_users_with_won_lots(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_users_with_won_lots() TO "Администратор";
GRANT ALL ON FUNCTION public.get_users_with_won_lots() TO "Пользователь";


--
-- Name: FUNCTION hash_password(password text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hash_password(password text) TO "Администратор";
GRANT ALL ON FUNCTION public.hash_password(password text) TO "Пользователь";
GRANT ALL ON FUNCTION public.hash_password(password text) TO "Гость";


--
-- Name: FUNCTION hash_password_trigger(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hash_password_trigger() TO "Администратор";
GRANT ALL ON FUNCTION public.hash_password_trigger() TO "Пользователь";
GRANT ALL ON FUNCTION public.hash_password_trigger() TO "Гость";


--
-- Name: FUNCTION hmac(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hmac(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION hmac(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.hmac(text, text, text) TO "Администратор";


--
-- Name: FUNCTION increase_bid(auction_id integer, user_id integer, new_bid numeric); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.increase_bid(auction_id integer, user_id integer, new_bid numeric) TO "Администратор";
GRANT ALL ON FUNCTION public.increase_bid(auction_id integer, user_id integer, new_bid numeric) TO "Пользователь";


--
-- Name: FUNCTION insert_lots(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.insert_lots() TO "Администратор";


--
-- Name: FUNCTION pgp_armor_headers(text, OUT key text, OUT value text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text) TO "Администратор";


--
-- Name: FUNCTION pgp_key_id(bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_key_id(bytea) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_decrypt_bytea(bytea, bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_encrypt(text, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) TO "Администратор";


--
-- Name: FUNCTION pgp_pub_encrypt_bytea(bytea, bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_decrypt(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_decrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_encrypt(text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_encrypt(text, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) TO "Администратор";


--
-- Name: FUNCTION pgp_sym_encrypt_bytea(bytea, text, text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) TO "Администратор";


--
-- Name: FUNCTION search_lots_by_name(input_name character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.search_lots_by_name(input_name character varying) TO "Администратор";
GRANT ALL ON FUNCTION public.search_lots_by_name(input_name character varying) TO "Пользователь";
GRANT ALL ON FUNCTION public.search_lots_by_name(input_name character varying) TO "Гость";


--
-- Name: FUNCTION update_auction_status(p_id_auction integer, p_new_status integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_auction_status(p_id_auction integer, p_new_status integer) TO "Администратор";
GRANT ALL ON FUNCTION public.update_auction_status(p_id_auction integer, p_new_status integer) TO "Пользователь";


--
-- Name: PROCEDURE update_lot(IN lot_id integer, IN name character varying, IN description character varying, IN image character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.update_lot(IN lot_id integer, IN name character varying, IN description character varying, IN image character varying) TO "Пользователь";


--
-- Name: PROCEDURE update_user(IN user_id integer, IN new_name character varying, IN new_last_name character varying, IN new_password character varying, IN new_email character varying, IN new_role character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON PROCEDURE public.update_user(IN user_id integer, IN new_name character varying, IN new_last_name character varying, IN new_password character varying, IN new_email character varying, IN new_role character varying) TO "Пользователь";


--
-- Name: TABLE "Лоты"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public."Лоты" TO "Администратор";
GRANT SELECT,INSERT ON TABLE public."Лоты" TO "Пользователь";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public."Лоты" TO "Менеджер";
GRANT SELECT ON TABLE public."Лоты" TO "Гость";


--
-- Name: TABLE last_bid_for_lot; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.last_bid_for_lot TO "Администратор";
GRANT SELECT ON TABLE public.last_bid_for_lot TO "Пользователь";
GRANT SELECT ON TABLE public.last_bid_for_lot TO "Гость";


--
-- Name: TABLE num_bids_per_user; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.num_bids_per_user TO "Администратор";
GRANT SELECT ON TABLE public.num_bids_per_user TO "Пользователь";
GRANT SELECT ON TABLE public.num_bids_per_user TO "Гость";


--
-- Name: TABLE num_lots_on_auction; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.num_lots_on_auction TO "Администратор";
GRANT SELECT ON TABLE public.num_lots_on_auction TO "Пользователь";
GRANT SELECT ON TABLE public.num_lots_on_auction TO "Гость";


--
-- Name: TABLE user_role_and_num_bids; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_role_and_num_bids TO "Администратор";
GRANT SELECT ON TABLE public.user_role_and_num_bids TO "Пользователь";
GRANT SELECT ON TABLE public.user_role_and_num_bids TO "Гость";


--
-- Name: SEQUENCE "Аукционы_id_Лота_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Аукционы_id_Лота_seq" TO "Администратор";


--
-- Name: SEQUENCE "Аукционы_id_Пользователя_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Аукционы_id_Пользователя_seq" TO "Администратор";


--
-- Name: SEQUENCE "Аукционы_id_аукциона_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Аукционы_id_аукциона_seq" TO "Администратор";


--
-- Name: SEQUENCE "Лоты_id_Лота_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Лоты_id_Лота_seq" TO "Администратор";


--
-- Name: SEQUENCE "Пользователи_id_Пользователя_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Пользователи_id_Пользователя_seq" TO "Администратор";


--
-- Name: SEQUENCE "Ставки_id_Пользователя_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Ставки_id_Пользователя_seq" TO "Администратор";


--
-- Name: SEQUENCE "Ставки_id_Ставки_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Ставки_id_Ставки_seq" TO "Администратор";


--
-- Name: SEQUENCE "Ставки_id_аукциона_seq"; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public."Ставки_id_аукциона_seq" TO "Администратор";


--
-- PostgreSQL database dump complete
--

