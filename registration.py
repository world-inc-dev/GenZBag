import sqlite3
import hashlib
import secrets
import re
import html

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

DB = "users.db"
router = APIRouter()


class RegistrationData(BaseModel):
    username: str = Field(min_length=3, max_length=30)
    email: str = Field(min_length=5, max_length=254)
    phone: str = Field(min_length=7, max_length=20)
    country: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=10, max_length=128)
    confirm_password: str
    referral_code: str
    terms: bool


def hash_password(password, salt):
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode(),
        bytes.fromhex(salt),
        310000
    ).hex()


@router.get("/register/{referral_code}", response_class=HTMLResponse)
def registration_page(referral_code: str):

    if not re.fullmatch(r"[a-z0-9_]{3,30}", referral_code):
        raise HTTPException(404, "Invalid referral link")

    with sqlite3.connect(DB) as db:
        inviter = db.execute("""
            SELECT username
            FROM users
            JOIN profiles ON users.id = profiles.user_id
            WHERE profiles.referral_code = ?
        """, (referral_code,)).fetchone()

    if not inviter:
        raise HTTPException(404, "Referral link not found")

    inviter_name = html.escape(inviter[0])

    return f"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Join GenZBag</title>

<style>
* {{ box-sizing: border-box; }}

body {{
    margin: 0;
    padding: 25px 15px;
    background: #081723;
    font-family: Arial, sans-serif;
    color: #172b42;
}}

.card {{
    max-width: 480px;
    margin: 20px auto;
    padding: 30px;
    background: white;
    border-radius: 18px;
    box-shadow: 0 12px 40px #0005;
}}

.logo {{
    text-align: center;
    font-size: 29px;
    font-weight: bold;
    color: #087de0;
}}

.tagline {{
    text-align: center;
    color: #64748b;
    margin-bottom: 28px;
}}

h2 {{
    text-align: center;
    margin-bottom: 8px;
}}

.subtitle {{
    text-align: center;
    color: #64748b;
    font-size: 14px;
    margin-bottom: 25px;
}}

label {{
    display: block;
    font-size: 13px;
    font-weight: bold;
    margin: 14px 0 7px;
}}

input, select {{
    width: 100%;
    padding: 13px;
    border: 1px solid #d5deea;
    border-radius: 9px;
    font-size: 15px;
    background: white;
}}

input:focus, select:focus {{
    outline: 2px solid #087de0;
}}

button {{
    width: 100%;
    padding: 14px;
    margin-top: 22px;
    border: none;
    border-radius: 9px;
    background: #087de0;
    color: white;
    font-size: 16px;
    font-weight: bold;
    cursor: pointer;
}}

button:disabled {{
    opacity: .6;
    cursor: wait;
}}

.inviter {{
    padding: 12px;
    background: #eaf4ff;
    border-radius: 9px;
    color: #0759a5;
    font-size: 14px;
}}

.message {{
    margin-top: 15px;
    font-size: 14px;
    text-align: center;
}}

.signin {{
    text-align: center;
    margin-top: 20px;
    font-size: 14px;
}}

.signin a {{
    color: #087de0;
    text-decoration: none;
}}

small {{
    color: #64748b;
}}
</style>
</head>

<body>
<div class="card">

<div class="logo">GENZBAG</div>
<div class="tagline">Earn Smart. Grow Together.</div>

<h2>Create Your Account</h2>
<div class="subtitle">
Join GenZBag and explore available opportunities.
</div>

<form id="registerForm">

<label>Username</label>
<input name="username" required minlength="3"
maxlength="30" pattern="[a-zA-Z0-9_]+"
placeholder="Choose a username">

<label>Email</label>
<input name="email" type="email" required
placeholder="Enter your email">

<label>Mobile Number</label>
<input name="phone" type="tel" required
placeholder="+256 7XXXXXXXX">

<label>Password</label>
<input name="password" type="password"
required minlength="10" maxlength="128">

<label>Confirm Password</label>
<input name="confirm_password" type="password"
required minlength="10" maxlength="128">

<label>Country</label>
<input name="country" list="countries"
placeholder="Select or type your country" required>

