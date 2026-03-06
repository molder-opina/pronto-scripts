
import json
import logging
import sys
from io import StringIO
from unittest.mock import patch

from pronto_shared.trazabilidad import get_logger, StructuredLogger

def verify_structured_logging():
    """
    Verifies that the StructuredLogger outputs correctly formatted JSON logs
    with the required fields.
    """
    print("Verifying Structured Logging...")

    # 1. Capture stdout
    with patch('sys.stdout', new=StringIO()) as fake_out:
        # Configure logging to stream to our fake stdout
        root = logging.getLogger()
        root.setLevel(logging.INFO)
        handler = logging.StreamHandler(sys.stdout)
        root.addHandler(handler)
        
        # 2. Get a logger instance
        logger = get_logger("test_service")
        
        # 3. Log a test message
        test_message = "Test structured log message"
        # user_id and action should be promoted to top-level
        # extra_field should be merged to top-level
        # context should be kept as context dict
        logger.info(
            test_message, 
            user_id="123", 
            action="test_action", 
            extra_field="extra_value",
            context={"deep_info": "foo"}
        )
        
        # 4. Get the output
        log_output = fake_out.getvalue().strip()
        
        # remove handler
        root.removeHandler(handler)

    print(f"Log Output: {log_output}")

    # 5. Verify JSON structure
    try:
        log_json = json.loads(log_output)
    except json.JSONDecodeError:
        print("FAIL: Log output is not valid JSON")
        return False

    # 6. Verify required fields
    required_fields = [
        "timestamp", "level", "service", "correlation_id", 
        "message"
    ]
    
    missing_fields = [f for f in required_fields if f not in log_json]
    if missing_fields:
        print(f"FAIL: Missing required fields: {missing_fields}")
        return False
        
    # 7. Verify field values
    if log_json["service"] != "test_service":
        print(f"FAIL: Incorrect service name. Expected 'test_service', got '{log_json['service']}'")
        return False
        
    if log_json["message"] != test_message:
        print(f"FAIL: Incorrect message. Expected '{test_message}', got '{log_json['message']}'")
        return False
        
    if log_json["level"] != "INFO":
        print(f"FAIL: Incorrect level. Expected 'INFO', got '{log_json['level']}'")
        return False

    # Check top-level promoted fields
    if log_json.get("user_id") != "123":
         print(f"FAIL: Incorrect user_id. Expected '123', got '{log_json.get('user_id')}'")
         return False

    if log_json.get("action") != "test_action":
         print(f"FAIL: Incorrect action. Expected 'test_action', got '{log_json.get('action')}'")
         return False

    if log_json.get("extra_field") != "extra_value":
         print(f"FAIL: Incorrect extra_field. Expected 'extra_value', got '{log_json.get('extra_field')}'")
         return False

    # Check context
    expected_context = {"deep_info": "foo"}
    if log_json.get("context") != expected_context:
         print(f"FAIL: Incorrect context. Expected '{expected_context}', got '{log_json.get('context')}'")
         return False

    print("SUCCESS: Structured Logging is working correctly.")
    return True

if __name__ == "__main__":
    if verify_structured_logging():
        sys.exit(0)
    else:
        sys.exit(1)
