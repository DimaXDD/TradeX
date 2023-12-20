---------------------- Создание Tablespace ----------------------
drop tablespace Пользователи;
drop tablespace Аукционы;
drop tablespace Ставки;

CREATE TABLESPACE Пользователи
  OWNER postgres
  LOCATION 'E:\TradeX\Tablespaces\Users';

CREATE TABLESPACE Аукционы
  OWNER postgres
  LOCATION 'E:\TradeX\Tablespaces\Auctions';
  
CREATE TABLESPACE Ставки
  OWNER postgres
  LOCATION 'E:\TradeX\Tablespaces\Bets';

---------------------- Создание таблиц ----------------------
CREATE TABLE Лоты (
    ID_Лота SERIAL PRIMARY KEY,
    Наименование VARCHAR(255) NOT NULL,
    Описание VARCHAR NOT NULL,
    Изображение VARCHAR(255)
) TABLESPACE Аукционы;

CREATE TABLE Пользователи (
    ID_Пользователя SERIAL PRIMARY KEY,
    Имя VARCHAR(50) NOT NULL,
    Фамилия VARCHAR NOT NULL,
    Пароль VARCHAR(100) NOT NULL,
    email VARCHAR NOT NULL,
    Роль VARCHAR NOT NULL
) TABLESPACE Пользователи;

CREATE TABLE Аукционы (
    ID_аукциона SERIAL PRIMARY KEY,
    ID_Пользователя SERIAL REFERENCES Пользователи(ID_Пользователя),
    Дата_Начала_Торгов TIMESTAMP NOT NULL,
    Дата_Конца_Торгов TIMESTAMP NOT NULL,
    Статус INTEGER,
    ID_Лота SERIAL REFERENCES Лоты(ID_Лота),
    Начальная_цена NUMERIC(32,2) CHECK (Начальная_цена > 0)
) TABLESPACE Аукционы;

CREATE TABLE Ставки (
    ID_Ставки SERIAL PRIMARY KEY,
    ID_Пользователя SERIAL REFERENCES Пользователи(ID_Пользователя),
    Ставка NUMERIC(32,2) CHECK (Ставка > 0), 
    Время_ставки TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Статус INTEGER,
    ID_аукциона SERIAL REFERENCES Аукционы(ID_аукциона)
) TABLESPACE Ставки;

ALTER TABLE Ставки 
ADD CONSTRAINT fk_ID_аукциона FOREIGN KEY (ID_аукциона)
REFERENCES Аукционы(ID_аукциона);

ALTER TABLE Аукционы 
ADD CONSTRAINT fk_id_лот FOREIGN KEY (ID_Лота) 
REFERENCES Лоты (ID_Лота);

ALTER TABLE Аукционы 
ADD CONSTRAINT fk_id_Пользователя FOREIGN KEY (ID_Пользователя) 
REFERENCES Пользователи(ID_Пользователя);

DROP TABLE Ставки CASCADE;
DROP TABLE Аукционы CASCADE;
DROP TABLE Пользователи CASCADE;
DROP TABLE Лоты CASCADE;