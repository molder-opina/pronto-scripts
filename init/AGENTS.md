# AI Agent Rules for Pronto Development

This document contains all the rules and guidelines that AI agents must follow when creating new objects, structures, and code for the Pronto Restaurant Management System.

---

## Table of Contents

1. [Core Principles](#core-principles)
2. [Database & Models](#database--models)
3. [API Development](#api-development)
4. [Service Layer](#service-layer)
5. [Authentication & Security](#authentication--security)
6. [Frontend Development](#frontend-development)
7. [Testing Requirements](#testing-requirements)
8. [Code Quality Standards](#code-quality-standards)
9. [File Organization](#file-organization)
10. [Prohibited Patterns](#prohibited-patterns)

---

## Core Principles

### 1. Reuse Before Creation
- **ALWAYS** check if functionality exists before creating new code
- Search in `pronto_shared` first for models, services, and utilities
- Extend existing functions rather than duplicating logic
- Use parameterization to make functions more flexible

### 2. Import Hierarchy
```python
# ✅ CORRECT ORDER
from pronto_shared.models import Order, Customer
from pronto_shared.services.order_service import create_order
from pronto_shared.jwt_middleware import jwt_required

# ❌ NEVER duplicate logic from pronto_shared in app-specific folders
```

### 3. Modularization
- Keep functions focused on a single responsibility
- Extract reusable logic into `pronto_shared`
- Shell scripts: max 300 lines, use `bin/lib/` for shared functions
- Python modules: max 500 lines, split into submodules if larger

### 4. Documentation
- All new services must have docstrings
- Update `AGENTS.md` when introducing new patterns
- Document breaking changes in migration files
- Add inline comments for complex business logic

---

## Database & Models

### UUID Consistency Rule (CRITICAL)

**All core entities use UUIDs for primary and foreign keys:**

#### Core Entities (UUID)
- `Employee.id` → UUID
- `Customer.id` → UUID
- `DiningSession.id` → UUID
- `Order.id`, `customer_id`, `session_id` → UUID
- `OrderItem.id`, `order_id`, `menu_item_id` → UUID
- `MenuItem.id`, `category_id` → UUID
- `MenuCategory.id` → UUID
- `Modifier.id`, `modifier_group_id` → UUID
- `ModifierGroup.id` → UUID
- `Feedback.id`, `session_id`, `customer_id` → UUID

#### Utility Entities (Integer)
- `Area.id` → Integer (serial)
- `CustomRole.id` → Integer
- `WaiterCall.id` → Integer
- `ProductSchedule.id` → Integer
- `KeyboardShortcut.id` → Integer
- `TableTransferRequest.id` → Integer

### Model Definition Rules

```python
# ✅ CORRECT: UUID Primary Key
from uuid import UUID, uuid4
from sqlalchemy import UUID as SQLAlchemyUUID
from sqlalchemy.orm import Mapped, mapped_column

class Order(Base):
    __tablename__ = "pronto_orders"
    
    id: Mapped[UUID] = mapped_column(
        SQLAlchemyUUID(as_uuid=True), 
        primary_key=True, 
        default=uuid4
    )
    customer_id: Mapped[UUID] = mapped_column(
        SQLAlchemyUUID(as_uuid=True),
        ForeignKey("pronto_customers.id")
    )

# ❌ WRONG: Using Integer for core entities
class Order(Base):
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
```

### Table Naming Convention
- All tables: `pronto_<entity_name>` (e.g., `pronto_orders`, `pronto_menu_items`)
- Junction tables: `pronto_<entity1>_<entity2>` (e.g., `pronto_menu_item_modifier_groups`)
- **NEVER** create tables without the `pronto_` prefix

### Index Naming Convention
```sql
-- Pattern: ix_<table>_<column(s)>
CREATE INDEX ix_orders_session_id ON pronto_orders(session_id);
CREATE INDEX ix_orders_customer_status ON pronto_orders(customer_id, status);
```

### Migration Rules
1. **File naming**: `YYYYMMDD_NN__description.sql`
   - Example: `20260209_01__add_order_notes.sql`
2. **Location**: `pronto-scripts/init/sql/migrations/`
3. **Content requirements**:
   - Include `-- Migration: <description>`
   - Add rollback instructions in comments
   - Test on local DB before committing
4. **Destructive operations**: Require explicit approval
   - Never `DROP TABLE` without backup
   - Never `TRUNCATE` on production tables

### Protected Tables (NO DELETE/TRUNCATE/DROP)
- `pronto_menu_categories`
- `pronto_menu_items`
- `pronto_employees`
- `pronto_customers`

---

## API Development

### Route Patterns

#### URL Structure
```python
# ✅ CORRECT: Canonical /api/* pattern
@bp.route("/api/orders", methods=["POST"])
@bp.route("/api/orders/<order_id>", methods=["GET"])

# ❌ WRONG: Scoped API routes (deprecated)
@bp.route("/waiter/api/orders", methods=["POST"])
```

#### UUID Parameters (CRITICAL)
```python
# ✅ CORRECT: No type constraint for UUIDs
@bp.get("/orders/<order_id>")
def get_order(order_id) -> tuple[dict, int]:
    # order_id is already a string UUID
    order = order_service.get_order(order_id)
    
# ❌ WRONG: Using int constraint for UUID
@bp.get("/orders/<int:order_id>")  # NEVER DO THIS
def get_order(order_id: int):
    order = order_service.get_order(int(order_id))  # NEVER CAST
```

#### Integer Parameters (for utility entities)
```python
# ✅ CORRECT: Use int constraint for Integer IDs
@bp.get("/roles/<int:role_id>")
def get_role(role_id: int) -> tuple[dict, int]:
    # role_id is an integer
    role = role_service.get_role(role_id)
```

### Thin Controllers Pattern
```python
# ✅ CORRECT: Route delegates to service
@bp.post("/orders")
@jwt_required
@scope_required("waiter")
def create_order() -> tuple[dict, int]:
    payload = request.get_json(silent=True) or {}
    
    # Delegate to service layer
    data, status = order_service.create_order(payload)
    
    if status != HTTPStatus.CREATED:
        return error_response(data.get("error")), status
    return success_response(data), status

# ❌ WRONG: Business logic in route
@bp.post("/orders")
def create_order():
    payload = request.get_json()
    # DON'T DO THIS - business logic belongs in service
    order = Order(
        customer_id=payload["customer_id"],
        total=sum(item["price"] for item in payload["items"])
    )
    session.add(order)
    session.commit()
```

### Response Format
```python
# ✅ CORRECT: Use serializers
from pronto_shared.serializers import success_response, error_response

return success_response({"order": order_data}), HTTPStatus.CREATED
return error_response("Order not found"), HTTPStatus.NOT_FOUND

# ❌ WRONG: Manual JSON construction
return jsonify({"data": order_data, "status": "success"}), 201
```

### Blueprint Registration
```python
# ✅ CORRECT: Register in __init__.py
# pronto-api/src/api_app/routes/employees/__init__.py
from api_app.routes.employees import orders

def register_employees_blueprints() -> Blueprint:
    employees_bp.register_blueprint(orders.bp)
    return employees_bp

# ❌ WRONG: Importing without registering
# This causes 404 errors
```

---

## Service Layer

### Service Location
- **Core services**: `pronto-libs/src/pronto_shared/services/`
- **Specialized services**: `pronto-libs/src/pronto_shared/services/<domain>/`
  - Example: `services/orders/`, `services/payments/`

### Service Function Signature
```python
# ✅ CORRECT: Return tuple[dict, HTTPStatus]
def create_order(payload: dict) -> tuple[dict, HTTPStatus]:
    try:
        # Business logic
        order = Order(...)
        session.add(order)
        session.commit()
        
        return {"order": serialize_order(order)}, HTTPStatus.CREATED
    except ValidationError as e:
        return {"error": str(e)}, HTTPStatus.BAD_REQUEST

# ❌ WRONG: Returning just data or raising exceptions
def create_order(payload: dict) -> dict:
    order = Order(...)
    return serialize_order(order)  # No status code
```

### Database Session Management
```python
# ✅ CORRECT: Use context manager
from pronto_shared.db import get_session

def get_order(order_id: UUID) -> tuple[dict, HTTPStatus]:
    with get_session() as session:
        order = session.get(Order, order_id)
        if not order:
            return {"error": "Order not found"}, HTTPStatus.NOT_FOUND
        return {"order": serialize_order(order)}, HTTPStatus.OK

# ❌ WRONG: Manual session management
def get_order(order_id: UUID):
    session = Session()
    order = session.query(Order).get(order_id)
    session.close()  # Easy to forget
```

### UUID Handling in Services
```python
# ✅ CORRECT: Accept UUID directly
def get_order(order_id: UUID | str) -> tuple[dict, HTTPStatus]:
    with get_session() as session:
        order = session.get(Order, order_id)  # SQLAlchemy handles UUID/str
        
# ❌ WRONG: Casting to int
def get_order(order_id: int):  # NEVER for core entities
    order = session.get(Order, int(order_id))
```

### Validation
```python
# ✅ CORRECT: Use validation service
from pronto_shared.validation import ValidationError
from pronto_shared.services.menu_validation import MenuValidator

def create_menu_item(payload: dict) -> tuple[dict, HTTPStatus]:
    with get_session() as session:
        validator = MenuValidator(session=session)
        try:
            validator.validate_create(payload)
        except ValidationError as e:
            return {"error": str(e)}, HTTPStatus.BAD_REQUEST
        
        # Create item
        item = MenuItem(...)
        
# ❌ WRONG: Inline validation
def create_menu_item(payload: dict):
    if not payload.get("name"):
        raise ValueError("Name required")  # Don't raise
    if len(payload["name"]) > 100:
        raise ValueError("Name too long")
```

---

## Authentication & Security

### JWT Authentication (CRITICAL)

#### Employee Authentication
```python
# ✅ CORRECT: Use JWT decorators
from pronto_shared.jwt_middleware import jwt_required, scope_required, get_employee_id

@bp.post("/orders")
@jwt_required
@scope_required("waiter")
def create_order():
    employee_id = get_employee_id()  # Get from JWT
    # Use employee_id
    
# ❌ WRONG: Using Flask session for employees
from flask import session

@bp.post("/orders")
def create_order():
    employee_id = session.get("employee_id")  # NEVER DO THIS
    session["employee_id"] = 123  # NEVER DO THIS
```

#### Flask Session Rules
```python
# ✅ ALLOWED: Client-facing sessions only
session.get("customer_id")  # OK for pronto-client
session.get("dining_session_id")  # OK for pronto-client

# ✅ ALLOWED: SQLAlchemy sessions
from pronto_shared.db import get_session
with get_session() as session:  # This is fine
    order = session.get(Order, order_id)

# ❌ FORBIDDEN: Employee auth in Flask session
session.get("employee_id")  # NEVER
session.get("employee_role")  # NEVER
session.clear()  # Use JWT logout instead
```

### Scope-Based Authorization
```python
# ✅ CORRECT: Scope guard for specific roles
@bp.post("/orders/<order_id>/cancel")
@jwt_required
@scope_required(["admin", "system"])  # Only admin/system can cancel
def cancel_order(order_id):
    pass

# Multiple scopes allowed
@scope_required(["waiter", "chef", "cashier", "admin"])
```

### CSRF Protection
```python
# ✅ CORRECT: CSRF token in headers
# Frontend must send:
headers = {
    "X-CSRFToken": csrf_token,
    "Content-Type": "application/json"
}

# Backend validates automatically via middleware
```

---

## Frontend Development

### Static Asset URLs
```html
<!-- ✅ CORRECT: Use template variables -->
<link rel="stylesheet" href="{{ assets_css_clients }}/menu.css">
<script src="{{ assets_js_employees }}/main.js"></script>
<img src="{{ assets_images }}/logo.png" alt="Logo">

<!-- ❌ WRONG: Hardcoded URLs -->
<link rel="stylesheet" href="http://localhost:9088/assets/css/clients/menu.css">
<script src="{{ pronto_static_container_host }}/assets/js/employees/main.js"></script>
```

### Available Template Variables
- `assets_css` → `/assets/css`
- `assets_css_clients` → `/assets/css/clients`
- `assets_css_employees` → `/assets/css/employees`
- `assets_js` → `/assets/js`
- `assets_js_clients` → `/assets/js/clients`
- `assets_js_employees` → `/assets/js/employees`
- `assets_images` → `/assets/pronto`

### Vue 3 Component Structure
```typescript
// ✅ CORRECT: Composition API with TypeScript
<script setup lang="ts">
import { ref, computed } from 'vue'
import type { Order } from '@/types/order'

const orders = ref<Order[]>([])
const totalOrders = computed(() => orders.value.length)
</script>

// ❌ WRONG: Options API (deprecated in this project)
<script lang="ts">
export default {
  data() {
    return { orders: [] }
  }
}
</script>
```

### API Calls from Frontend
```typescript
// ✅ CORRECT: Use centralized API client
import { api } from '@/lib/api'

const createOrder = async (orderData: CreateOrderRequest) => {
  const response = await api.post('/orders', orderData)
  return response.data
}

// ❌ WRONG: Direct fetch calls
const createOrder = async (orderData) => {
  const response = await fetch('http://localhost:6082/api/orders', {
    method: 'POST',
    body: JSON.stringify(orderData)
  })
}
```

---

## Testing Requirements

### Test Coverage Mandate
**Every new feature MUST include tests:**

1. **Unit Tests**: `pronto-tests/tests/functionality/unit/`
   - Test individual functions in isolation
   - Mock external dependencies
   
2. **Integration Tests**: `pronto-tests/tests/functionality/integration/`
   - Test service layer with real database
   - Test API endpoints with real requests
   
3. **E2E Tests**: `pronto-tests/tests/functionality/e2e/`
   - Test complete user flows
   - Use Playwright for browser automation

### Test Naming Convention
```python
# ✅ CORRECT: Descriptive test names
def test_create_order_with_valid_payload_returns_201():
    pass

def test_create_order_with_missing_customer_id_returns_400():
    pass

# ❌ WRONG: Vague test names
def test_order():
    pass

def test_1():
    pass
```

### Test Structure
```python
# ✅ CORRECT: Arrange-Act-Assert pattern
def test_create_order_calculates_total_correctly():
    # Arrange
    payload = {
        "customer_id": str(uuid4()),
        "items": [
            {"menu_item_id": str(uuid4()), "quantity": 2, "price": 10.0},
            {"menu_item_id": str(uuid4()), "quantity": 1, "price": 15.0}
        ]
    }
    
    # Act
    data, status = order_service.create_order(payload)
    
    # Assert
    assert status == HTTPStatus.CREATED
    assert data["order"]["total"] == 35.0
```

---

## Code Quality Standards

### Python Standards
```python
# Line length: 100 characters max
# Linter: ruff
# Formatter: black or ruff format
# Type checker: mypy

# ✅ CORRECT: Type hints
def create_order(
    payload: dict[str, Any],
    employee_id: UUID
) -> tuple[dict[str, Any], HTTPStatus]:
    pass

# ❌ WRONG: No type hints
def create_order(payload, employee_id):
    pass
```

### Import Organization
```python
# ✅ CORRECT: Organized imports
from __future__ import annotations

import logging
from datetime import datetime
from http import HTTPStatus
from typing import Any
from uuid import UUID

from flask import Blueprint, request
from sqlalchemy import select

from pronto_shared.db import get_session
from pronto_shared.jwt_middleware import jwt_required
from pronto_shared.models import Order, OrderItem
from pronto_shared.serializers import error_response, success_response

# ❌ WRONG: Unorganized imports
from pronto_shared.models import Order
import logging
from flask import Blueprint
from pronto_shared.db import get_session
```

### Error Handling
```python
# ✅ CORRECT: Specific exceptions
try:
    order = order_service.create_order(payload)
except ValidationError as e:
    return error_response(str(e)), HTTPStatus.BAD_REQUEST
except IntegrityError as e:
    logger.error(f"Database integrity error: {e}")
    return error_response("Database error"), HTTPStatus.INTERNAL_SERVER_ERROR

# ❌ WRONG: Bare except
try:
    order = order_service.create_order(payload)
except:  # Too broad
    return error_response("Error"), 500
```

---

## File Organization

### Service Files
```
pronto-libs/src/pronto_shared/services/
├── order_service.py              # Core order operations
├── menu_service.py               # Menu management
├── orders/                       # Order subdomain
│   ├── __init__.py
│   ├── customer_resolver.py
│   ├── session_manager.py
│   ├── order_item_processor.py
│   └── order_pricing.py
└── payments/                     # Payment subdomain
    ├── __init__.py
    ├── base_provider.py
    ├── cash_provider.py
    └── stripe_provider.py
```

### Route Files
```
pronto-api/src/api_app/routes/
├── __init__.py                   # Blueprint registration
├── orders.py                     # Order routes
├── menu.py                       # Menu routes
└── employees/                    # Employee-specific routes
    ├── __init__.py
    ├── orders.py
    ├── menu_items.py
    └── sessions.py
```

### Model Organization
```python
# ✅ CORRECT: All models in models.py
# pronto-libs/src/pronto_shared/models.py
class Order(Base):
    pass

class OrderItem(Base):
    pass

# ❌ WRONG: Models scattered in multiple files
# pronto-api/src/models/order.py  # Don't do this
```

---

## Prohibited Patterns

### ❌ NEVER Do These Things

1. **Architecture Changes Without Approval**
   - No changing database schema without migration
   - No changing API contract without versioning
   - No removing existing endpoints

2. **Database Operations**
   - `DROP TABLE` on production tables
   - `TRUNCATE` on protected tables
   - Direct SQL without parameterization (SQL injection risk)

3. **Authentication Anti-Patterns**
   ```python
   # ❌ NEVER
   session["employee_id"] = 123
   session.get("employee_role")
   
   # ❌ NEVER
   if request.args.get("admin") == "true":
       # Grant admin access
   ```

4. **UUID Anti-Patterns**
   ```python
   # ❌ NEVER use int for core entities
   @bp.get("/orders/<int:order_id>")
   
   # ❌ NEVER cast UUID to int
   order = session.get(Order, int(order_id))
   ```

5. **Import Anti-Patterns**
   ```python
   # ❌ NEVER duplicate from pronto_shared
   # pronto-api/src/utils/order_helper.py
   def calculate_order_total(items):  # Already exists in pronto_shared
       pass
   ```

6. **Hardcoded Values**
   ```python
   # ❌ NEVER hardcode
   TAX_RATE = 0.16  # Use config
   ADMIN_EMAIL = "admin@example.com"  # Use env var
   ```

7. **Static Asset Anti-Patterns**
   ```html
   <!-- ❌ NEVER hardcode URLs -->
   <script src="http://localhost:9088/assets/js/main.js"></script>
   
   <!-- ❌ NEVER use container host in templates -->
   <img src="{{ pronto_static_container_host }}/logo.png">
   ```

---

## Quick Reference Checklist

Before creating new code, verify:

- [ ] Checked if functionality exists in `pronto_shared`
- [ ] Used UUIDs for core entity IDs (not `int`)
- [ ] No `<int:...>` constraints for UUID parameters
- [ ] Used JWT for employee auth (not Flask session)
- [ ] Followed thin controller pattern (logic in services)
- [ ] Used `success_response`/`error_response` serializers
- [ ] Added type hints to all functions
- [ ] Created unit/integration tests
- [ ] Used template variables for static assets
- [ ] Followed naming conventions (tables, indexes, files)
- [ ] No hardcoded values (use config/env vars)
- [ ] Documented complex business logic
- [ ] Checked `AGENTS.md` for project-specific rules

---

## Getting Help

When in doubt:
1. Check `pronto-ai/AGENTS.md` for project overview
2. Review existing code in `pronto_shared` for patterns
3. Use `\d+ table_name` in psql to verify schema
4. Run `grep -r "pattern" pronto-libs/` to find examples
5. Check test files for usage examples

---

**Last Updated**: 2026-02-09  
**Maintained By**: Development Team
