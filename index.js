require("dotenv").config();
const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { Pool } = require("pg");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const cookieParser = require("cookie-parser");
const path = require("path");

const app = express();

app.use(express.static("public"));
app.set("view engine", "ejs");

app.use(express.urlencoded({ extended: true }));  // This parses URL-encoded data from forms
app.use(express.json());  // This parses incoming JSON payloads

app.set("views", path.join(__dirname, "views"));


app.use(cookieParser());  // Add this line to enable cookie parsing

// const pool = new Pool({
//   user: process.env.DB_USER,
//   host: process.env.DB_HOST,
//   database: process.env.DB_NAME,
//   password: process.env.DB_PASSWORD,
//   port: process.env.DB_PORT,
// });

const pool = new Pool({
  user: 'jman',
  host: 'localhost',
  database: 'irctc_v2',
  password: 'codeword',
  port: 6500
});

pool.connect()
  .then(client => {
    console.log("Connected to the PostgreSQL database!");
    client.release(); // Release the client back to the pool
  })
  .catch(err => {
    console.error("Error connecting to the PostgreSQL database", err.stack);
  });

app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan("dev"));

const SECRET_KEY = 'abc';
const ADMIN_API_KEY = process.env.ADMIN_API_KEY;

// Middleware to verify JWT
const authenticateToken = (req, res, next) => {
  // Get token from either the Authorization header or cookies
  const token = req.cookies.jwt || req.header("Authorization")?.replace("Bearer ", "");

  if (!token) return res.redirect("/login");

  jwt.verify(token, SECRET_KEY, (err, user) => {
    if (err) return res.redirect("/login");
    req.user = user;  // Attach the user object to the request
    next();
  });
};


// Middleware to protect admin endpoints
const authenticateAdmin = (req, res, next) => {
  const apiKey = req.header("x-api-key");
  if (apiKey !== 'go') {
    return res.status(403).json({ message: "Forbidden: Invalid API Key" });
  }
  next();
};

  
  // ✅ **Register Page**
  app.get("/register", (req, res) => {
    res.render("register", { message: null });
  });
  
  app.post("/register", async (req, res) => {
    const { username, email, phone_number, password, role } = req.body;
    console.log(req.body)
    const hashedPassword = await bcrypt.hash(password, 10);
    
      // Store hash in your password DB.
    console.log("Called")
    console.log(username)
    console.log(password)
    console.log(email)
  
    try {
      await pool.query(
        "INSERT INTO users (username, email, phone_number, password_hash, role) VALUES ($1, $2, $3, $4, $5)",
        [username, email, phone_number, hashedPassword, role]
        
      );
      console.log(username)
      res.redirect("/login");
    } catch (error) {
      res.render("register", { message: "Error: " + error.message });
    }


});
  
  // ✅ **Login Page**
  app.get("/login", (req, res) => {
    res.render("login", { message: null });
  });
  
  app.post("/login", async (req, res) => {
    const { email, password } = req.body;
  
    try {
      const user = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
      if (user.rows.length === 0) return res.render("login", { message: "User not found" });
  
      const isValidPassword = await bcrypt.compare(password, user.rows[0].password_hash);
      if (!isValidPassword) return res.render("login", { message: "Invalid password" });
  
      const token = jwt.sign({ userId: user.rows[0].user_id, role: user.rows[0].role }, SECRET_KEY, { expiresIn: "1h" });
      console.log(token)
      // Store JWT in cookie for EJS sessions
      res.cookie("jwt", token, { httpOnly: true, secure: false });  // Use secure: true for HTTPS
      res.redirect("/");
    } catch (error) {
      res.render("login", { message: "Error: " + error.message });
    }
  });
  
  
  // ✅ **Home Page (Protected)**
  app.get("/", authenticateToken, (req, res) => {
    res.render("index", { user: req.user });
  });
  
  // ✅ **Logout (Clear JWT)**
  app.get("/logout", (req, res) => {
    res.clearCookie("jwt");
    res.redirect("/login");
  });

// ✅ 3. Add a New Train (Admin Only)
app.get("/add-train", authenticateAdmin, (req, res) => {
  res.render("add-train", { message: null });
});

