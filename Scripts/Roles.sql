---------------------- Создание ролей ----------------------
CREATE ROLE Администратор;
CREATE ROLE Пользователь;
CREATE ROLE Менеджер;
CREATE ROLE Гость;

-- Grant
-- Admin
GRANT ALL PRIVILEGES ON DATABASE tradex TO Администратор;
GRANT ALL PRIVILEGES ON TABLESPACE Пользователи, Аукционы, Ставки TO Администратор;
GRANT ALL PRIVILEGES ON Пользователи, Аукционы, Ставки, Лоты TO Администратор;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO Администратор;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO Администратор;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO Администратор;


-- User
GRANT CONNECT ON DATABASE tradex TO Пользователь;
GRANT ALL PRIVILEGES ON TABLESPACE Пользователи, Аукционы, Ставки TO Пользователь;
GRANT SELECT, INSERT, UPDATE ON TABLE Пользователи TO Пользователь;
GRANT SELECT, INSERT ON TABLE Аукционы TO Пользователь;
GRANT SELECT, INSERT ON TABLE Лоты TO Пользователь;
GRANT SELECT, INSERT ON TABLE Ставки TO Пользователь;

GRANT SELECT ON num_lots_on_auction TO Пользователь;
GRANT SELECT ON last_bid_for_lot TO Пользователь;
GRANT SELECT ON num_bids_per_user TO Пользователь;
GRANT SELECT ON user_role_and_num_bids TO Пользователь;

GRANT EXECUTE ON FUNCTION authenticate_user TO Пользователь;
GRANT EXECUTE ON FUNCTION create_lot TO Пользователь;
GRANT EXECUTE ON FUNCTION get_lots_list TO Пользователь;
GRANT EXECUTE ON FUNCTION search_lots_by_name TO Пользователь;
GRANT EXECUTE ON FUNCTION get_all_users TO Пользователь;
GRANT EXECUTE ON FUNCTION get_all_auctions TO Пользователь;
GRANT EXECUTE ON FUNCTION get_all_bets TO Пользователь;
GRANT EXECUTE ON FUNCTION get_active_auctions TO Пользователь;
GRANT EXECUTE ON FUNCTION update_auction_status TO Пользователь;
GRANT EXECUTE ON FUNCTION get_max_bid_for_auction TO Пользователь;
GRANT EXECUTE ON FUNCTION get_min_bid_for_auction TO Пользователь;
GRANT EXECUTE ON FUNCTION get_bids_for_lot TO Пользователь;
GRANT EXECUTE ON FUNCTION get_auctions_for_user TO Пользователь;
GRANT EXECUTE ON FUNCTION increase_bid TO Пользователь;
GRANT EXECUTE ON FUNCTION get_auctions_for_user TO Пользователь;
GRANT EXECUTE ON FUNCTION get_users_with_won_lots TO Пользователь;
GRANT EXECUTE ON FUNCTION hash_password TO Пользователь;
GRANT EXECUTE ON FUNCTION hash_password_trigger TO Пользователь;
GRANT EXECUTE ON FUNCTION check_auction_dates TO Пользователь;
GRANT EXECUTE ON FUNCTION check_bid TO Пользователь;
GRANT EXECUTE ON FUNCTION check_auction_status TO Пользователь;
GRANT EXECUTE ON FUNCTION check_duplicate_email TO Пользователь;

GRANT EXECUTE ON PROCEDURE Add_user TO Пользователь;
GRANT EXECUTE ON PROCEDURE delete_user TO Пользователь;
GRANT EXECUTE ON PROCEDURE update_user TO Пользователь;
GRANT EXECUTE ON PROCEDURE create_auction TO Пользователь;
GRANT EXECUTE ON PROCEDURE edit_auction TO Пользователь;
GRANT EXECUTE ON PROCEDURE update_lot TO Пользователь;
GRANT EXECUTE ON PROCEDURE delete_lot TO Пользователь;
GRANT EXECUTE ON PROCEDURE create_bid TO Пользователь;
GRANT EXECUTE ON PROCEDURE delete_bid TO Пользователь;


