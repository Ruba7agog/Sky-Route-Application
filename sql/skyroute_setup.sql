-- ============================================================
-- SkyRoute Database Setup
-- CS431 Database Architecture | Ruba Hagog
-- Run this file in MySQL: source skyroute_setup.sql
-- ============================================================

DROP DATABASE IF EXISTS skyroute;
CREATE DATABASE skyroute;
USE skyroute;

-- ── Strong Entities ──────────────────────────────────────────────────────

CREATE TABLE Customer (
  customer_id   INT AUTO_INCREMENT PRIMARY KEY,
  first_name    VARCHAR(50)  NOT NULL,
  last_name     VARCHAR(50)  NOT NULL,
  email         VARCHAR(100) UNIQUE NOT NULL,
  phone         VARCHAR(20),
  street        VARCHAR(100),
  city          VARCHAR(50),
  state         VARCHAR(2),
  zip           VARCHAR(10),
  date_of_birth DATE
);

CREATE TABLE Airport (
  airport_code VARCHAR(3)   PRIMARY KEY,
  airport_name VARCHAR(100) NOT NULL,
  city         VARCHAR(50)  NOT NULL,
  country      VARCHAR(50)  NOT NULL,
  timezone     VARCHAR(50)
);

CREATE TABLE Airline (
  airline_code VARCHAR(3)   PRIMARY KEY,
  airline_name VARCHAR(100) NOT NULL,
  country      VARCHAR(50),
  hub_airport  VARCHAR(3),
  FOREIGN KEY (hub_airport) REFERENCES Airport(airport_code) ON DELETE RESTRICT
);

CREATE TABLE Aircraft (
  aircraft_id   INT AUTO_INCREMENT PRIMARY KEY,
  aircraft_type VARCHAR(50)  UNIQUE NOT NULL,
  manufacturer  VARCHAR(100) NOT NULL,
  total_seats   INT          NOT NULL CHECK (total_seats > 0),
  max_range_km  INT
);

CREATE TABLE Flight (
  flight_id            INT AUTO_INCREMENT PRIMARY KEY,
  flight_no            VARCHAR(10)    NOT NULL,
  departure_date       DATE           NOT NULL,
  airline_code         VARCHAR(3)     NOT NULL,
  origin_airport       VARCHAR(3)     NOT NULL,
  destination_airport  VARCHAR(3)     NOT NULL,
  aircraft_id          INT            NOT NULL,
  departure_time       TIMESTAMP      NOT NULL,
  arrival_time         TIMESTAMP      NOT NULL,
  base_price           DECIMAL(10,2)  NOT NULL CHECK (base_price > 0),
  UNIQUE (flight_no, departure_date),
  FOREIGN KEY (airline_code)        REFERENCES Airline(airline_code)  ON DELETE RESTRICT,
  FOREIGN KEY (origin_airport)      REFERENCES Airport(airport_code)  ON DELETE RESTRICT,
  FOREIGN KEY (destination_airport) REFERENCES Airport(airport_code)  ON DELETE RESTRICT,
  FOREIGN KEY (aircraft_id)         REFERENCES Aircraft(aircraft_id)  ON DELETE RESTRICT
);

CREATE TABLE Reservation (
  reservation_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id    INT          NOT NULL,
  booking_date   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  status         VARCHAR(20)  CHECK (status IN ('Confirmed','Cancelled','Pending')),
  FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE RESTRICT
);

CREATE TABLE Passenger (
  passenger_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name   VARCHAR(50) NOT NULL,
  last_name    VARCHAR(50) NOT NULL,
  date_of_birth DATE       NOT NULL,
  passport_no  VARCHAR(20) UNIQUE,
  nationality  VARCHAR(50)
);

CREATE TABLE Card (
  card_id          INT AUTO_INCREMENT PRIMARY KEY,
  customer_id      INT          NOT NULL,
  card_number_hash VARCHAR(255) NOT NULL,
  card_last4       VARCHAR(4),
  card_holder_name VARCHAR(100) NOT NULL,
  expiration_date  DATE         NOT NULL,
  card_type        VARCHAR(20)  CHECK (card_type IN ('Visa','MasterCard','Amex','Discover')),
  billing_zip      VARCHAR(10),
  FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE RESTRICT
);

