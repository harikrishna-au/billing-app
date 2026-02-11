#!/bin/bash

# Quick start script for FastAPI backend

echo "🚀 Starting FastAPI Backend Setup..."
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8 or higher."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"
echo ""

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

echo ""

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

echo ""

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo ""
echo "✅ Dependencies installed successfully"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found. Copying from .env.example..."
    cp .env.example .env
    echo "✅ .env file created. Please update DATABASE_URL and other settings."
    echo ""
fi

# Initialize database
echo "🗄️  Initializing database..."
python -m app.init_db

echo ""
echo "✅ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "   1. Update .env file with your database credentials"
echo "   2. Run: source venv/bin/activate"
echo "   3. Run: uvicorn app.main:app --reload"
echo "   4. Open: http://localhost:8000/docs"
echo ""
echo "🔐 Default credentials:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
