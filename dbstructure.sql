-- Stations table to maintain list of all stations
CREATE TABLE stations (
    station_id SERIAL PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    station_code VARCHAR(10) UNIQUE NOT NULL
);

-- Trains table for storing train information
CREATE TABLE trains (
    train_id SERIAL PRIMARY KEY,
    train_number VARCHAR(20) UNIQUE NOT NULL,
    train_name VARCHAR(100) NOT NULL,
    total_seats INTEGER NOT NULL CHECK (total_seats > 0),
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'user'))
);

CREATE TABLE train_routes (
    route_id SERIAL PRIMARY KEY,
    train_id INTEGER REFERENCES trains(train_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- New table for storing route stations with sequence
CREATE TABLE route_stations (
    route_station_id SERIAL PRIMARY KEY,
    route_id INTEGER REFERENCES train_routes(route_id),
    station_id INTEGER REFERENCES stations(station_id),
    sequence_number INTEGER NOT NULL,  -- Order of stations in route
    arrival_time TIME,
    departure_time TIME,
    distance_from_start INTEGER NOT NULL, -- Distance in kilometers from start
    UNIQUE(route_id, station_id),        -- Station appears once in a route
    UNIQUE(route_id, sequence_number)    -- Sequence numbers are unique per route
);


CREATE TABLE seat_availability (
    availability_id SERIAL PRIMARY KEY,
    route_id INTEGER REFERENCES train_routes(route_id),
    from_station_id INTEGER REFERENCES stations(station_id),
    to_station_id INTEGER REFERENCES stations(station_id),
    travel_date DATE NOT NULL,
    available_seats INTEGER NOT NULL CHECK (available_seats >= 0),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, from_station_id, to_station_id, travel_date)
);

-- Modified bookings table to include station pairs
CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    route_id INTEGER REFERENCES train_routes(route_id),
    from_station_id INTEGER REFERENCES stations(station_id),
    to_station_id INTEGER REFERENCES stations(station_id),
    travel_date DATE NOT NULL,
    seats_booked INTEGER NOT NULL CHECK (seats_booked > 0),
    booking_status VARCHAR(20) NOT NULL CHECK (booking_status IN ('confirmed', 'cancelled')),
    booking_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL
);