CREATE TABLE Bank_Account (
  account_id          INT AUTO_INCREMENT PRIMARY KEY,
  customer_id         INT          NOT NULL,
  routing_number      VARCHAR(9)   NOT NULL,
  account_number_hash VARCHAR(255) NOT NULL,
  account_type        VARCHAR(20)  CHECK (account_type IN ('Checking','Savings')),
  bank_name           VARCHAR(100),
  FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE RESTRICT
);

CREATE TABLE Seat (
  seat_id     INT AUTO_INCREMENT PRIMARY KEY,
  aircraft_id INT          NOT NULL,
  seat_no     VARCHAR(5)   NOT NULL,
  seat_class  VARCHAR(20)  CHECK (seat_class IN ('Economy','Business','First')),
  is_window   BOOLEAN,
  is_aisle    BOOLEAN,
  UNIQUE (aircraft_id, seat_no),
  FOREIGN KEY (aircraft_id) REFERENCES Aircraft(aircraft_id) ON DELETE RESTRICT
);

CREATE TABLE Payment (
  payment_id     INT AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT            NOT NULL,
  amount         DECIMAL(10,2)  NOT NULL CHECK (amount > 0),
  payment_date   TIMESTAMP      DEFAULT CURRENT_TIMESTAMP,
  card_id        INT            NOT NULL,
  status         VARCHAR(20)    CHECK (status IN ('Approved','Declined','Refunded')),
  FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id) ON DELETE RESTRICT,
  FOREIGN KEY (card_id)        REFERENCES Card(card_id)               ON DELETE RESTRICT
);

-- ── Weak Entities ────────────────────────────────────────────────────────

CREATE TABLE Ticket (
  ticket_no      VARCHAR(20)   PRIMARY KEY,
  passenger_id   INT           NOT NULL,
  reservation_id INT           NOT NULL,
  flight_id      INT           NOT NULL,
  seat_id        INT,
  fare_class     VARCHAR(20),
  price          DECIMAL(10,2) NOT NULL,
  issue_date     TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (passenger_id)   REFERENCES Passenger(passenger_id)     ON DELETE CASCADE,
  FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id) ON DELETE RESTRICT,
  FOREIGN KEY (flight_id)      REFERENCES Flight(flight_id)           ON DELETE RESTRICT,
  FOREIGN KEY (seat_id)        REFERENCES Seat(seat_id)               ON DELETE RESTRICT
);

CREATE TABLE Flight_Leg (
  flight_id           INT          NOT NULL,
  leg_no              INT          NOT NULL,
  origin_airport      VARCHAR(3)   NOT NULL,
  destination_airport VARCHAR(3)   NOT NULL,
  departure_time      TIMESTAMP    NOT NULL,
  arrival_time        TIMESTAMP    NOT NULL,
  PRIMARY KEY (flight_id, leg_no),
  FOREIGN KEY (flight_id)           REFERENCES Flight(flight_id)          ON DELETE CASCADE,
  FOREIGN KEY (origin_airport)      REFERENCES Airport(airport_code)      ON DELETE RESTRICT,
  FOREIGN KEY (destination_airport) REFERENCES Airport(airport_code)      ON DELETE RESTRICT
);

-- ── Junction Table ───────────────────────────────────────────────────────

CREATE TABLE Reservation_Flight (
  reservation_id INT NOT NULL,
  flight_id      INT NOT NULL,
  segment_order  INT,
  PRIMARY KEY (reservation_id, flight_id),
  FOREIGN KEY (reservation_id) REFERENCES Reservation(reservation_id) ON DELETE CASCADE,
  FOREIGN KEY (flight_id)      REFERENCES Flight(flight_id)           ON DELETE RESTRICT
);

-- ============================================================
-- SEED DATA (reference tables — at least 10 rows each)
-- ============================================================

INSERT INTO Airport VALUES
  ('SFO','San Francisco International','San Francisco','USA','America/Los_Angeles'),
  ('LAX','Los Angeles International','Los Angeles','USA','America/Los_Angeles'),
  ('JFK','John F. Kennedy International','New York','USA','America/New_York'),
  ('ORD','O\'Hare International','Chicago','USA','America/Chicago'),
  ('DFW','Dallas/Fort Worth International','Dallas','USA','America/Chicago'),
  ('MIA','Miami International','Miami','USA','America/New_York'),
  ('SEA','Seattle-Tacoma International','Seattle','USA','America/Los_Angeles'),
  ('DEN','Denver International','Denver','USA','America/Denver'),
  ('BOS','Logan International','Boston','USA','America/New_York'),
  ('ATL','Hartsfield-Jackson Atlanta International','Atlanta','USA','America/New_York'),
  ('LHR','Heathrow Airport','London','UK','Europe/London'),
  ('CDG','Charles de Gaulle Airport','Paris','France','Europe/Paris');

