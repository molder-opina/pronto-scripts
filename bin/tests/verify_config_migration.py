from pronto_shared.db import get_session, init_engine
from pronto_shared.models import SystemSetting
from pronto_shared.config import load_config
from sqlalchemy import select

def verify_system_settings():
    print("Verifying SystemSetting model and pronto_system_settings table...")
    
    # Initialize DB engine
    config = load_config("api")
    init_engine(config)
    
    try:
        with get_session() as session:
            # Check if we can query the table
            stmt = select(SystemSetting).limit(5)
            settings = session.execute(stmt).scalars().all()
            
            print(f"Successfully queried {len(settings)} settings.")
            for setting in settings:
                print(f" - {setting.config_key}: {setting.config_value} ({setting.value_type})")
            
            print("\\nVerification SUCCESS: Table renamed and model updated correctly.")
    except Exception as e:
        print(f"\\nVerification FAILED: {str(e)}")
        # Check if old table still exists
        try:
            from sqlalchemy import text
            with get_session() as session:
                result = session.execute(text("SELECT count(*) FROM pronto_business_config")).scalar()
                print(f"Old table 'pronto_business_config' still exists with {result} rows.")
        except Exception:
            print("Old table 'pronto_business_config' does not exist (expected).")

if __name__ == "__main__":
    verify_system_settings()
