from flask import Flask, render_template, redirect, session, request, jsonify
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, auth, firestore
import time
from dash_app import add_dash  # Import the main Dash app
# from google.auth.exceptions import InvalidToken

from firestore_query import get_devices

# Check if Firebase app is already initialized
if not firebase_admin._apps:
    cred = credentials.Certificate("firebase-admin.json")
    firebase_admin.initialize_app(cred)

app = Flask(__name__, static_folder = 'static')
app.secret_key = 'your_secret_key'  # Set a secure secret key

# Firestore database client
db = firestore.client()

# Add Dash to Flask
add_dash(app)


@app.route('/')
@app.route('/login', methods=['GET'])
def login():
    return render_template('login.html')




# POST only route for logging in a user and loading the session data
@app.route('/attempt-login', methods=['POST'])
def try_login():
    id_token = request.json.get('id_token')
    email = request.json.get('email')  # Added for context
    print(f"Received ID Token: {id_token}")
    print(f"Received Email: {email}")

    try:
        # Verify the ID token
        decoded_token = auth.verify_id_token(id_token)

        # Check if token is being used too early due to clock skew
        server_time = int(time.time())  # Current time in seconds
        token_iat = decoded_token.get("iat", 0)  # Issue time of the token
        token_exp = decoded_token.get("exp", 0)  # Expiry time of the token

        print(f"Server Time: {server_time}")
        print(f"Token Issued At: {token_iat}")
        print(f"Token Expires At: {token_exp}")

        # Allow a small clock skew tolerance (e.g., 10 seconds)
        if token_iat > server_time + 100:
            print("Token used too early. Possible clock skew issue.")
            return jsonify({'status': 'error', 'message': 'Token used too early. Check your device time.'}), 401

        if token_exp < server_time:
            print("Token expired.")
            return jsonify({'status': 'error', 'message': 'Token expired. Please re-login.'}), 401
        
        print(f"Decoded Token: {decoded_token}")  # Log decoded token details

        # Store user ID in the session
        session['user_id'] = decoded_token['uid']
        session['user_email'] = email
        session['device_ids'] = []

        print(f"User ID: {session['user_id']} logged in successfully.")
    except firebase_admin.auth.InvalidIdTokenError as e:
        print(f"Invalid ID Token Error: {e}")
        return jsonify({'status': 'error', 'message': 'Invalid ID token'}), 401
    except Exception as e:
        print(f"Exception during token verification: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

    try:
        # Retrieve user devices
        session['device_ids'] = get_devices(session['user_id'])
        if session['device_ids']:
            # Convert the dictionary values to a list and pick the first one.
            device_list = list(session['device_ids'].values())
            session['device_id'] = device_list[0] if device_list else None
        else:
            session['device_id'] = None

        # Set initial query date
        today = datetime.today()
        session['selected_date'] = today.strftime('%m-%d-%Y')
    except Exception as e:
        print(f"Exception while fetching devices: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

    return jsonify({'status': 'success'}), 200


@app.route('/register')
def register():
    return render_template('register.html')

@app.route('/dashboard', methods=['GET', 'POST'])
def dashboard():
    if 'user_id' not in session:
        return redirect('/')

    user_id = session.get('user_id')
    device_id = session.get('device_id')  # Use `.get()` instead of direct access

    if not device_id:
        return render_template('index.html', error="No device ID provided")

    return render_template('index.html', 
                           selected_date=session.get('selected_date', ''), 
                           user_id=user_id, 
                           user_email=session.get('user_email', ''), 
                           device_ids=session.get('device_ids', []))


@app.route('/update-session', methods=['POST'])
def update_session():
    data = request.json  # Get the JSON data sent from the client
    device_id = data.get('device_id')
    date_str = data.get('selected_date')

    # Convert the date string from yyyy-mm-dd to mm-dd-yyyy
    if date_str:
        try:
            # Parse the date in yyyy-mm-dd format
            date_obj = datetime.strptime(date_str, '%Y-%m-%d')
            
            # Reformat the date into mm-dd-yyyy
            formatted_date = date_obj.strftime('%m-%d-%Y')
        except ValueError:
            return jsonify({'status': 'error', 'message': 'Invalid date format'}), 400
    else:
        formatted_date = None

    # Update the session with the new device_id
    if session['device_id'] != device_id or session['selected_date'] != formatted_date:
        session['device_id'] = device_id
        session['selected_date'] = formatted_date
        print("Updated Session Characteristics from HTML")
        print(session)
    
    else:
        print("Session Characteristics did not change")
    return jsonify({'status': 'success', 'device_id': session['device_id']}), 200


@app.route('/settings')
def settings():
    return render_template('settings.html')


@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')

if __name__ == '__main__':
    app.run(debug=True, port=5000)