INSERT INTO Airline VALUES
  ('UAL','United Airlines','USA','ORD'),
  ('AAL','American Airlines','USA','DFW'),
  ('DAL','Delta Air Lines','USA','ATL'),
  ('SWA','Southwest Airlines','USA','DFW'),
  ('BAW','British Airways','UK','LHR'),
  ('AFR','Air France','France','CDG'),
  ('ASA','Alaska Airlines','USA','SEA'),
  ('JBU','JetBlue Airways','USA','JFK'),
  ('FFT','Frontier Airlines','USA','DEN'),
  ('SKW','SkyWest Airlines','USA','SLC');

INSERT INTO Aircraft (aircraft_type, manufacturer, total_seats, max_range_km) VALUES
  ('Boeing 737-800','Boeing',162,5765),
  ('Boeing 757-200','Boeing',200,7250),
  ('Boeing 777-300ER','Boeing',396,13650),
  ('Boeing 787-9 Dreamliner','Boeing',296,14140),
  ('Airbus A320','Airbus',180,6150),
  ('Airbus A321neo','Airbus',194,7400),
  ('Airbus A330-300','Airbus',335,11750),
  ('Airbus A380-800','Airbus',555,15200),
  ('Embraer E175','Embraer',80,3735),
  ('Bombardier CRJ-900','Bombardier',90,2956);

-- Seats for Aircraft 1 (Boeing 737-800, 18 sample seats)
INSERT INTO Seat (aircraft_id, seat_no, seat_class, is_window, is_aisle) VALUES
  (1,'1A','First',1,0),(1,'1B','First',0,0),(1,'1C','First',0,1),
  (1,'10A','Business',1,0),(1,'10B','Business',0,0),(1,'10C','Business',0,1),
  (1,'20A','Economy',1,0),(1,'20B','Economy',0,0),(1,'20C','Economy',0,1),
  (1,'21A','Economy',1,0),(1,'21B','Economy',0,0),(1,'21C','Economy',0,1),
  (1,'30A','Economy',1,0),(1,'30B','Economy',0,0),(1,'30C','Economy',0,1),
  (1,'31A','Economy',1,0),(1,'31B','Economy',0,0),(1,'31C','Economy',0,1);

-- Seats for Aircraft 5 (Airbus A320)
INSERT INTO Seat (aircraft_id, seat_no, seat_class, is_window, is_aisle) VALUES
  (5,'1A','Business',1,0),(5,'1C','Business',0,1),(5,'1D','Business',0,1),(5,'1F','Business',1,0),
  (5,'10A','Economy',1,0),(5,'10B','Economy',0,0),(5,'10C','Economy',0,1),
  (5,'10D','Economy',0,1),(5,'10E','Economy',0,0),(5,'10F','Economy',1,0),
  (5,'20A','Economy',1,0),(5,'20B','Economy',0,0),(5,'20C','Economy',0,1),
  (5,'20D','Economy',0,1),(5,'20E','Economy',0,0),(5,'20F','Economy',1,0);

