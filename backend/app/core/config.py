from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    APP_NAME: str = "Billing Admin API"
    APP_VERSION: str = "1.1.0"
    DEBUG: bool = True
    
    # Database
    DATABASE_URL: str
    DATABASE_ECHO: bool = False
    
    # Security
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:8080,http://localhost:5173"
    
    # Razorpay
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""

    # Supabase (legacy — kept for backward compat, no longer used for auth)
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""

    # Firebase
    FIREBASE_PROJECT_ID: str = ""
    FIREBASE_SERVICE_ACCOUNT_JSON: str = ""  # full service account JSON as a single-line string

    # Clerk
    CLERK_SECRET_KEY: str = ""

    # Self-registration token embedded in the hidden signup URL.
    # This is an obscurity token, not a true secret — the same value ships in the
    # frontend bundle (Signup.tsx), and the real gate on self-register is Clerk OTP.
    # Defaults to the frontend value so deploys don't crash when the env var is unset;
    # override SELF_REGISTER_TOKEN in the environment to use a different value.
    SELF_REGISTER_TOKEN: str = "lcaWo29pNaw"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    @property
    def allowed_origins_list(self) -> List[str]:
        """Convert comma-separated origins to list."""
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Create global settings instance
settings = Settings()