INSERT INTO users (username, email, phone_number, password_hash, role) VALUES
('admin1', 'admin1@railway.com', '+1234567890', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewfT/y3tTUFm1/uW', 'admin'),
('john_doe', 'john.doe@email.com', '+1234567892', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewfT/y3tTUFm1/uW', 'user'),
('jane_smith', 'jane.smith@email.com', '+1234567893', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewfT/y3tTUFm1/uW', 'user');

-- Insert stations
INSERT INTO stations (station_name, station_code) VALUES
('Mumbai Central', 'MMCT'),
('Surat', 'ST'),
('Vadodara', 'BRC'),
('Ahmedabad', 'ADI'),
('Delhi', 'DLI'),
('Jaipur', 'JP'),
('Kota', 'KOTA'),
('Bhopal', 'BPL');

-- Insert trains
INSERT INTO trains (train_number, train_name, total_seats, created_by) VALUES
('01016', 'Mumbai-Ahmedabad Express', 500, 1),
('02018', 'Delhi-Mumbai Rajdhani', 700, 1),
('03020', 'Gujarat Express', 600, 1);

-- Insert train routes
INSERT INTO train_routes (train_id) VALUES 
(1), -- Mumbai-Ahmedabad Express
(2), -- Delhi-Mumbai Rajdhani
(3); -- Gujarat Express

-- Insert route stations
-- Mumbai-Ahmedabad Express
INSERT INTO route_stations (route_id, station_id, sequence_number, arrival_time, departure_time, distance_from_start) VALUES
(1, 1, 1, NULL, '06:00', 0),        -- Mumbai Central
(1, 2, 2, '08:30', '08:35', 263),   -- Surat
(1, 3, 3, '10:05', '10:10', 392),   -- Vadodara
(1, 4, 4, '11:40', NULL, 491);      -- Ahmedabad

-- Delhi-Mumbai Rajdhani
INSERT INTO route_stations (route_id, station_id, sequence_number, arrival_time, departure_time, distance_from_start) VALUES
(2, 5, 1, NULL, '16:00', 0),        -- Delhi
(2, 6, 2, '18:30', '18:35', 309),   -- Jaipur
(2, 7, 3, '20:05', '20:10', 458),   -- Kota
(2, 8, 4, '23:40', '23:45', 842),   -- Bhopal
(2, 1, 5, '08:00', NULL, 1384);     -- Mumbai Central

-- Gujarat Express
INSERT INTO route_stations (route_id, station_id, sequence_number, arrival_time, departure_time, distance_from_start) VALUES
(3, 4, 1, NULL, '15:00', 0),        -- Ahmedabad
(3, 3, 2, '16:30', '16:35', 99),    -- Vadodara
(3, 2, 3, '18:05', '18:10', 228),   -- Surat
(3, 1, 4, '20:40', NULL, 491);      -- Mumbai Central

-- Insert seat availability for next 7 days
INSERT INTO seat_availability (route_id, from_station_id, to_station_id, travel_date, available_seats)
SELECT 
    r.route_id,
    rs1.station_id as from_station_id,
    rs2.station_id as to_station_id,
    CURRENT_DATE + (i || ' days')::interval as travel_date,
    CASE 
        WHEN r.route_id = 1 THEN 500
        WHEN r.route_id = 2 THEN 700
        ELSE 600
    END as available_seats
FROM train_routes r
CROSS JOIN generate_series(0, 6) i
CROSS JOIN route_stations rs1
CROSS JOIN route_stations rs2
WHERE rs1.route_id = r.route_id 
AND rs2.route_id = r.route_id
AND rs1.sequence_number < rs2.sequence_number;

-- Insert sample bookings
INSERT INTO bookings (user_id, route_id, from_station_id, to_station_id, travel_date, seats_booked, booking_status, total_amount) VALUES
(2, 1, 1, 4, CURRENT_DATE + INTERVAL '1 day', 2, 'confirmed', 1200.00),
(3, 2, 5, 1, CURRENT_DATE + INTERVAL '2 days', 1, 'confirmed', 2500.00),
(2, 3, 4, 1, CURRENT_DATE + INTERVAL '3 days', 3, 'confirmed', 1800.00);

CREATE OR REPLACE FUNCTION book_ticket(
    p_user_id INTEGER,
    p_route_id INTEGER,
    p_from_station_id INTEGER,
    p_to_station_id INTEGER,
    p_travel_date DATE,
    p_seats_booked INTEGER,
    p_total_amount DECIMAL(10,2)
) RETURNS TEXT AS $$
DECLARE
    v_available_seats INTEGER;
BEGIN
    -- Check seat availability
    SELECT available_seats INTO v_available_seats 
    FROM seat_availability
    WHERE route_id = p_route_id 
      AND from_station_id = p_from_station_id 
      AND to_station_id = p_to_station_id
      AND travel_date = p_travel_date;
    
    IF v_available_seats IS NULL THEN
        RETURN 'Error: No seat availability data for the selected route!';
    END IF;
    
    IF v_available_seats < p_seats_booked THEN
        RETURN 'Error: Not enough seats available!';
    END IF;

    -- Insert booking
    INSERT INTO bookings (
        user_id, route_id, from_station_id, to_station_id, travel_date, 
        seats_booked, booking_status, total_amount
    ) VALUES (
        p_user_id, p_route_id, p_from_station_id, p_to_station_id, p_travel_date, 
        p_seats_booked, 'confirmed', p_total_amount
    );

    -- Update seat availability
    UPDATE seat_availability
    SET available_seats = available_seats - p_seats_booked
    WHERE route_id = p_route_id 
      AND from_station_id = p_from_station_id 
      AND to_station_id = p_to_station_id
      AND travel_date = p_travel_date;

    RETURN 'Booking successful!';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION restore_seats_on_cancel() RETURNS TRIGGER AS $$
BEGIN
    -- Restore seats when a booking is canceled
    IF OLD.booking_status = 'confirmed' AND NEW.booking_status = 'cancelled' THEN
        UPDATE seat_availability
        SET available_seats = available_seats + OLD.seats_booked
        WHERE route_id = OLD.route_id 
          AND from_station_id = OLD.from_station_id 
          AND to_station_id = OLD.to_station_id
          AND travel_date = OLD.travel_date;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_restore_seats
AFTER UPDATE ON bookings
FOR EACH ROW
WHEN (NEW.booking_status = 'cancelled')
EXECUTE FUNCTION restore_seats_on_cancel();