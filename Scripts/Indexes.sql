---------------------- Создание индексов ----------------------
-- Для таблицы Лоты:
CREATE INDEX idx_наименование ON Лоты (Наименование);
CREATE INDEX idx_описание ON Лоты (Описание);
CREATE INDEX idx_изображение ON Лоты (Изображение);

-- Для таблицы Пользователи:
CREATE INDEX idx_имя ON Пользователи (Имя);
CREATE INDEX idx_фамилия ON Пользователи (Фамилия);
CREATE INDEX idx_email ON Пользователи (email);
CREATE INDEX idx_роль ON Пользователи (Роль);

-- Для таблицы Ставки:
CREATE INDEX idx_id_пользователя ON Ставки (ID_Пользователя);
CREATE INDEX idx_статус ON Ставки (Статус);
CREATE INDEX idx_id_аукциона ON Ставки (ID_аукциона);

-- Для таблицы Аукционы:
CREATE INDEX idx_id_лота ON Аукционы (ID_Лота);
CREATE INDEX idx_начальная_цена ON Аукционы (Начальная_цена);
CREATE INDEX idx_id_пользователя ON Аукционы (ID_Пользователя); -- ?
CREATE INDEX idx_статус ON Аукционы (Статус); -- ?

SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'Аукционы';