<datalist id="countries">
<option value="Uganda">
<option value="Kenya">
<option value="Tanzania">
<option value="Rwanda">
<option value="South Sudan">
<option value="Nigeria">
<option value="Ghana">
<option value="South Africa">
<option value="United States">
<option value="United Kingdom">
<option value="Canada">
<option value="India">
<option value="Australia">
<option value="Germany">
<option value="France">
<option value="Singapore">
<option value="Zambia">
<option value="Malawi">
<option value="Ethiopia">
<option value="Somalia">
</datalist>

<label>Invited By</label>
<div class="inviter">
{inviter_name}
</div>

<br>

<label>
<input type="checkbox" name="terms"
style="width:auto" required>
I agree to the Terms & Conditions.
</label>

<input type="hidden" name="referral_code"
value="{referral_code}">

<button type="submit" id="submitBtn">
Create Account
</button>

<div class="message" id="message"></div>

</form>

<div class="signin">
Already have an account?
<a href="/login">Sign in here</a>
</div>

</div>

<script>
const form = document.getElementById("registerForm");

form.addEventListener("submit", async function(event) {{
    event.preventDefault();

    const data = Object.fromEntries(
        new FormData(form).entries()
    );

    data.terms = form.elements.terms.checked;

    const message = document.getElementById("message");
    const button = document.getElementById("submitBtn");

    if (data.password !== data.confirm_password) {{
        message.textContent = "Passwords do not match.";
        return;
    }}

    button.disabled = true;
    button.textContent = "Creating account...";

    try {{
        const response = await fetch("/api/register", {{
            method: "POST",
            headers: {{
                "Content-Type": "application/json"
            }},
            body: JSON.stringify(data)
        }});

        const result = await response.json();

        if (!response.ok) {{
            throw new Error(result.detail || "Registration failed.");
        }}

        message.textContent = result.message + " Redirecting to sign in...";
        form.reset();

        setTimeout(() => {{
            window.location.href = "/login?registered=1";
        }}, 1200);

    }} catch (error) {{
        message.textContent = error.message;
    }} finally {{
        button.disabled = false;
        button.textContent = "Create Account";
    }}
}});
</script>

</body>
</html>
"""


@router.post("/api/register")
def register_user(data: RegistrationData):

    username = data.username.strip().lower()
    email = data.email.strip().lower()
    phone = data.phone.strip()
    country = data.country.strip()
    referral_code = data.referral_code.strip().lower()

    if not re.fullmatch(r"[a-z0-9_]{3,30}", username):
        raise HTTPException(400, "Invalid username.")

    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
        raise HTTPException(400, "Invalid email address.")

    if not re.fullmatch(r"\+?[0-9\s-]{7,20}", phone):
        raise HTTPException(400, "Invalid mobile number.")

    if not data.terms:
        raise HTTPException(400, "Please accept the Terms & Conditions.")

    if data.password != data.confirm_password:
        raise HTTPException(400, "Passwords do not match.")

    if not re.fullmatch(r"[a-z0-9_]{3,30}", referral_code):
        raise HTTPException(400, "Invalid referral code.")

    salt = secrets.token_hex(16)
    password_hash = hash_password(data.password, salt)

    try:
        with sqlite3.connect(DB) as db:
            db.execute("PRAGMA foreign_keys = ON")

            inviter = db.execute("""
                SELECT user_id
                FROM profiles
                WHERE referral_code = ?
            """, (referral_code,)).fetchone()

            if not inviter:
                raise HTTPException(400, "Invalid referral link.")

            if db.execute(
                "SELECT 1 FROM users WHERE lower(username) = ?",
                (username,)
            ).fetchone():
                raise HTTPException(409, "Username already exists.")

            if db.execute(
                "SELECT 1 FROM profiles WHERE lower(email) = ?",
                (email,)
            ).fetchone():
                raise HTTPException(409, "Email already registered.")

            cursor = db.execute("""
                INSERT INTO users
                (username, password_hash, salt, role)
                VALUES (?, ?, ?, 'user')
            """, (username, password_hash, salt))

            user_id = cursor.lastrowid

            db.execute("""
                INSERT INTO profiles
                (user_id, email, phone, country,
                 referral_code, referred_by)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                user_id,
                email,
                phone,
                country,
                username,
                inviter[0]
            ))

    except sqlite3.IntegrityError:
        raise HTTPException(
            409,
            "Username, email or referral code already exists."
        )

    return {
        "message": "Account created successfully. Your username-based referral link is ready.",
        "username": username,
        "referral_link": f"/register/{username}"
    }
