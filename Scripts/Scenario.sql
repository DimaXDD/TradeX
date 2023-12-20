SELECT * FROM get_lots_list();
SELECT * FROM search_lots_by_name('золотая');


CALL Add_user ('Dmitry', 'Trubach', 'admin', 'dimatruba@mail.ru', 'Администратор');
CALL Add_user ('Ilya', 'Semkin', 'pass123', 'semkin123@mail.ru', 'Пользователь');
CALL Add_user ('Maksim', 'Daniletskiy', 'pass321', 'maksic321@mail.ru', 'Пользователь');
CALL Add_user ('Dmitry', 'Gaykov', 'dimas123', 'dmitryg2004@mail.ru', 'Пользователь');
CALL Add_user ('Andrey', 'Korenchyk', 'andrey123', 'andr@mail.ru', 'Пользователь');

select id_Пользователя from Пользователи where email = 'dmitryg2004@mail.ru'
SELECT * FROM get_all_users();

select authenticate_user('dmitryg2004@mail.ru', 'dimas123')
select authenticate_user('semkin123@mail.ru', 'pass123')


SELECT create_lot('Mercedes-Benz 300 SLR Uhlenhaut', 
				  'Раритетный автомобиль 1955 года выпуска', 
				  'https://www.ixbt.com/img/n1/news/2022/4/5/300SLR_large.jpg');
				 
SELECT create_lot('Алмаз 9 карат', 
				  'Нашел алмаз у себя дома', 
				  'https://s3.eu-central-1.amazonaws.com/img.hromadske.ua/posts/197477/kinardfriendshipcard1jpg/large.jpg');

SELECT create_lot('Медальон', 
				  'Нагрудной медальон со времен СССР', 
				  'https://i.pinimg.com/736x/a5/25/fd/a525fd6e12ecbdb29db602f3c88a6331.jpg');
				  
SELECT create_lot('Золотая монета', 
				  'Монета 1801 года в хорошей сохранности', 
				  'https://static.raritetus.ru/storage/lots/rusnumismat/98/51/248154598.jpg');
				  				  
				  
SELECT * FROM get_lots_list();


-- (lot_id, user_id, start, finish, start_price, status)
CALL create_auction(4, 10, '2023-12-20 10:00:00', '2023-12-20 20:30:00', 800.00, 1);

SELECT * FROM get_active_auctions();
SELECT * FROM get_all_auctions();
select * from Пользователи;
select * from Лоты;

-- потом, другой пользователь хочет поучавствовать в аукционе
-- для начала он смотрит, какие аукционы активны
SELECT * FROM get_active_auctions();

-- (user_id, bid, time, id_auc, status)
CALL create_bid(9, 200.00, CURRENT_TIMESTAMP, 1, 1);
CALL create_bid(8, 200.00, CURRENT_TIMESTAMP, 1, 1);
CALL create_bid(9, 1000.00, CURRENT_TIMESTAMP, 8, 1);
SELECT * FROM Ставки;

-- другой пользователь увидел этот аукцион и принялся учавствовать в нем
CALL create_bid(7, 900.00, CURRENT_TIMESTAMP, 1, 1);
CALL create_bid(7, 1100.00, CURRENT_TIMESTAMP, 1, 1);
SELECT * FROM Ставки;

-- далее будет идти "битва" за этот аук
-- (id_auc, id_user, bid)
SELECT increase_bid(1, 6, 500.00); -- error
SELECT increase_bid(1, 7, 500.00);
SELECT increase_bid(1, 8, 950.00);
SELECT * FROM Ставки;

SELECT * FROM get_auction_winner(8);

SELECT * FROM get_bids_for_lot(2);

SELECT get_max_bid_for_auction(1);
SELECT get_min_bid_for_auction(1);


-- (id_auc, status)
SELECT update_auction_status(5, 0);
SELECT end_auction(1); -- для админа

SELECT * FROM get_active_auctions();
SELECT * FROM get_all_auctions();
SELECT * FROM get_auction_winner(5);
SELECT * FROM get_users_with_won_lots();

-- теперь статус аукциона CLOSED и делать ставки больше нельзя
SELECT increase_bid(1, 7, 1050.00);

CALL delete_auction(11);

CALL update_user(9, 'Dmitry', 'Gaykov', 'dimas123', 'dmitryg2004@mail.ru', 'Пользователь');
