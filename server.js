const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
app.use(cors());
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── DB Connection Pool ────────────────────────────────────────────────────
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'RiRi_Snowy<31301',       // update with your MySQL password
  database: 'skyroute',
  waitForConnections: true,
  connectionLimit: 10
});

// Helper: run query and return rows
async function query(sql, params = []) {
  const [rows] = await pool.execute(sql, params);
  return rows;
}

// ── Health Check ──────────────────────────────────────────────────────────
app.get('/api/health', async (req, res) => {
  try {
    await pool.execute('SELECT 1');
    res.json({ status: 'connected', db: 'skyroute' });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// SELECT QUERIES
// ══════════════════════════════════════════════════════════════════════════

// Q1: All flights with airline, origin, destination, aircraft
app.get('/api/flights', async (req, res) => {
  try {
    const { origin, destination, date } = req.query;
    let sql = `
      SELECT f.flight_id, f.flight_no, f.departure_date,
             a.airline_name, a.airline_code,
             orig.airport_name AS origin_name, orig.city AS origin_city, orig.airport_code AS origin_airport,
             dest.airport_name AS dest_name, dest.city AS dest_city, dest.airport_code AS destination_airport,
             ac.aircraft_type,
             f.departure_time, f.arrival_time, f.base_price
      FROM Flight f
      JOIN Airline a ON f.airline_code = a.airline_code
      JOIN Airport orig ON f.origin_airport = orig.airport_code
      JOIN Airport dest ON f.destination_airport = dest.airport_code
      JOIN Aircraft ac ON f.aircraft_id = ac.aircraft_id
      WHERE 1=1`;
    const params = [];
    if (origin) { sql += ' AND f.origin_airport = ?'; params.push(origin); }
    if (destination) { sql += ' AND f.destination_airport = ?'; params.push(destination); }
    if (date) { sql += ' AND f.departure_date = ?'; params.push(date); }
    sql += ' ORDER BY f.departure_date, f.departure_time';
    const rows = await query(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q2: Customer reservations with status and ticket count
app.get('/api/reservations', async (req, res) => {
  try {
    const { customer_id, status } = req.query;
    let sql = `
      SELECT r.reservation_id, r.booking_date, r.status,
             c.first_name, c.last_name, c.email,
             COUNT(t.ticket_no) AS ticket_count,
             SUM(t.price) AS total_amount
      FROM Reservation r
      JOIN Customer c ON r.customer_id = c.customer_id
      LEFT JOIN Ticket t ON r.reservation_id = t.reservation_id
      WHERE 1=1`;
    const params = [];
    if (customer_id) { sql += ' AND r.customer_id = ?'; params.push(customer_id); }
    if (status) { sql += ' AND r.status = ?'; params.push(status); }
    sql += ' GROUP BY r.reservation_id, r.booking_date, r.status, c.first_name, c.last_name, c.email';
    sql += ' ORDER BY r.booking_date DESC';
    const rows = await query(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q3: Seat availability for a given flight
app.get('/api/seats/:flight_id', async (req, res) => {
  try {
    const { flight_id } = req.params;
    const sql = `
      SELECT s.seat_id, s.seat_no, s.seat_class, s.is_window, s.is_aisle,
             CASE WHEN t.seat_id IS NULL THEN 'Available' ELSE 'Occupied' END AS availability
      FROM Flight f
      JOIN Aircraft ac ON f.aircraft_id = ac.aircraft_id
      JOIN Seat s ON s.aircraft_id = ac.aircraft_id
      LEFT JOIN Ticket t ON t.seat_id = s.seat_id AND t.flight_id = f.flight_id
      WHERE f.flight_id = ?
      ORDER BY s.seat_class, s.seat_no`;
    const rows = await query(sql, [flight_id]);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q4: Passenger travel history
app.get('/api/passengers/:passenger_id/history', async (req, res) => {
  try {
    const { passenger_id } = req.params;
    const sql = `
      SELECT t.ticket_no, t.issue_date, t.fare_class, t.price,
             f.flight_no, f.departure_date,
             orig.city AS from_city, dest.city AS to_city,
             a.airline_name,
             s.seat_no, s.seat_class,
             r.status AS reservation_status
      FROM Ticket t
      JOIN Flight f ON t.flight_id = f.flight_id
      JOIN Airport orig ON f.origin_airport = orig.airport_code
      JOIN Airport dest ON f.destination_airport = dest.airport_code
      JOIN Airline a ON f.airline_code = a.airline_code
      LEFT JOIN Seat s ON t.seat_id = s.seat_id
      JOIN Reservation r ON t.reservation_id = r.reservation_id
      WHERE t.passenger_id = ?
      ORDER BY f.departure_date DESC`;
    const rows = await query(sql, [passenger_id]);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q5: Payment history for a reservation
app.get('/api/payments/:reservation_id', async (req, res) => {
  try {
    const { reservation_id } = req.params;
    const sql = `
      SELECT p.payment_id, p.amount, p.payment_date, p.status,
             c.card_type, c.card_last4, c.card_holder_name
      FROM Payment p
      JOIN Card c ON p.card_id = c.card_id
      WHERE p.reservation_id = ?
      ORDER BY p.payment_date DESC`;
    const rows = await query(sql, [reservation_id]);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q6: Airline route summary - flights per route
app.get('/api/reports/routes', async (req, res) => {
  try {
    const sql = `
      SELECT a.airline_name,
             orig.city AS from_city, orig.airport_code AS from_code,
             dest.city AS to_city, dest.airport_code AS to_code,
             COUNT(f.flight_id) AS total_flights,
             MIN(f.base_price) AS min_price,
             MAX(f.base_price) AS max_price,
             ROUND(AVG(f.base_price), 2) AS avg_price
      FROM Flight f
      JOIN Airline a ON f.airline_code = a.airline_code
      JOIN Airport orig ON f.origin_airport = orig.airport_code
      JOIN Airport dest ON f.destination_airport = dest.airport_code
      GROUP BY a.airline_name, orig.city, orig.airport_code, dest.city, dest.airport_code
      ORDER BY total_flights DESC`;
    const rows = await query(sql, []);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q7: Top booked flights
app.get('/api/reports/top-flights', async (req, res) => {
  try {
    const sql = `
      SELECT f.flight_no, f.departure_date,
             orig.city AS from_city, dest.city AS to_city,
             a.airline_name,
             COUNT(t.ticket_no) AS tickets_sold,
             SUM(t.price) AS revenue
      FROM Flight f
      JOIN Ticket t ON f.flight_id = t.flight_id
      JOIN Airport orig ON f.origin_airport = orig.airport_code
      JOIN Airport dest ON f.destination_airport = dest.airport_code
      JOIN Airline a ON f.airline_code = a.airline_code
      GROUP BY f.flight_id, f.flight_no, f.departure_date, orig.city, dest.city, a.airline_name
      ORDER BY tickets_sold DESC
      LIMIT 10`;
    const rows = await query(sql, []);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q8: All customers
app.get('/api/customers', async (req, res) => {
  try {
    const { search } = req.query;
    let sql = `SELECT customer_id, first_name, last_name, email, phone, city, state FROM Customer WHERE 1=1`;
    const params = [];
    if (search) {
      sql += ' AND (first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    sql += ' ORDER BY last_name, first_name LIMIT 100';
    const rows = await query(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q9: Airports list
app.get('/api/airports', async (req, res) => {
  try {
    const rows = await query('SELECT airport_code, airport_name, city, country FROM Airport ORDER BY city');
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Q10: Passengers list
app.get('/api/passengers', async (req, res) => {
  try {
    const { search } = req.query;
    let sql = `SELECT passenger_id, first_name, last_name, passport_no, nationality FROM Passenger WHERE 1=1`;
    const params = [];
    if (search) {
      sql += ' AND (first_name LIKE ? OR last_name LIKE ? OR passport_no LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    sql += ' ORDER BY last_name LIMIT 100';
    const rows = await query(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ══════════════════════════════════════════════════════════════════════════
// INSERT / UPDATE (BONUS)
// ══════════════════════════════════════════════════════════════════════════

// INSERT: New reservation
app.post('/api/reservations', async (req, res) => {
  try {
    const { customer_id } = req.body;
    if (!customer_id) return res.status(400).json({ success: false, message: 'customer_id required' });
    const result = await query(
      `INSERT INTO Reservation (customer_id, booking_date, status) VALUES (?, NOW(), 'Pending')`,
      [customer_id]
    );
    res.json({ success: true, reservation_id: result.insertId, message: 'Reservation created' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE: Reservation status
app.put('/api/reservations/:reservation_id/status', async (req, res) => {
  try {
    const { reservation_id } = req.params;
    const { status } = req.body;
    const valid = ['Confirmed', 'Cancelled', 'Pending'];
    if (!valid.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
    await query('UPDATE Reservation SET status = ? WHERE reservation_id = ?', [status, reservation_id]);
    res.json({ success: true, message: `Reservation ${reservation_id} updated to ${status}` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// INSERT: New customer
app.post('/api/customers', async (req, res) => {
  try {
    const { first_name, last_name, email, phone, street, city, state, zip, date_of_birth } = req.body;
    if (!first_name || !last_name || !email) {
      return res.status(400).json({ success: false, message: 'first_name, last_name, email required' });
    }
    const existing = await query('SELECT customer_id FROM Customer WHERE email = ?', [email]);
    if (existing.length > 0) return res.status(400).json({ success: false, message: 'Email already registered' });
    const result = await query(
      `INSERT INTO Customer (first_name, last_name, email, phone, street, city, state, zip, date_of_birth)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [first_name, last_name, email, phone || null, street || null, city || null, state || null, zip || null, date_of_birth || null]
    );
    res.json({ success: true, customer_id: result.insertId, message: 'Customer registered' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// INSERT: New passenger
app.post('/api/passengers', async (req, res) => {
  try {
    const { first_name, last_name, date_of_birth, passport_no, nationality } = req.body;
    if (!first_name || !last_name || !date_of_birth) {
      return res.status(400).json({ success: false, message: 'first_name, last_name, date_of_birth required' });
    }
    if (passport_no) {
      const existing = await query('SELECT passenger_id FROM Passenger WHERE passport_no = ?', [passport_no]);
      if (existing.length > 0) return res.status(400).json({ success: false, message: 'Passport number already registered' });
    }
    const result = await query(
      `INSERT INTO Passenger (first_name, last_name, date_of_birth, passport_no, nationality) VALUES (?, ?, ?, ?, ?)`,
      [first_name, last_name, date_of_birth, passport_no || null, nationality || null]
    );
    res.json({ success: true, passenger_id: result.insertId, message: 'Passenger registered' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// INSERT: New ticket (book a seat)
app.post('/api/tickets', async (req, res) => {
  try {
    const { passenger_id, reservation_id, flight_id, seat_id, fare_class, price } = req.body;
    if (!passenger_id || !reservation_id || !flight_id || !price) {
      return res.status(400).json({ success: false, message: 'passenger_id, reservation_id, flight_id, price required' });
    }
    // Check seat not already taken
    if (seat_id) {
      const taken = await query('SELECT ticket_no FROM Ticket WHERE flight_id = ? AND seat_id = ?', [flight_id, seat_id]);
      if (taken.length > 0) return res.status(400).json({ success: false, message: 'Seat already occupied on this flight' });
    }
    // Generate ticket number
    const ticket_no = 'TKT' + Date.now();
    await query(
      `INSERT INTO Ticket (ticket_no, passenger_id, reservation_id, flight_id, seat_id, fare_class, price, issue_date)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())`,
      [ticket_no, passenger_id, reservation_id, flight_id, seat_id || null, fare_class || null, price]
    );
    res.json({ success: true, ticket_no, message: 'Ticket issued successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// INSERT: Payment
app.post('/api/payments', async (req, res) => {
  try {
    const { reservation_id, amount, card_id } = req.body;
    if (!reservation_id || !amount || !card_id) {
      return res.status(400).json({ success: false, message: 'reservation_id, amount, card_id required' });
    }
    const result = await query(
      `INSERT INTO Payment (reservation_id, amount, payment_date, card_id, status) VALUES (?, ?, NOW(), ?, 'Approved')`,
      [reservation_id, amount, card_id]
    );
    // Confirm reservation
    await query(`UPDATE Reservation SET status = 'Confirmed' WHERE reservation_id = ?`, [reservation_id]);
    res.json({ success: true, payment_id: result.insertId, message: 'Payment processed and reservation confirmed' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// UPDATE: Payment status (refund)
app.put('/api/payments/:payment_id/status', async (req, res) => {
  try {
    const { payment_id } = req.params;
    const { status } = req.body;
    const valid = ['Approved', 'Declined', 'Refunded'];
    if (!valid.includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
    await query('UPDATE Payment SET status = ? WHERE payment_id = ?', [status, payment_id]);
    res.json({ success: true, message: `Payment ${payment_id} updated to ${status}` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Serve index.html for all other routes ─────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`SkyRoute server running at http://localhost:${PORT}`);
  console.log('Make sure MySQL is running with database: skyroute');
});