app.post("/add-train", authenticateAdmin, async (req, res) => {
  const { train_number, train_name, total_seats } = req.body;
 console.log(req.body)
  try {
    await pool.query(
      "INSERT INTO trains (train_number, train_name, total_seats) VALUES ($1, $2, $3)",
      [train_number, train_name, total_seats]
    );
    res.render("add-train", { message: "Train added successfully!" });
  } catch (error) {
    res.render("add-train", { message: "Error adding train: " + error.message });
  }
});


app.get("/seat-availability", async (req, res) => {
  try {
    // Fetch all stations
    const stationsResult = await pool.query("SELECT * FROM stations");

    // Render the form with stations data
    res.render("seat-availability", { 
      stations: stationsResult.rows, 
      trains: [],  // Pass an empty array for trains initially
      message: null
    });
  } catch (error) {
    res.status(500).json({ message: "Error fetching stations", error: error.message });
  }
});

app.post("/seat-availability", async (req, res) => {
  const { from_station, to_station, travel_date } = req.body;

  if (from_station === to_station) {
    return res.render("seat-availability", {
      stations: [], 
      trains: [], 
      message: "Source and Destination cannot be the same!"
    });
  }

  try {
    // Query to fetch seat availability
    const result = await pool.query(
      "SELECT t.train_id, t.train_name, sa.available_seats FROM seat_availability sa JOIN trains t ON sa.route_id = t.train_id WHERE sa.from_station_id = $1 AND sa.to_station_id = $2 AND sa.travel_date = $3",
      [from_station, to_station, travel_date]
    );

    // If no trains available
    if (result.rows.length === 0) {
      return res.render("seat-availability", {
        stations: [], 
        trains: [], 
        message: "No trains available for this route"
      });
    }

    // Render with trains data
    res.render("seat-availability", {
      stations: [], 
      trains: result.rows,  // Pass the available trains
      message: null
    });
  } catch (error) {
    res.status(500).json({ message: "Error fetching availability", error: error.message });
  }
});


// ✅ 5. Book a Seat (Handles Concurrency)
app.post("/book-seat", authenticateToken, async (req, res) => {
  const { route_id, from_station_id, to_station_id, travel_date, seats_booked } = req.body;
  const user_id = req.user.userId;
  
  try {
    await pool.query("BEGIN"); // Start transaction

    // Lock row to prevent race conditions
    const availability = await pool.query(
      "SELECT available_seats FROM seat_availability WHERE route_id = $1 AND from_station_id = $2 AND to_station_id = $3 AND travel_date = $4 FOR UPDATE",
      [route_id, from_station_id, to_station_id, travel_date]
    );

    if (availability.rows.length === 0 || availability.rows[0].available_seats < seats_booked) {
      await pool.query("ROLLBACK");
      return res.status(400).json({ message: "Not enough seats available" });
    }

    // Reduce available seats
    await pool.query(
      "UPDATE seat_availability SET available_seats = available_seats - $1 WHERE route_id = $2 AND from_station_id = $3 AND to_station_id = $4 AND travel_date = $5",
      [seats_booked, route_id, from_station_id, to_station_id, travel_date]
    );

    // Confirm booking
    await pool.query(
      "INSERT INTO bookings (user_id, route_id, from_station_id, to_station_id, travel_date, seats_booked, booking_status, total_amount) VALUES ($1, $2, $3, $4, $5, $6, 'confirmed', $7)",
      [user_id, route_id, from_station_id, to_station_id, travel_date, seats_booked, seats_booked * 100]
    );

    await pool.query("COMMIT"); // Commit transaction
    res.json({ message: "Booking successful!" });
  } catch (error) {
    await pool.query("ROLLBACK"); // Rollback on error
    res.status(500).json({ message: "Booking failed", error: error.message });
  }
});

// ✅ 6. Get Specific Booking Details
app.get("/booking-details", authenticateToken, async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM bookings WHERE user_id = $1", [req.user.userId]);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ message: "Error fetching bookings", error: error.message });
  }
});

const PORT = 
5001;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
