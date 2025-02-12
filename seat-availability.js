function fillBookingForm(trainId, fromStation, toStation, travelDate) {
  document.getElementById("route_id").value = trainId;
  document.getElementById("from_station_id").value = fromStation;
  document.getElementById("to_station_id").value = toStation;
  document.getElementById("travel_date").value = travelDate;

  document.getElementById("bookingForm").style.display = "block";
  document.getElementById("bookingForm").scrollIntoView({ behavior: "smooth" });
}

function validateBookingForm() {
  const seatsBooked = document.getElementById("seats_booked").value;
  
  if (!seatsBooked || isNaN(seatsBooked) || seatsBooked <= 0) {
    alert("Please enter a valid number of seats.");
    return false;
  }
  return true;
}
