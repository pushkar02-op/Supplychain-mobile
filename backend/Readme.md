# Fruit Vendor Backend API

This is the backend API for the Fruit Vendor Tool, built with FastAPI and SQLAlchemy. It provides endpoints for managing inventory, orders, invoices, dispatches, users, and more.

---

## 🚀 Quick Start

### 1. Clone the Repository

```sh
git clone <your-repo-url>
cd backend
```

### 2. Set Up Python Environment

```sh
python -m venv venv
venv\Scripts\activate  # On Windows
# Or
source venv/bin/activate  # On Linux/Mac
```

### 3. Install Dependencies

```sh
pip install -r app/requirements.txt
```

### 4. Configure Environment Variables

Create a `.env` file in the `backend` directory with the following variables:

```env
DATABASE_URL=postgresql://<user>:<password>@<host>:<port>/<db>
JWT_SECRET_KEY=your_secret_key
POSTGRES_USER=your_db_user
POSTGRES_PASSWORD=your_db_password
POSTGRES_DB=your_db_name
POSTGRES_PORT=5432
POSTGRES_HOST=localhost
```

### 5. Run Database Migrations

```sh
cd backend
alembic upgrade head
```

### 6. Start the API Server

using Docker:

```sh
 `docker-compose up --build`
```

---

## 📁 Folder Structure

```
backend/
│
├── alembic.ini
├── Dockerfile
├── requirements.txt
├── wait-for-db.sh
├── alembic/
│   ├── env.py
│   ├── README
│   ├── script.py.mako
│   └── versions/
│       └── ... migration scripts ...
└── app/
    ├── main.py
    ├── requirements.txt
    ├── api/
    │   ├── __init__.py
    │   ├── auth.py
    │   ├── batch.py
    │   ├── dispatch_entry.py
    │   ├── invoice.py
    │   ├── invoice_item.py
    │   ├── item.py
    │   ├── order.py
    │   ├── rejection_entry.py
    │   ├── reports.py
    │   ├── stock_entry.py
    │   ├── user.py
    │   └── audit_log.py
    ├── core/
    │   └── config.py
    ├── db/
    ├── services/
    └── utils/
```

---

## 🛠️ Key Features

- **User Authentication** (JWT)
- **Inventory Management** (Items, Batches, Stock Entries)
- **Order & Dispatch Management**
- **Invoice Upload & Parsing** (PDF support)
- **Audit Logging**
- **Reports** (Inventory, P&L)
- **RESTful API** with OpenAPI docs at `/docs`

---

## 📚 API Documentation

Once running, visit [http://localhost:8000/docs](http://localhost:8000/docs) for interactive API documentation (Swagger UI).

---

## 📝 Notes

- Ensure PostgreSQL is running and accessible with the credentials in your `.env`.
- Alembic is used for database migrations.
- The backend is CORS-enabled for development.
- For production, review and restrict CORS and environment variables.

---

## 🧑‍💻 Useful Commands

- **Run migrations:**  
  `docker-compose exec backend alembic upgrade head   `
- **Create migration:**  
  `docker-compose exec backend alembic revision --autogenerate -m "Migration message"`
- **Run with Docker:**  
  `docker-compose up --build`

---

## 📞 Support

For any issues, please open an issue in the repository or contact the maintainer.

---