-- Flights
INSERT INTO Flight (flight_no, departure_date, airline_code, origin_airport, destination_airport, aircraft_id, departure_time, arrival_time, base_price) VALUES
  ('UA118','2025-06-15','UAL','SFO','JFK',1,'2025-06-15 08:00:00','2025-06-15 16:30:00',289.00),
  ('UA200','2025-06-15','UAL','JFK','ORD',1,'2025-06-15 18:00:00','2025-06-15 20:15:00',149.00),
  ('AA305','2025-06-16','AAL','LAX','MIA',5,'2025-06-16 07:30:00','2025-06-16 16:00:00',219.00),
  ('DL410','2025-06-16','DAL','ATL','BOS',1,'2025-06-16 09:00:00','2025-06-16 12:45:00',179.00),
  ('UA501','2025-06-17','UAL','ORD','DEN',5,'2025-06-17 11:00:00','2025-06-17 12:30:00',129.00),
  ('AA601','2025-06-17','AAL','DFW','SEA',5,'2025-06-17 14:00:00','2025-06-17 16:45:00',199.00),
  ('BA001','2025-06-18','BAW','JFK','LHR',3,'2025-06-18 21:00:00','2025-06-19 09:00:00',599.00),
  ('AF077','2025-06-18','AFR','JFK','CDG',3,'2025-06-18 22:30:00','2025-06-19 11:45:00',649.00),
  ('AS220','2025-06-19','ASA','SEA','SFO',5,'2025-06-19 06:00:00','2025-06-19 08:15:00',109.00),
  ('JB800','2025-06-19','JBU','BOS','JFK',5,'2025-06-19 10:00:00','2025-06-19 11:05:00',89.00),
  ('UA118','2025-06-20','UAL','SFO','JFK',1,'2025-06-20 08:00:00','2025-06-20 16:30:00',299.00),
  ('DL500','2025-06-20','DAL','LAX','ATL',5,'2025-06-20 10:30:00','2025-06-20 18:00:00',239.00);

-- Customers
INSERT INTO Customer (first_name, last_name, email, phone, street, city, state, zip, date_of_birth) VALUES
  ('James','Carter','james.carter@email.com','415-555-0101','12 Oak St','San Francisco','CA','94102','1985-03-14'),
  ('Sofia','Nguyen','sofia.nguyen@email.com','213-555-0202','88 Palm Ave','Los Angeles','CA','90001','1990-07-22'),
  ('Marcus','Williams','marcus.w@email.com','212-555-0303','45 Broadway','New York','NY','10001','1978-11-05'),
  ('Elena','Rodriguez','elena.r@email.com','312-555-0404','200 Michigan Ave','Chicago','IL','60601','1995-02-28'),
  ('David','Kim','david.kim@email.com','972-555-0505','9 Commerce St','Dallas','TX','75201','1988-06-17'),
  ('Priya','Patel','priya.p@email.com','305-555-0606','1 Biscayne Blvd','Miami','FL','33101','1993-09-30'),
  ('Tyler','Johnson','tyler.j@email.com','206-555-0707','500 Pine St','Seattle','WA','98101','1982-12-03'),
  ('Aisha','Brown','aisha.b@email.com','720-555-0808','300 16th St','Denver','CO','80202','1997-04-11'),
  ('Michael','Lee','m.lee@email.com','617-555-0909','75 State St','Boston','MA','02109','1975-08-19'),
  ('Natalie','Davis','natalie.d@email.com','404-555-1010','100 Peachtree St','Atlanta','GA','30301','1991-01-25'),
  ('Ryan','Thompson','ryan.t@email.com','415-555-1111','50 Market St','San Francisco','CA','94105','1986-05-08'),
  ('Zoe','Martinez','zoe.m@email.com','818-555-1212','77 Sunset Blvd','Los Angeles','CA','90028','1994-10-16');

-- Passengers
INSERT INTO Passenger (first_name, last_name, date_of_birth, passport_no, nationality) VALUES
  ('James','Carter','1985-03-14','US123456789','American'),
  ('Sofia','Nguyen','1990-07-22','US987654321','American'),
  ('Marcus','Williams','1978-11-05','US111222333','American'),
  ('Elena','Rodriguez','1995-02-28','US444555666','American'),
  ('David','Kim','1988-06-17','US777888999','American'),
  ('Priya','Patel','1993-09-30','IN100200300','Indian'),
  ('Tyler','Johnson','1982-12-03','US400500600','American'),
  ('Aisha','Brown','1997-04-11','US700800900','American'),
  ('Michael','Lee','1975-08-19','US010203040','American'),
  ('Natalie','Davis','1991-01-25','US050607080','American'),
  ('Liam','Walker','2001-06-30','US090001002','American'),
  ('Emma','Hall','1998-12-12','UK556677889','British');

