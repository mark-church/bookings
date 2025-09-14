
import os
from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from prometheus_flask_exporter import PrometheusMetrics
 

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///bookings.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
metrics = PrometheusMetrics(app)

# --- Database Models ---
class Hotel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    location = db.Column(db.String(100), nullable=False)
    rooms = db.relationship('Room', backref='hotel', lazy=True)

class Room(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    hotel_id = db.Column(db.Integer, db.ForeignKey('hotel.id'), nullable=False)
    number = db.Column(db.String(10), nullable=False)
    type = db.Column(db.String(50), nullable=False)

class Booking(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    room_id = db.Column(db.Integer, db.ForeignKey('room.id'), nullable=False)
    date = db.Column(db.String(20), nullable=False)
    room = db.relationship('Room', backref='bookings')

# --- Routes ---
@app.route('/')
def index():
    hotels = Hotel.query.all()
    return render_template('index.html', hotels=hotels)

@app.route('/hotel/<int:hotel_id>', methods=['GET', 'POST'])
def hotel(hotel_id):
    hotel = Hotel.query.get_or_404(hotel_id)
    if request.method == 'POST':
        room_id = request.form['room_id']
        date = request.form['date']
        new_booking = Booking(room_id=room_id, date=date)
        db.session.add(new_booking)
        db.session.commit()
        return redirect(url_for('bookings'))
    return render_template('hotel.html', hotel=hotel)

@app.route('/bookings')
def bookings():
    all_bookings = Booking.query.all()
    return render_template('bookings.html', bookings=all_bookings)

@app.route('/cancel/<int:booking_id>', methods=['POST'])
def cancel(booking_id):
    booking = Booking.query.get_or_404(booking_id)
    db.session.delete(booking)
    db.session.commit()
    return redirect(url_for('bookings'))

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        # Add some sample data if the database is empty
        if not Hotel.query.first():
            # Hotels
            hotel1 = Hotel(name='Grand Hyatt', location='New York')
            hotel2 = Hotel(name='The Plaza', location='New York')
            hotel3 = Hotel(name='The Ritz-Carlton', location='San Francisco')

            db.session.add_all([hotel1, hotel2, hotel3])
            db.session.commit()

            # Rooms
            room101 = Room(hotel_id=hotel1.id, number='101', type='Standard')
            room102 = Room(hotel_id=hotel1.id, number='102', type='Suite')
            room201 = Room(hotel_id=hotel2.id, number='201', type='Standard')
            room301 = Room(hotel_id=hotel3.id, number='301', type='Deluxe')

            db.session.add_all([room101, room102, room201, room301])
            db.session.commit()
    app.run(debug=True)
