# SkyRoute — Enterprise Database Web Application
**CS431 Database Architecture | Ruba Hagog**

---

## Setup Instructions

### 1. Database Setup
Open MySQL and run the setup script:
```sql
source sql/skyroute_setup.sql
```
This creates the `skyroute` database, all 13 tables, and seeds reference data (12 airports, 10 airlines, 10 aircraft, 12 flights, 12 customers, 12 passengers, 10 cards, 12 reservations, 12 tickets, 10 payments).

### 2. Configure DB Connection
Open `server.js` and update the connection block if needed:
```js
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '',       // ← your MySQL password here
  database: 'skyroute',
  ...
});
```

### 3. Install Dependencies
```bash
npm install
```

### 4. Start the Server
```bash
npm start
```

### 5. Open the App
Open your browser and go to:
```
http://localhost:3000
```

---

## Application Features

### SELECT Queries (10 reports)
| Page | Query Description |
|------|-------------------|
| Dashboard | Counts across all major tables + recent reservations |
| Search Flights | Flights with airline, origin, destination, aircraft — filterable by airport and date |
| Reservations | Reservations with customer info and ticket/total aggregation — filterable by customer and status |
| Customers | Customer directory with search |
| Passengers | Passenger list + full travel history per passenger |
| Seat Availability | Seat map and table for a given flight (joins Seat + Ticket to determine availability) |
| Route Summary | Flight count and price stats grouped by airline + route |
| Top Flights | Top 10 flights by tickets sold and revenue |

### INSERT / UPDATE Operations (Bonus)
| Operation | Tables Affected |
|-----------|----------------|
| Register Customer | INSERT INTO Customer |
| Create Reservation | INSERT INTO Reservation |
| Update Reservation Status | UPDATE Reservation |
| Issue Ticket | INSERT INTO Ticket (with seat conflict check) |
| Process Payment | INSERT INTO Payment + UPDATE Reservation status |
| Update Payment Status | UPDATE Payment (for refunds) |

---

## Schema Summary
- **10 strong-entity relations:** Customer, Airline, Airport, Aircraft, Flight, Reservation, Passenger, Payment, Card, Bank_Account
- **2 weak-entity relations:** Ticket, Flight_Leg
- **1 junction table:** Reservation_Flight (M:N between Reservation and Flight)
- **13 relations total**, fully normalised to 3NF

---

## Tech Stack
- **Frontend:** HTML, CSS, JavaScript (vanilla)
- **Backend:** Node.js + Express
- **Database:** MySQL
- **Entry point:** `index.html` (via `http://localhost:3000`)