-- Cards
INSERT INTO Card (customer_id, card_number_hash, card_last4, card_holder_name, expiration_date, card_type, billing_zip) VALUES
  (1,'$2b$10$hashedvalue1111','4242','James Carter','2027-12-01','Visa','94102'),
  (2,'$2b$10$hashedvalue2222','1234','Sofia Nguyen','2026-08-01','MasterCard','90001'),
  (3,'$2b$10$hashedvalue3333','5678','Marcus Williams','2028-03-01','Amex','10001'),
  (4,'$2b$10$hashedvalue4444','9012','Elena Rodriguez','2026-11-01','Visa','60601'),
  (5,'$2b$10$hashedvalue5555','3456','David Kim','2027-05-01','Discover','75201'),
  (6,'$2b$10$hashedvalue6666','7890','Priya Patel','2025-09-01','Visa','33101'),
  (7,'$2b$10$hashedvalue7777','2345','Tyler Johnson','2028-01-01','MasterCard','98101'),
  (8,'$2b$10$hashedvalue8888','6789','Aisha Brown','2026-07-01','Visa','80202'),
  (9,'$2b$10$hashedvalue9999','0123','Michael Lee','2027-10-01','Amex','02109'),
  (10,'$2b$10$hashedvalueAAAA','4567','Natalie Davis','2025-12-01','Visa','30301');

-- Reservations
INSERT INTO Reservation (customer_id, booking_date, status) VALUES
  (1,'2025-05-01 10:00:00','Confirmed'),
  (2,'2025-05-02 11:30:00','Confirmed'),
  (3,'2025-05-03 09:15:00','Pending'),
  (4,'2025-05-04 14:00:00','Confirmed'),
  (5,'2025-05-05 16:45:00','Cancelled'),
  (6,'2025-05-06 08:30:00','Confirmed'),
  (7,'2025-05-07 12:00:00','Confirmed'),
  (8,'2025-05-08 17:30:00','Pending'),
  (9,'2025-05-09 10:45:00','Confirmed'),
  (10,'2025-05-10 13:15:00','Confirmed'),
  (1,'2025-05-11 09:00:00','Confirmed'),
  (3,'2025-05-12 15:30:00','Pending');

-- Tickets
INSERT INTO Ticket (ticket_no, passenger_id, reservation_id, flight_id, seat_id, fare_class, price, issue_date) VALUES
  ('TKT001',1,1,1,1,'First',589.00,'2025-05-01 10:05:00'),
  ('TKT002',2,2,3,5,'Business',419.00,'2025-05-02 11:35:00'),
  ('TKT003',3,3,7,NULL,'Economy',599.00,'2025-05-03 09:20:00'),
  ('TKT004',4,4,4,10,'Economy',179.00,'2025-05-04 14:05:00'),
  ('TKT005',5,5,5,19,'Economy',129.00,'2025-05-05 16:50:00'),
  ('TKT006',6,6,8,NULL,'Economy',649.00,'2025-05-06 08:35:00'),
  ('TKT007',7,7,9,20,'Economy',109.00,'2025-05-07 12:05:00'),
  ('TKT008',8,8,10,21,'Economy',89.00,'2025-05-08 17:35:00'),
  ('TKT009',9,9,1,2,'Business',389.00,'2025-05-09 10:50:00'),
  ('TKT010',10,10,2,4,'Economy',149.00,'2025-05-10 13:20:00'),
  ('TKT011',1,11,11,7,'Economy',299.00,'2025-05-11 09:05:00'),
  ('TKT012',3,12,4,NULL,'Economy',179.00,'2025-05-12 15:35:00');

-- Payments
INSERT INTO Payment (reservation_id, amount, payment_date, card_id, status) VALUES
  (1,589.00,'2025-05-01 10:06:00',1,'Approved'),
  (2,419.00,'2025-05-02 11:36:00',2,'Approved'),
  (4,179.00,'2025-05-04 14:06:00',4,'Approved'),
  (5,129.00,'2025-05-05 16:51:00',5,'Refunded'),
  (6,649.00,'2025-05-06 08:36:00',6,'Approved'),
  (7,109.00,'2025-05-07 12:06:00',7,'Approved'),
  (9,389.00,'2025-05-09 10:51:00',9,'Approved'),
  (10,149.00,'2025-05-10 13:21:00',10,'Approved'),
  (11,299.00,'2025-05-11 09:06:00',1,'Approved'),
  (1,50.00,'2025-05-15 14:00:00',1,'Approved');

-- Reservation_Flight junction
INSERT INTO Reservation_Flight (reservation_id, flight_id, segment_order) VALUES
  (1,1,1),(2,3,1),(3,7,1),(4,4,1),(5,5,1),
  (6,8,1),(7,9,1),(8,10,1),(9,1,1),(10,2,1),
  (11,11,1),(12,4,1);

SELECT 'SkyRoute database setup complete.' AS message;