-- Manager
GRANT CONNECT ON DATABASE tradex TO Менеджер;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "Аукционы", "Лоты" TO Менеджер;
GRANT SELECT, UPDATE, INSERT ON TABLE Пользователи TO Менеджер;

GRANT SELECT ON num_lots_on_auction TO Менеджер;
GRANT SELECT ON last_bid_for_lot TO Менеджер;
GRANT SELECT ON num_bids_per_user TO Менеджер;
GRANT SELECT ON user_role_and_num_bids TO Менеджер;

GRANT EXECUTE ON FUNCTION authenticate_user TO Менеджер;
GRANT EXECUTE ON FUNCTION get_lots_list TO Менеджер;
GRANT EXECUTE ON FUNCTION search_lots_by_name TO Менеджер;
GRANT EXECUTE ON FUNCTION get_all_users TO Менеджер;
GRANT EXECUTE ON FUNCTION get_all_auctions TO Менеджер;
GRANT EXECUTE ON FUNCTION get_all_bets TO Менеджер;
GRANT EXECUTE ON FUNCTION get_active_auctions TO Менеджер;
GRANT EXECUTE ON FUNCTION get_max_bid_for_auction TO Менеджер;
GRANT EXECUTE ON FUNCTION get_min_bid_for_auction TO Менеджер;
GRANT EXECUTE ON FUNCTION get_bids_for_lot TO Менеджер;
GRANT EXECUTE ON FUNCTION get_auctions_for_user TO Менеджер;
GRANT EXECUTE ON FUNCTION get_users_with_won_lots TO Менеджер;
GRANT EXECUTE ON FUNCTION hash_password TO Менеджер;
GRANT EXECUTE ON FUNCTION hash_password_trigger TO Менеджер;
GRANT EXECUTE ON FUNCTION check_auction_dates TO Пользователь;
GRANT EXECUTE ON FUNCTION check_bid TO Пользователь;
GRANT EXECUTE ON FUNCTION check_auction_status TO Пользователь;
GRANT EXECUTE ON FUNCTION check_duplicate_email TO Пользователь;


GRANT EXECUTE ON PROCEDURE update_auction_status TO Менеджер;
GRANT EXECUTE ON PROCEDURE Add_user TO Менеджер;
GRANT EXECUTE ON PROCEDURE update_user TO Менеджер;
GRANT EXECUTE ON PROCEDURE edit_auction TO Менеджер;
GRANT EXECUTE ON PROCEDURE update_lot TO Менеджер;


-- Guest
GRANT CONNECT ON DATABASE tradex TO Гость;
GRANT SELECT ON TABLE "Аукционы", "Лоты", "Ставки" TO Гость;
GRANT SELECT, INSERT ON TABLE Пользователи TO Гость;

GRANT SELECT ON num_lots_on_auction TO Гость;
GRANT SELECT ON last_bid_for_lot TO Гость;
GRANT SELECT ON num_bids_per_user TO Гость;
GRANT SELECT ON user_role_and_num_bids TO Гость;

GRANT EXECUTE ON FUNCTION authenticate_user TO Гость;
GRANT EXECUTE ON FUNCTION hash_password TO Гость;
GRANT EXECUTE ON FUNCTION hash_password_trigger TO Гость;
GRANT EXECUTE ON FUNCTION check_duplicate_email TO Гость;
GRANT EXECUTE ON FUNCTION get_lots_list TO Гость;
GRANT EXECUTE ON FUNCTION search_lots_by_name TO Гость;


GRANT EXECUTE ON PROCEDURE Add_user TO Гость;


CREATE USER admin_user WITH PASSWORD '111';
ALTER ROLE admin_user SET ROLE Администратор;

CREATE USER regular_user WITH PASSWORD '111';
ALTER ROLE regular_user SET ROLE Пользователь;

CREATE USER manager_user WITH PASSWORD '111';
ALTER ROLE manager_user SET ROLE Менеджер;

CREATE USER guest_user WITH PASSWORD '111';
ALTER ROLE guest_user SET ROLE Гость;

drop user admin_user;
drop user regular_user;
drop user manager_user;
drop user guest_user;

SELECT * FROM pg_roles;