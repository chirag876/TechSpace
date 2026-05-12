# FastAPI Request Payload Types: Complete & Comprehensive Guide

## Table of Contents
1. [Introduction](#introduction)
2. [FastAPI's Type Detection System](#fastapis-type-detection-system)
3. [Core Request Payload Types](#core-request-payload-types)
4. [Implicit vs. Explicit Query Parameters](#implicit-vs-explicit-query-parameters)
5. [Your Implementation Patterns](#your-implementation-patterns)
6. [The Class Method Decorator Approach](#the-class-method-decorator-approach)
7. [File Uploads with UploadFile](#file-uploads-with-uploadfile)
8. [Alternative & Better Methods](#alternative--better-methods)
9. [Additional Payload Types](#additional-payload-types)
10. [Keeping Routes Clean](#keeping-routes-clean)
11. [Complete Examples](#complete-examples)
12. [Best Practices & Recommendations](#best-practices--recommendations)
13. [Decision Tree & When to Use What](#decision-tree--when-to-use-what)

---

## Introduction

FastAPI provides multiple ways to accept and process request payloads. Understanding these different types and their implementation patterns is critical for building clean, maintainable, and type-safe APIs.

This guide covers:
- The three main types you've identified (JSON, Query, Form+File)
- Why the class method decorator approach is used for form data
- **How FastAPI automatically determines parameter types (implicit vs. explicit)**
- **Query parameters WITH and WITHOUT `Query()` and when it matters**
- **File upload handling with `UploadFile` class**
- Alternative and better approaches
- Additional lesser-known payload types
- Strategies for keeping routes clean

---

## FastAPI's Type Detection System

### How FastAPI Automatically Determines Parameter Types

One of FastAPI's most powerful features is **automatic type detection**. When you define a function parameter, FastAPI uses a set of rules to determine where the data should come from. Understanding these rules is crucial because they explain why your code works without explicit `Query()` declarations.

#### The Detection Rules

FastAPI follows these rules **in order** to determine a parameter's source:

**1. If the parameter is in the URL path → PATH PARAMETER**
```python
@router.get('/tickets/{ticket_id}')
async def get_ticket(ticket_id: int):  # 'ticket_id' is in the path
    # ticket_id comes from URL: /tickets/123
    pass
```

**2. If the parameter is explicitly declared with `Body()`, `Form()`, `File()`, `Query()`, `Path()`, `Cookie()`, or `Header()` → Use that source**
```python
@router.post('/tickets')
async def create(
    params: CreateTicketRequest,  # Explicit: Body
    skip: int = Query(0),  # Explicit: Query
    file: UploadFile = File(None)  # Explicit: File
):
    pass
```

**3. If the parameter is a Pydantic model → REQUEST BODY (JSON)**
```python
@router.post('/tickets')
async def create(params: CreateTicketRequest):  # No explicit declaration
    # FastAPI sees this is a Pydantic BaseModel
    # Therefore: expects JSON body
    pass
```

**4. If the parameter is a singular type (`int`, `str`, `float`, `bool`) → QUERY PARAMETER**
```python
@router.get('/tickets')
async def list_tickets(skip: int = 0, limit: int = 10):
    # No explicit Query() declaration
    # Singular types default to query parameters
    # URL: /tickets?skip=0&limit=10
    pass
```

**5. If the parameter has a default value of `None` → OPTIONAL QUERY PARAMETER**
```python
@router.get('/tickets')
async def list_tickets(status: Optional[str] = None):
    # Optional: query parameter with None as default
    # URL: /tickets or /tickets?status=open
    pass
```

**6. If the parameter is a special FastAPI type → Use special handling**
```python
from fastapi import Request, BackgroundTasks

@router.post('/tickets')
async def create(
    request: Request,  # Special: raw request object
    bg_tasks: BackgroundTasks  # Special: background task queue
):
    pass
```

#### Visual Decision Tree

```
┌────────────────────────────────────────┐
│  FastAPI Parameter Type Detection      │
└────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
   Is it in          Is it explicitly
   the URL path?     declared with
        │            Body/Form/File/Query?
        │                       │
      YES                      YES
        │                       │
        ▼                       ▼
    PATH              Use that source
  PARAMETER          (Form/Body/File/etc)
                              │
        ┌───────────┬─────────┴──────────┬──────────┐
        │           │                    │          │
        ▼           ▼                    ▼          ▼
      NO          Is it a          Is it a      Is it
              Pydantic model?    singular type?  optional?
                    │                │           │
                   YES              YES          YES
                    │                │           │
                    ▼                ▼           ▼
                BODY            QUERY        QUERY
              (JSON)          PARAMETER    PARAMETER
                              (required)    (optional)
```

### Why Your Code Works Without Query()

Your code works because of **Rule #4**:

```python
@router.put('/extend/duedate')
async def extend_duedate_of_evaluation(
    assignment_id: str,  # Singular type (str) → automatic QUERY
    faculty_id: str,     # Singular type (str) → automatic QUERY
    student_id: str,     # Singular type (str) → automatic QUERY
    evaluation_due_date: Optional[str] = None,  # Optional singular → automatic QUERY
    review_due_date: Optional[str] = None,      # Optional singular → automatic QUERY
):
    pass
```

FastAPI automatically detects singular types and treats them as query parameters. You don't need `Query()` unless you want to add **additional metadata or constraints**.

---

## Core Request Payload Types

### Type 1: JSON Request Body

**What it is:** The client sends data as JSON in the request body. This is the default and most common approach in modern APIs.

**How FastAPI handles it:**
- FastAPI automatically parses the JSON body
- Uses Pydantic models for validation and serialization
- Content-Type header should be `application/json`

**When to use:**
- REST APIs with standard JSON payloads
- Client-side applications (web/mobile) sending structured data
- When you don't need file uploads

**Your current implementation:**
```python
class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    category_id: str
    priority: TicketPriority
    attachments: list[dict[str, Any]] = []

@router.post('/create/tickets')
async def create_ticket(params: CreateTicketRequest):
    # params is automatically deserialized from JSON body
    # FastAPI detects it's a Pydantic model → automatic BODY
    return await ticket_service.create_ticket(params)
```

**How FastAPI detects it:**
- Rule #3 is triggered: parameter is a Pydantic BaseModel
- FastAPI expects JSON in request body
- Automatic validation and deserialization

**Advantages:**
- ✅ Clean and simple
- ✅ Automatic validation via Pydantic
- ✅ Type hints are preserved
- ✅ Works seamlessly with Swagger documentation
- ✅ Language/framework agnostic

**Limitations:**
- ❌ Cannot upload files (files require multipart/form-data)
- ❌ Large payloads may have size limits
- ❌ All data must be JSON-serializable

**Example Usage:**

```javascript
// Client-side (JavaScript)
const response = await fetch('/create/tickets', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    subject: 'Bug in login',
    description: 'Users cannot login with email',
    category_id: 'CAT123',
    priority: 'high'
  })
});
```

---

### Type 2: Query Parameters (Implicit)

**What it is:** Data passed as query string parameters in the URL. Can be implicit (no `Query()`) or explicit (with `Query()`).

#### Implicit Query Parameters (No Query() needed)

**How FastAPI handles it:**
- Detects singular types (str, int, float, bool)
- Automatically treats them as query parameters
- Optional parameters have None as default

**Your actual code pattern:**

```python
@router.put('/extend/duedate')
async def extend_duedate_of_evaluation(
    assignment_id: str,                              # Required query param
    faculty_id: str,                                 # Required query param
    student_id: str,                                 # Required query param
    evaluation_due_date: Optional[str] = None,      # Optional query param
    review_due_date: Optional[str] = None,          # Optional query param
    _user=Depends(JWTAuthUser([]))                  # Dependency injection
) -> dict[str, Any]:
    data = await assignment_evaluation.extend_duedate_of_evaluation(
        assignment_id, faculty_id, student_id, 
        evaluation_due_date, review_due_date
    )
    return {'data': data, 'status': 'SUCCESS'}
```

**Advantages of implicit:**
- ✅ Cleaner code (no redundant `Query()` declarations)
- ✅ Less boilerplate
- ✅ Works perfectly for simple parameters
- ✅ Swagger documentation still generated correctly

**When to use implicit:**
- Simple query parameters without extra constraints
- When you don't need default values, descriptions, or validation
- Quick endpoints with straightforward filtering

---

### Type 2.5: Query Parameters (Explicit with Query())

**What it is:** Query parameters with explicit `Query()` declaration for additional metadata and constraints.

**When to use explicit `Query()`:**

You should use `Query()` when you need:

1. **Description for documentation:**
```python
from fastapi import Query

@router.get('/tickets')
async def list_tickets(
    skip: int = Query(0, description="Number of records to skip"),
    limit: int = Query(10, description="Maximum records to return")
):
    """List all tickets with pagination."""
    pass
```

2. **Validation constraints:**
```python
@router.get('/tickets')
async def list_tickets(
    skip: int = Query(0, ge=0),              # Greater than or equal to 0
    limit: int = Query(10, ge=1, le=100)    # Between 1 and 100
):
    pass
```

3. **Multiple values for same parameter:**
```python
@router.get('/tickets')
async def list_tickets(
    tags: list[str] = Query([])  # Multiple tags: ?tags=bug&tags=urgent
):
    pass
```

4. **Custom parameter names:**
```python
@router.get('/tickets')
async def list_tickets(
    skip: int = Query(0, alias="skip_count")  # Parameter is 'skip_count' in URL
):
    # URL: /tickets?skip_count=10
    pass
```

5. **Making it deprecated:**
```python
@router.get('/tickets')
async def list_tickets(
    status: str = Query("open", deprecated=True)  # Marks as deprecated in docs
):
    pass
```

**Example: Full featured query parameter:**

```python
@router.get('/tickets')
async def list_tickets(
    skip: int = Query(
        0, 
        ge=0,                                    # >= 0
        description="Number of records to skip",
        example=0
    ),
    limit: int = Query(
        10, 
        ge=1, 
        le=100,                                  # 1 <= limit <= 100
        description="Maximum records to return. Default is 10, max is 100.",
        example=10
    ),
    status: Optional[str] = Query(
        None,
        description="Filter by ticket status",
        enum=["open", "closed", "pending"]
    ),
    tags: list[str] = Query(
        [],
        description="Filter by multiple tags"
    )
):
    """
    List tickets with advanced filtering.
    
    - **skip**: How many records to skip for pagination
    - **limit**: Maximum records to return
    - **status**: Filter by status (optional)
    - **tags**: Filter by tags (can specify multiple times)
    """
    return await ticket_service.list_tickets(skip, limit, status, tags)
```

**Comparison: Implicit vs Explicit**

```python
# ❌ Implicit: No metadata
@router.get('/tickets')
async def list_implicit(skip: int = 0, limit: int = 10):
    pass

# ✅ Explicit: Rich metadata for documentation
@router.get('/tickets')
async def list_explicit(
    skip: int = Query(0, ge=0, description="Records to skip"),
    limit: int = Query(10, ge=1, le=100, description="Max records")
):
    pass
# Both work exactly the same way, but explicit provides better API documentation
```

**When to use implicit vs explicit:**

| Scenario | Use |
|----------|-----|
| Simple internal API | Implicit |
| Public API documentation matters | Explicit |
| Need validation constraints | Explicit |
| Need custom names/aliases | Explicit |
| Simple boolean flags | Implicit |
| Complex filtering with descriptions | Explicit |

---

### Type 3: Multipart Form Data with File Upload

**What it is:** Data sent as `multipart/form-data` encoding, typically from HTML forms or when uploading files along with other data.

**How FastAPI handles it:**
- Uses `Form()` for regular form fields
- Uses `File()` for file uploads
- Uses `UploadFile` class for advanced file handling
- Can mix both in the same request
- Requires `python-multipart` library

**When to use:**
- Uploading files (images, documents, etc.)
- Combining file uploads with metadata
- HTML form submissions
- When you need to send binary data alongside structured data

**Your current implementation (using class method decorator):**
```python
class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    category_id: str
    priority: TicketPriority
    attachments: list[dict[str, Any]] = []

    @classmethod
    def as_form(
        cls,
        subject: str = Form(...),
        description: str = Form(...),
        category_id: str = Form(...),
        priority: TicketPriority = Form(...)
    ) -> 'CreateTicketRequest':
        return cls(
            subject=subject,
            description=description,
            category_id=category_id,
            priority=priority,
            attachments=[]
        )

@router.post('/create/tickets', status_code=201)
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(['erp.support.ticket:create']))
) -> dict[str, Any]:
    data = await ticket_service.create_ticket(params, user, attachment=attachment)
    return {'data': data, 'status': 'SUCCESS'}
```

**Advantages:**
- ✅ Validates form fields with Pydantic
- ✅ Keeps validation logic in one place
- ✅ Type-safe
- ✅ Clean endpoint signature
- ✅ Advanced file handling with `UploadFile`

---

## Implicit vs. Explicit Query Parameters

### Complete Comparison

Your use of implicit query parameters (without `Query()`) is **completely valid and encouraged for simple cases**. Let's understand when to use each.

### Implicit Query Parameters (Your Code Pattern)

```python
@router.put('/extend/duedate')
async def extend_duedate_of_evaluation(
    assignment_id: str,                          # Required
    faculty_id: str,                             # Required
    student_id: str,                             # Required
    evaluation_due_date: Optional[str] = None,  # Optional
    review_due_date: Optional[str] = None,      # Optional
):
    pass
```

**Characteristics:**
- ✅ Simple and clean
- ✅ Minimal boilerplate
- ✅ Works for straightforward parameters
- ✅ Swagger docs still generated
- ❌ No custom descriptions (auto-generated)
- ❌ No validation constraints
- ❌ No custom aliases

**What Swagger sees:**

```yaml
parameters:
  - name: assignment_id
    in: query
    required: true
    schema:
      type: string
  - name: evaluation_due_date
    in: query
    required: false
    schema:
      type: string
      nullable: true
```

### Explicit Query Parameters

```python
@router.put('/extend/duedate')
async def extend_duedate_of_evaluation(
    assignment_id: str = Query(..., description="Assignment identifier"),
    faculty_id: str = Query(..., description="Faculty member identifier"),
    student_id: str = Query(..., description="Student identifier"),
    evaluation_due_date: Optional[str] = Query(
        None, 
        description="New evaluation due date (YYYY-MM-DD)"
    ),
    review_due_date: Optional[str] = Query(
        None,
        description="New review due date (YYYY-MM-DD)"
    ),
):
    pass
```

**Characteristics:**
- ✅ Explicit and clear intent
- ✅ Rich documentation
- ✅ Validation constraints possible
- ✅ Custom names/aliases
- ❌ More boilerplate
- ❌ Potentially verbose

**What Swagger sees:**

```yaml
parameters:
  - name: assignment_id
    in: query
    required: true
    description: "Assignment identifier"
    schema:
      type: string
  - name: evaluation_due_date
    in: query
    required: false
    description: "New evaluation due date (YYYY-MM-DD)"
    schema:
      type: string
      nullable: true
```

### When Issues Arise (Implicit vs Explicit)

**Issue 1: Missing validation**

```python
# ❌ Problem: No validation
@router.get('/users/{user_id}/data')
async def get_user_data(
    user_id: int,
    page: int = 1  # What if page=0 or page=-1?
):
    pass

# ✅ Solution: Add validation
@router.get('/users/{user_id}/data')
async def get_user_data(
    user_id: int,
    page: int = Query(1, ge=1)  # Page must be >= 1
):
    pass
```

**Issue 2: Unclear documentation**

```python
# ❌ Auto-generated docs aren't helpful
@router.get('/tickets')
async def list_tickets(
    skip: int = 0,
    limit: int = 10
):
    # Developer sees "skip: int" but doesn't know constraints
    pass

# ✅ Clear documentation
@router.get('/tickets')
async def list_tickets(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(10, ge=1, le=100, description="Max records (1-100)")
):
    pass
```

**Issue 3: Parameter naming conflicts**

```python
# ❌ Can't use different query name than parameter name
@router.get('/data')
async def get_data(
    from_date: str  # In URL must be ?from_date=...
):
    pass

# ✅ Use alias if API expects different name
@router.get('/data')
async def get_data(
    from_date: str = Query(..., alias="from")  # In URL: ?from=2025-01-01
):
    pass
```

### Recommendation Matrix

| Situation | Use Implicit | Use Explicit |
|-----------|-------------|--------------|
| Internal API, simple params | ✅ | - |
| Public API with good docs needed | - | ✅ |
| Simple boolean flags | ✅ | - |
| Integer with range constraints | - | ✅ |
| String with enum values | - | ✅ |
| Multiple values (list) | - | ✅ |
| Legacy API with weird param names | - | ✅ |
| Quick prototyping | ✅ | - |
| Production code needing validation | - | ✅ |
| Temporary endpoints | ✅ | - |

---

## Your Implementation Patterns

You've mentioned three patterns you currently use:

### Pattern 1: Model Class for JSON (Type 1)
```python
class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    category_id: str
    priority: TicketPriority

@router.post('/create/tickets')
async def create_ticket(params: CreateTicketRequest):
    return await ticket_service.create_ticket(params)
```

**Assessment:**
- ✅ This is the recommended pattern for JSON bodies
- ✅ Pydantic validation happens automatically
- ✅ Type hints are clear and explicit
- ✅ Swagger documentation is auto-generated

---

### Pattern 2: Implicit Query Parameters (Your Actual Pattern)

**Your code:**
```python
@router.put('/extend/duedate')
async def extend_duedate_of_evaluation(
    assignment_id: str,
    faculty_id: str,
    student_id: str,
    evaluation_due_date: Optional[str] = None,
    review_due_date: Optional[str] = None,
    _user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    data = await assignment_evaluation.extend_duedate_of_evaluation(
        assignment_id, faculty_id, student_id, 
        evaluation_due_date, review_due_date
    )
    return {'data': data, 'status': 'SUCCESS'}
```

**Assessment:**
- ✅ Works perfectly fine (no issues)
- ✅ Clean and readable
- ✅ Appropriate for internal APIs or simple parameters
- ✅ Less boilerplate than explicit Query()
- ⚠️ Consider adding Query() if:
  - You need validation constraints
  - Documentation needs to be detailed
  - Parameter has complex rules

---

### Pattern 3: Class Method for Form + File

```python
class CreateTicketRequest(BaseModel):
    @classmethod
    def as_form(cls, ...):
        return cls(...)

@router.post('/create/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None)
):
    return await ticket_service.create_ticket(params, attachment=attachment)
```

**Assessment:**
- ✅ Keeps routes clean
- ✅ Type-safe and structured
- ✅ Centralizes validation
- ✅ Best pattern for Type 3 (Form + File)

---

## The Class Method Decorator Approach

### What You're Looking At

Your code block uses a **class method pattern** combined with **dependency injection** (`Depends()`). Let's break it down:

```python
@classmethod
def as_form(
    cls,
    subject: str = Form(...),
    description: str = Form(...),
    category_id: str = Form(...),
    priority: TicketPriority = Form(...)
) -> 'CreateTicketRequest':
    return cls(subject=subject, description=description, category_id=category_id, priority=priority, attachments=[])
```

#### Understanding Each Part

**1. `@classmethod` decorator:**
- Makes this a class method (receives `cls` instead of `self`)
- Can be called on the class itself: `CreateTicketRequest.as_form(...)`
- Allows the method to instantiate the class
- Not bound to any instance (it's bound to the class)

**2. Form field declarations:**
- `subject: str = Form(...)` - Required form field
- `...` (Ellipsis) - Means this field is required; FastAPI will raise validation error if missing
- `Form()` - Tells FastAPI to extract this from form data, not from JSON body
- Each parameter must be explicitly listed

**3. Return type:**
- `-> 'CreateTicketRequest'` - Returns an instance of the class
- Quoted string allows forward reference (class doesn't need to exist yet)

**4. Method body:**
```python
return cls(subject=subject, description=description, category_id=category_id, priority=priority, attachments=[])
```
- Creates and returns a new instance
- Assembles form parameters into the model object
- Can add default values (like empty `attachments=[])

#### How It Works in the Route

```python
@router.post('/create/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(['erp.support.ticket:create']))
) -> dict[str, Any]:
```

**Step-by-step execution:**

1. **Request arrives** with form data and optional file
   - Content-Type: `multipart/form-data`
   - Body contains form fields and file

2. **FastAPI sees** `Depends(CreateTicketRequest.as_form)`
   - Recognizes this is a dependency
   - Needs to resolve it before calling the endpoint

3. **FastAPI inspects** `CreateTicketRequest.as_form` signature
   - Sees: `subject: str = Form(...)`
   - Sees: `description: str = Form(...)`
   - etc.

4. **FastAPI extracts** form fields from the multipart request
   - `subject` → "test"
   - `description` → "sample"
   - `category_id` → "cat123"
   - `priority` → "HIGH"

5. **FastAPI validates** extracted values using Pydantic
   - `TicketPriority` enum validation
   - String length checks
   - Custom validators run

6. **FastAPI calls** `CreateTicketRequest.as_form(subject=..., description=..., ...)`
   - Passes validated form values to the class method
   - Method creates and returns a `CreateTicketRequest` instance

7. **The endpoint receives** the populated `params` object
   - Type: `CreateTicketRequest`
   - All fields validated
   - Ready to use

8. **Separately**, `attachment` is extracted as `UploadFile`
   - Also validates file upload
   - Provides file handling methods

### Why This Pattern Works

```
┌─────────────────────────────────────────────────┐
│         Request with Form Data & File            │
├─────────────────────────────────────────────────┤
│ Content-Type: multipart/form-data                │
│                                                  │
│ Form Fields:                                     │
│   subject=test                                   │
│   description=sample                             │
│   category_id=cat123                             │
│   priority=HIGH                                  │
│                                                  │
│ File:                                            │
│   attachment=<binary file data>                  │
└─────────────────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  FastAPI Dependency Injection │
        │  (Depends clause triggered)   │
        │  Looks at: as_form signature  │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  Form Field Extraction        │
        │  - Reads multipart request    │
        │  - Finds each Form() param    │
        │  - Extracts corresponding val │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  Pydantic Validation          │
        │  - Validates types            │
        │  - Runs validators            │
        │  - Checks enums               │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  as_form() Method Called      │
        │  Receives validated values    │
        │  Creates CreateTicketRequest  │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │    Structured Model Object    │
        │    (type-safe, validated)     │
        │    Ready to use in endpoint   │
        └───────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │     Endpoint Receives:        │
        │  - params: CreateTicketRequest│
        │  - attachment: UploadFile     │
        │  - user: AuthUser             │
        │                               │
        │  Ready to call service layer  │
        └───────────────────────────────┘
```

### Advantages of This Pattern

1. **Type Safety**
   ```python
   params: CreateTicketRequest  # IDE knows exactly what fields exist
   # vs
   params: dict  # Could be anything
   ```

2. **Validation Centralization**
   ```python
   class CreateTicketRequest(BaseModel):
       subject: str = Field(..., min_length=5)
       @validator('subject')
       def validate_subject(cls, v):
           # All validation in one place
           pass
   ```

3. **Clean Route Signature**
   ```python
   # With as_form (clean)
   async def create_ticket(
       params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
       attachment: UploadFile = File(None)
   )
   
   # vs direct Form() (bloated)
   async def create_ticket(
       subject: str = Form(...),
       description: str = Form(...),
       category_id: str = Form(...),
       priority: TicketPriority = Form(...),
       attachment: UploadFile = File(None)
   )
   ```

4. **Reusability**
   ```python
   # Can use as_form from multiple endpoints
   @router.post('/tickets')
   async def create(params: CreateTicketRequest = Depends(CreateTicketRequest.as_form)):
       pass
   
   @router.put('/tickets/{id}')
   async def update(params: CreateTicketRequest = Depends(CreateTicketRequest.as_form)):
       pass
   ```

5. **Service Layer Independence**
   ```python
   # Service doesn't know about Form or FastAPI
   class TicketService:
       async def create_ticket(self, request: CreateTicketRequest, user, attachment=None):
           # Just works with the model
           pass
   ```

---

## File Uploads with UploadFile

### Understanding UploadFile

`UploadFile` is a special class provided by FastAPI for handling file uploads. It wraps the uploaded file in a convenient interface.

### UploadFile vs bytes

```python
from fastapi import UploadFile, File

# ❌ Simple bytes: Entire file loaded into memory
@router.post('/upload')
async def upload_bytes(file: bytes = File(...)):
    # Entire file in memory as bytes
    # Only use for small files
    return {'size': len(file)}

# ✅ UploadFile: Streaming and safe
@router.post('/upload')
async def upload_file(file: UploadFile = File(...)):
    # File streamed from disk/network
    # Safer, more efficient
    # Access file contents when needed
    return {'filename': file.filename}
```

### UploadFile Attributes and Methods

```python
from fastapi import UploadFile, File

@router.post('/upload')
async def upload_file(file: UploadFile = File(...)):
    # Attributes:
    print(file.filename)        # Original filename from upload
    print(file.content_type)    # MIME type (e.g., 'image/jpeg')
    print(file.headers)         # HTTP headers for the file
    print(file.size)            # File size in bytes (if available)
    
    # Methods:
    contents = await file.read()                    # Read entire file
    await file.seek(0)                              # Reset to beginning
    chunk = await file.read(size=1024*1024)        # Read 1MB chunk
    await file.write(b"data")                       # Write to file
    await file.close()                              # Close file
    
    return {'filename': file.filename}
```

### Complete UploadFile Example

```python
from fastapi import UploadFile, File
from pathlib import Path
import aiofiles

# Upload and save file
@router.post('/tickets/{ticket_id}/attachment')
async def upload_attachment(
    ticket_id: int,
    file: UploadFile = File(...),
    user=Depends(JWTAuthUser([]))
):
    """Upload attachment to a ticket."""
    
    # Validate file type
    if file.content_type not in ['image/jpeg', 'image/png', 'application/pdf']:
        raise HTTPException(
            status_code=400,
            detail=f"File type {file.content_type} not allowed"
        )
    
    # Validate file size
    contents = await file.read()
    max_size = 5 * 1024 * 1024  # 5MB
    if len(contents) > max_size:
        raise HTTPException(
            status_code=413,
            detail="File too large (max 5MB)"
        )
    
    # Create upload directory
    upload_dir = Path(f"uploads/tickets/{ticket_id}")
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Save file
    file_path = upload_dir / file.filename
    async with aiofiles.open(file_path, 'wb') as f:
        await f.write(contents)
    
    # Store metadata
    attachment = {
        'filename': file.filename,
        'content_type': file.content_type,
        'size': len(contents),
        'path': str(file_path),
        'uploaded_by': user.id
    }
    
    # Save to database
    await ticket_service.add_attachment(ticket_id, attachment)
    
    return {
        'status': 'SUCCESS',
        'data': attachment
    }
```

### Multiple File Uploads

```python
from fastapi import UploadFile, File
from typing import list

# Upload multiple files
@router.post('/tickets/{ticket_id}/attachments')
async def upload_attachments(
    ticket_id: int,
    files: list[UploadFile] = File(...),
    user=Depends(JWTAuthUser([]))
):
    """Upload multiple attachments."""
    
    uploaded = []
    for file in files:
        # Validate and save each file
        if file.size > 5 * 1024 * 1024:  # 5MB limit per file
            continue
        
        contents = await file.read()
        file_path = f"uploads/tickets/{ticket_id}/{file.filename}"
        
        # Save file
        with open(file_path, 'wb') as f:
            f.write(contents)
        
        uploaded.append({
            'filename': file.filename,
            'size': len(contents),
            'content_type': file.content_type
        })
    
    return {
        'status': 'SUCCESS',
        'uploaded': uploaded,
        'count': len(uploaded)
    }

# Usage in HTML form:
# <form method="post" enctype="multipart/form-data">
#   <input type="file" name="files" multiple>
# </form>
```

### UploadFile with Form Data (Your Use Case)

This is exactly what you're doing:

```python
class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    category_id: str
    priority: TicketPriority
    
    @classmethod
    def as_form(
        cls,
        subject: str = Form(...),
        description: str = Form(...),
        category_id: str = Form(...),
        priority: TicketPriority = Form(...)
    ) -> 'CreateTicketRequest':
        return cls(
            subject=subject,
            description=description,
            category_id=category_id,
            priority=priority
        )

@router.post('/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Create ticket with optional attachment."""
    
    # Handle form data
    data = {
        'subject': params.subject,
        'description': params.description,
        'category_id': params.category_id,
        'priority': params.priority
    }
    
    # Handle file if provided
    if attachment:
        contents = await attachment.read()
        file_info = {
            'filename': attachment.filename,
            'content_type': attachment.content_type,
            'size': len(contents),
            'data': contents
        }
        data['attachment'] = file_info
    
    # Create ticket with attachment
    created = await ticket_service.create_ticket(data, user)
    
    return {
        'data': created,
        'status': 'SUCCESS'
    }
```

### File Upload Security Considerations

```python
from fastapi import UploadFile, File, HTTPException
import mimetypes
from pathlib import Path

ALLOWED_EXTENSIONS = {'.pdf', '.doc', '.docx', '.jpg', '.png', '.gif'}
ALLOWED_MIMETYPES = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
    'image/gif'
}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

@router.post('/tickets/{ticket_id}/safe-upload')
async def safe_upload(
    ticket_id: int,
    file: UploadFile = File(...),
    user=Depends(JWTAuthUser([]))
):
    """Upload with security checks."""
    
    # 1. Validate MIME type
    if file.content_type not in ALLOWED_MIMETYPES:
        raise HTTPException(
            status_code=400,
            detail=f"File type {file.content_type} not allowed"
        )
    
    # 2. Check file extension
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File extension {file_ext} not allowed"
        )
    
    # 3. Validate file size
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail=f"File too large (max {MAX_FILE_SIZE // 1024 // 1024}MB)"
        )
    
    # 4. Prevent path traversal
    filename = Path(file.filename).name  # Get just the filename
    if '..' in str(filename) or '/' in str(filename):
        raise HTTPException(
            status_code=400,
            detail="Invalid filename"
        )
    
    # 5. Generate safe filename
    safe_filename = f"ticket_{ticket_id}_{int(time.time())}_{filename}"
    
    # 6. Save to safe location
    upload_dir = Path("uploads") / str(ticket_id)
    upload_dir.mkdir(parents=True, exist_ok=True)
    file_path = upload_dir / safe_filename
    
    async with aiofiles.open(file_path, 'wb') as f:
        await f.write(contents)
    
    return {
        'status': 'SUCCESS',
        'filename': safe_filename,
        'size': len(contents)
    }
```

### Streaming Large Files

```python
@router.post('/tickets/large-upload')
async def upload_large_file(
    file: UploadFile = File(...),
    user=Depends(JWTAuthUser([]))
):
    """Upload large file by streaming."""
    
    upload_dir = Path("uploads")
    upload_dir.mkdir(exist_ok=True)
    file_path = upload_dir / file.filename
    
    total_size = 0
    chunk_size = 1024 * 1024  # 1MB chunks
    max_size = 100 * 1024 * 1024  # 100MB limit
    
    async with aiofiles.open(file_path, 'wb') as f:
        while True:
            chunk = await file.read(chunk_size)
            if not chunk:
                break
            
            total_size += len(chunk)
            
            # Check size limit
            if total_size > max_size:
                # Delete partial file
                file_path.unlink()
                raise HTTPException(
                    status_code=413,
                    detail="File too large"
                )
            
            await f.write(chunk)
    
    return {
        'status': 'SUCCESS',
        'filename': file.filename,
        'size': total_size
    }
```

---

## Alternative & Better Methods

### Option 1: Direct Form Parameters (Simpler, But Not Always Better)

```python
from fastapi import Form

@router.post('/create/tickets')
async def create_ticket(
    subject: str = Form(...),
    description: str = Form(...),
    category_id: str = Form(...),
    priority: TicketPriority = Form(...),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(['erp.support.ticket:create']))
) -> dict[str, Any]:
    # Create object manually
    params = CreateTicketRequest(
        subject=subject,
        description=description,
        category_id=category_id,
        priority=priority
    )
    return await ticket_service.create_ticket(params, user, attachment=attachment)
```

**Pros:**
- ✅ More explicit
- ✅ Fewer abstractions

**Cons:**
- ❌ Route signature becomes bloated
- ❌ Manual object creation
- ❌ Validation logic spread across multiple places
- ❌ Hard to maintain as complexity grows
- ❌ Not reusable across endpoints

---

### Option 2: Custom Dependency Function

```python
async def get_ticket_form(
    subject: str = Form(...),
    description: str = Form(...),
    category_id: str = Form(...),
    priority: TicketPriority = Form(...)
) -> CreateTicketRequest:
    """Dependency that converts form to model."""
    return CreateTicketRequest(
        subject=subject,
        description=description,
        category_id=category_id,
        priority=priority
    )

@router.post('/create/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(get_ticket_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(['erp.support.ticket:create']))
) -> dict[str, Any]:
    return await ticket_service.create_ticket(params, user, attachment=attachment)
```

**Pros:**
- ✅ Clean route signature
- ✅ Reusable dependency
- ✅ Separation of concerns

**Cons:**
- ⚠️ Extra function to maintain
- ⚠️ Adds another file/module
- ⚠️ Less directly tied to the model

---

### Option 3: Class Method (Your Current Approach) - **RECOMMENDED** ✅

```python
class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    category_id: str
    priority: TicketPriority
    attachments: list[dict[str, Any]] = []

    @classmethod
    def as_form(
        cls,
        subject: str = Form(...),
        description: str = Form(...),
        category_id: str = Form(...),
        priority: TicketPriority = Form(...)
    ) -> 'CreateTicketRequest':
        return cls(
            subject=subject,
            description=description,
            category_id=category_id,
            priority=priority,
            attachments=[]
        )

@router.post('/create/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(['erp.support.ticket:create']))
) -> dict[str, Any]:
    return await ticket_service.create_ticket(params, user, attachment=attachment)
```

**Pros:**
- ✅ Model is self-contained
- ✅ Clean route signature
- ✅ Direct relationship between model and form handler
- ✅ Validation is centralized
- ✅ Type-safe
- ✅ Scales well with complexity
- ✅ Easy to reuse across endpoints
- ✅ Follows DRY principle

**Cons:**
- ⚠️ Slightly more complex syntax initially
- ⚠️ Requires understanding of class methods and Depends

**This is the best approach for your use case.**

---

### Comparison Table

| Approach | Route Cleanliness | Type Safety | Validation | Reusability | Complexity | Scalability |
|----------|------------------|------------|-----------|------------|-----------|-------------|
| **Direct Form** | ⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐⭐ | ⭐ |
| **Custom Dependency** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Class Method** ✅ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## Additional Payload Types

Beyond the three main types, FastAPI supports several other approaches:

### Type 4: Path Parameters

**What it is:** Data passed as part of the URL path (e.g., `/tickets/123`).

**Example:**
```python
from fastapi import Path

@router.get('/tickets/{ticket_id}')
async def get_ticket(
    ticket_id: int = Path(..., gt=0, description="Ticket ID (must be positive)")
):
    return await ticket_service.get_ticket(ticket_id)

# URL: /tickets/123
```

**When to use:**
- Identifying resources
- RESTful endpoint design
- Resource hierarchy
- Primary resource keys

**Advantages:**
- ✅ RESTful design
- ✅ Semantic meaning
- ✅ Validation via Path parameters
- ✅ Clean URL structure

**Important: Always use Path() for path parameters that need validation:**

```python
# ❌ Bad: No validation
@router.delete('/tickets/{ticket_id}')
async def delete_ticket(ticket_id: int):
    # What if ticket_id=-1 or ticket_id=0?
    pass

# ✅ Good: With validation
@router.delete('/tickets/{ticket_id}')
async def delete_ticket(ticket_id: int = Path(..., gt=0)):
    # ticket_id must be > 0
    pass
```

---

### Type 5: Mixed Parameters (JSON Body + Path/Query)

**What it is:** Combining multiple sources in a single endpoint.

**Example:**
```python
class UpdateTicketRequest(BaseModel):
    subject: str
    description: str
    priority: TicketPriority

@router.put('/tickets/{ticket_id}')
async def update_ticket(
    ticket_id: int = Path(..., gt=0),
    status: str = Query(..., enum=["open", "closed", "pending"]),
    params: UpdateTicketRequest
) -> dict:
    # ticket_id from path
    # status from query
    # params from JSON body
    return await ticket_service.update(ticket_id, status, params)

# URL: PUT /tickets/123?status=closed
# Body: JSON with subject, description, priority
```

**When to use:**
- Complex operations requiring multiple data sources
- Updating resources with filters
- Specifying "how" (query) and "what" (body)

---

### Type 6: Cookie Data

**What it is:** Data sent via HTTP cookies.

**Example:**
```python
from fastapi import Cookie

@router.get('/profile')
async def get_profile(
    session_id: str | None = Cookie(None),
    theme: str = Cookie("light")
):
    if session_id:
        return await user_service.get_from_session(session_id)
    return {"theme": theme}
```

**When to use:**
- Session management
- Tracking and analytics
- User preferences
- Authentication tokens (though headers are preferred)

**Note:** Not commonly used in modern APIs; headers are preferred for security.

---

### Type 7: Header Data

**What it is:** Custom HTTP headers sent with the request.

**Example:**
```python
from fastapi import Header

@router.post('/tickets')
async def create_ticket(
    params: CreateTicketRequest,
    x_token: str = Header(..., description="Authentication token"),
    x_request_id: str = Header(default=None, description="Request tracking ID")
):
    # Validate token from header
    return await ticket_service.create_ticket(params, x_token)

# Header: X-Token: secret_value
```

**When to use:**
- API keys
- Authentication tokens
- Custom metadata
- Request tracking
- CORS headers

**Important: Header names are case-insensitive but FastAPI converts them:**

```python
# ❌ This won't work as expected
@router.post('/tickets')
async def create(X-Token: str = Header(...)):
    # Python doesn't allow hyphens in variable names
    pass

# ✅ Correct approach
@router.post('/tickets')
async def create(x_token: str = Header(...)):
    # FastAPI automatically converts 'X-Token' to 'x_token'
    pass

# If you need a different header name:
@router.post('/tickets')
async def create(
    token: str = Header(..., alias="X-Custom-Token")
):
    # Looks for 'X-Custom-Token' header
    pass
```

---

### Type 8: Multiple Body Parameters

**What it is:** Accepting multiple JSON objects in a single request.

**Example:**
```python
@router.post('/tickets/with-metadata')
async def create_with_metadata(
    ticket: CreateTicketRequest,
    metadata: dict = Body(...),
    tags: list[str] = Body(...)
):
    # Multiple objects from same JSON body
    return await ticket_service.create(ticket, metadata, tags)

# JSON:
# {
#   "ticket": {...},
#   "metadata": {...},
#   "tags": [...]
# }
```

**When to use:**
- Complex nested data structures
- Multiple related objects
- Legacy APIs requiring specific JSON structure

---

### Type 9: StreamingResponse / File Response

**What it is:** Streaming large responses or returning files.

**Example:**
```python
from fastapi.responses import FileResponse, StreamingResponse

@router.get('/tickets/{ticket_id}/export')
async def export_ticket(ticket_id: int):
    """Export ticket as PDF."""
    file_path = await ticket_service.export_as_pdf(ticket_id)
    return FileResponse(
        path=file_path,
        filename='ticket.pdf',
        media_type='application/pdf'
    )

# Server-Sent Events (streaming):
async def generate_events():
    for i in range(10):
        yield f"data: {{'message': 'Event {i}'}}\n\n"
        await asyncio.sleep(1)

@router.get('/stream')
async def stream_events():
    return StreamingResponse(
        generate_events(),
        media_type='text/event-stream'
    )
```

**When to use:**
- Large file downloads
- Real-time data streaming
- Server-sent events
- Live updates
- Media streaming

---

### Type 10: Background Tasks with Request Data

**What it is:** Processing request data asynchronously.

**Example:**
```python
from fastapi import BackgroundTasks

@router.post('/tickets')
async def create_ticket(
    params: CreateTicketRequest,
    background_tasks: BackgroundTasks
):
    """Create ticket and send notification asynchronously."""
    ticket = await ticket_service.create_ticket(params)
    
    # Add background task
    background_tasks.add_task(send_email, ticket.id, params.subject)
    
    # Return immediately while email sends in background
    return {
        'status': 'SUCCESS',
        'data': ticket
    }

async def send_email(ticket_id: int, subject: str):
    """Runs in background without blocking response."""
    await email_service.send_notification(ticket_id, subject)
```

**When to use:**
- Email notifications
- Log processing
- Heavy computations
- Webhook calls
- Data synchronization

---

### Type 11: Request Object (Raw Access)

**What it is:** Direct access to the request object for custom processing.

**Example:**
```python
from fastapi import Request

@router.post('/tickets')
async def create_ticket(
    request: Request,
    params: CreateTicketRequest = None
):
    """Create ticket with raw request access."""
    
    # Access raw request data
    body = await request.body()
    headers = dict(request.headers)
    client = request.client
    
    print(f"Client IP: {client.host}")
    print(f"Headers: {headers}")
    
    if params:
        return await ticket_service.create_ticket(params)

```

**When to use:**
- Custom request validation
- Logging/debugging
- Rate limiting
- Request authentication (when you need more control)

---

### Type 12: Form Data with Nested Pydantic Models

**What it is:** Complex form structures with nested models.

**Example:**
```python
from pydantic import BaseModel

class Address(BaseModel):
    street: str
    city: str
    zip_code: str

class UserForm(BaseModel):
    name: str
    email: str
    address: Address
    
    @classmethod
    def as_form(
        cls,
        name: str = Form(...),
        email: str = Form(...),
        street: str = Form(...),
        city: str = Form(...),
        zip_code: str = Form(...)
    ) -> 'UserForm':
        return cls(
            name=name,
            email=email,
            address=Address(street=street, city=city, zip_code=zip_code)
        )

@router.post('/users')
async def create_user(
    params: UserForm = Depends(UserForm.as_form)
):
    return await user_service.create(params)
```

**When to use:**
- Complex form structures
- Logical grouping of related fields
- Reusing nested model validation

---

## Keeping Routes Clean

### Principle 1: Use Dependency Injection

```python
# ❌ Bad: Bloated route signature
@router.post('/tickets')
async def create_ticket(
    subject: str = Form(...),
    description: str = Form(...),
    category_id: str = Form(...),
    priority: TicketPriority = Form(...),
    status: str = Form(default='open'),
    assigned_to: str = Form(default=None),
    tags: list[str] = Form(default=[]),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(...))
):
    pass

# ✅ Good: Clean route with dependency injection
@router.post('/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthPermission(...))
):
    pass
```

---

### Principle 2: Extract Common Logic into Dependencies

```python
# ✅ Good: Separate concern
async def verify_ticket_access(
    ticket_id: int = Path(..., gt=0),
    user=Depends(JWTAuthPermission(...))
):
    """Dependency that verifies user has access to ticket."""
    ticket = await ticket_service.get_ticket(ticket_id)
    if ticket.owner_id != user.id and not user.is_admin:
        raise HTTPException(status_code=403, detail="Access denied")
    return ticket

@router.get('/tickets/{ticket_id}')
async def get_ticket(
    ticket: Ticket = Depends(verify_ticket_access)
):
    """Only accessible users see their tickets."""
    return ticket
```

---

### Principle 3: Use Request/Response Models Consistently

```python
# ✅ Good: Consistent patterns
class CreateTicketRequest(BaseModel):
    subject: str
    description: str

class TicketResponse(BaseModel):
    id: str
    subject: str
    created_at: datetime
    
    class Config:
        from_attributes = True

@router.post('/tickets', response_model=TicketResponse, status_code=201)
async def create_ticket(params: CreateTicketRequest):
    return await ticket_service.create_ticket(params)
```

---

### Principle 4: Separate Endpoints by Content Type (Optional)

```python
# ✅ Good: Separate endpoints for different content types

# For JSON clients (REST API)
@router.post('/api/tickets')
async def create_ticket_json(params: CreateTicketRequest):
    return await ticket_service.create_ticket(params)

# For form submissions (HTML forms)
@router.post('/web/tickets')
async def create_ticket_form(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None)
):
    return await ticket_service.create_ticket(params, attachment=attachment)
```

---

### Principle 5: Group Related Parameters

```python
class PaginationParams(BaseModel):
    skip: int = Field(0, ge=0)
    limit: int = Field(10, ge=1, le=100)

class FilterParams(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    assigned_to: Optional[str] = None

# ✅ Clean route
@router.get('/tickets')
async def list_tickets(
    pagination: PaginationParams = Depends(),
    filters: FilterParams = Depends()
):
    """List tickets with pagination and filtering."""
    return await ticket_service.list(pagination, filters)
```

---

## Complete Examples

### Example 1: Ticket System with All Concepts

```python
from fastapi import APIRouter, File, UploadFile, Depends, status, Path, Query, Form, HTTPException
from pydantic import BaseModel, Field, validator
from typing import Optional, Any
from enum import Enum
import aiofiles
from pathlib import Path

# === ENUMS ===
class TicketPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class TicketStatus(str, Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    CLOSED = "closed"
    ON_HOLD = "on_hold"

# === REQUEST MODELS ===
class CreateTicketRequest(BaseModel):
    """Create ticket from JSON body."""
    subject: str = Field(..., min_length=5, max_length=200)
    description: str = Field(..., min_length=20)
    category_id: str
    priority: TicketPriority
    
    @validator('subject')
    def subject_no_special_chars(cls, v):
        if any(char in v for char in ['<', '>']):
            raise ValueError('Subject cannot contain < or >')
        return v

    @classmethod
    def as_form(
        cls,
        subject: str = Form(..., min_length=5),
        description: str = Form(..., min_length=20),
        category_id: str = Form(...),
        priority: TicketPriority = Form(...)
    ) -> 'CreateTicketRequest':
        """Create ticket from form data with file."""
        return cls(
            subject=subject,
            description=description,
            category_id=category_id,
            priority=priority
        )

class UpdateTicketRequest(BaseModel):
    """Update ticket with optional fields."""
    subject: Optional[str] = Field(None, min_length=5)
    description: Optional[str] = Field(None, min_length=20)
    priority: Optional[TicketPriority] = None
    status: Optional[TicketStatus] = None

class PaginationParams(BaseModel):
    """Query pagination parameters."""
    skip: int = Field(0, ge=0)
    limit: int = Field(10, ge=1, le=100)

class FilterParams(BaseModel):
    """Query filter parameters."""
    status: Optional[str] = Query(None)
    priority: Optional[str] = Query(None)
    category_id: Optional[str] = Query(None)

# === RESPONSE MODELS ===
class TicketResponse(BaseModel):
    """Ticket response model."""
    id: str
    subject: str
    description: str
    status: str
    priority: str
    created_at: str
    
    class Config:
        from_attributes = True

class AttachmentResponse(BaseModel):
    """File attachment response."""
    filename: str
    size: int
    content_type: str
    uploaded_at: str

# === ROUTER ===
router = APIRouter(prefix="/tickets", tags=["Tickets"])

# === ENDPOINTS ===

@router.post('', response_model=TicketResponse, status_code=201)
async def create_ticket_json(
    params: CreateTicketRequest,
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Create ticket from JSON body."""
    data = await ticket_service.create(params, user)
    return {'data': data, 'status': 'SUCCESS'}

@router.post('/form', response_model=TicketResponse, status_code=201)
async def create_ticket_form(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    attachment: UploadFile | None = File(None),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Create ticket from form with optional file."""
    # Validate file if provided
    if attachment:
        contents = await attachment.read()
        if len(contents) > 5 * 1024 * 1024:  # 5MB limit
            raise HTTPException(status_code=413, detail="File too large")
        
        # Save file
        file_path = await save_attachment(attachment, contents)
        attachment_data = {
            'filename': attachment.filename,
            'path': str(file_path),
            'size': len(contents),
            'content_type': attachment.content_type
        }
    else:
        attachment_data = None
    
    data = await ticket_service.create(params, user, attachment=attachment_data)
    return {'data': data, 'status': 'SUCCESS'}

@router.get('')
async def list_tickets(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    status: Optional[str] = Query(None),
    priority: Optional[str] = Query(None),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """List tickets with implicit query parameters."""
    data = await ticket_service.list(
        skip=skip,
        limit=limit,
        filters={'status': status, 'priority': priority},
        user_id=user.id
    )
    return {'data': data, 'status': 'SUCCESS'}

@router.get('/{ticket_id}')
async def get_ticket(
    ticket_id: int = Path(..., gt=0),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Get specific ticket by ID."""
    data = await ticket_service.get(ticket_id, user.id)
    if not data:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return {'data': data, 'status': 'SUCCESS'}

@router.put('/{ticket_id}')
async def update_ticket(
    ticket_id: int = Path(..., gt=0),
    params: UpdateTicketRequest = None,
    status: Optional[str] = Query(None, enum=["open", "closed"]),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Update ticket with path ID + query status + body fields."""
    data = await ticket_service.update(
        ticket_id,
        params,
        status=status,
        user_id=user.id
    )
    return {'data': data, 'status': 'SUCCESS'}

@router.delete('/{ticket_id}')
async def delete_ticket(
    ticket_id: int = Path(..., gt=0),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Delete ticket."""
    await ticket_service.delete(ticket_id, user.id)
    return {'status': 'SUCCESS', 'message': 'Ticket deleted'}

@router.post('/{ticket_id}/attachments')
async def upload_attachment(
    ticket_id: int = Path(..., gt=0),
    file: UploadFile = File(...),
    user=Depends(JWTAuthUser([]))
) -> dict[str, Any]:
    """Upload attachment to existing ticket."""
    contents = await file.read()
    
    # Validate
    if len(contents) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large")
    
    # Save
    file_path = await save_attachment(file, contents)
    
    # Store metadata
    attachment = {
        'ticket_id': ticket_id,
        'filename': file.filename,
        'size': len(contents),
        'content_type': file.content_type,
        'uploaded_by': user.id
    }
    
    data = await ticket_service.add_attachment(ticket_id, attachment)
    return {'data': data, 'status': 'SUCCESS'}

# === HELPER FUNCTIONS ===

async def save_attachment(file: UploadFile, contents: bytes) -> Path:
    """Save file to disk."""
    upload_dir = Path("uploads/attachments")
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    file_path = upload_dir / file.filename
    async with aiofiles.open(file_path, 'wb') as f:
        await f.write(contents)
    
    return file_path
```

---

### Example 2: Different Endpoint Patterns Side by Side

```python
# === JSON Body (Type 1) ===
@router.post('/tickets/json')
async def create_json(params: CreateTicketRequest):
    """Expects JSON body."""
    pass

# === Query Parameters (Type 2) - Implicit ===
@router.get('/tickets/search')
async def search_implicit(
    keyword: str,
    skip: int = 0,
    limit: int = 10
):
    """All parameters are automatically query parameters."""
    pass

# === Query Parameters (Type 2) - Explicit ===
@router.get('/tickets/advanced')
async def search_explicit(
    keyword: str = Query(..., min_length=3),
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100)
):
    """Explicit with validation."""
    pass

# === Form with File (Type 3) ===
@router.post('/tickets/form')
async def create_form(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form),
    file: UploadFile = File(None)
):
    """Form submission with optional file."""
    pass

# === Mixed: Path + Query + Body ===
@router.put('/tickets/{ticket_id}')
async def update_mixed(
    ticket_id: int = Path(..., gt=0),
    priority: str = Query("high"),
    params: UpdateTicketRequest = None
):
    """Combines path, query, and body."""
    pass

# === Path Parameter Only ===
@router.get('/tickets/{ticket_id}')
async def get_by_id(ticket_id: int = Path(..., gt=0)):
    """Only path parameter."""
    pass

# === Headers ===
@router.post('/tickets/secure')
async def secure_create(
    params: CreateTicketRequest,
    authorization: str = Header(...),
    x_request_id: str = Header(None)
):
    """Uses request headers."""
    pass
```

---

## Best Practices & Recommendations

### 1. Choose the Right Type for Your Use Case

| Scenario | Use Type | Implicit/Explicit |
|----------|----------|------------------|
| REST API - create resource | Type 1: JSON | N/A |
| REST API - filter/pagination | Type 2: Query | Implicit |
| REST API - resource ID | Type 4: Path | Default (no choice) |
| REST API - with file | Type 3: Form | Class Method |
| Internal tool - quick filters | Type 2: Query | Implicit |
| Public API - documented | Type 2: Query | Explicit |
| Authentication | Type 7: Header | Explicit |
| Large file download | Type 9: Streaming | N/A |

---

### 2. For Type 3 (Form + File), Always Use Class Method

```python
# ✅ Always do this
class YourRequest(BaseModel):
    field1: str
    field2: str
    
    @classmethod
    def as_form(
        cls,
        field1: str = Form(...),
        field2: str = Form(...)
    ) -> 'YourRequest':
        return cls(field1=field1, field2=field2)

@router.post('/endpoint')
async def endpoint(
    params: YourRequest = Depends(YourRequest.as_form),
    file: UploadFile = File(None)
):
    pass
```

---

### 3. Use Implicit Query() For Simple Cases

```python
# ✅ Good: Simple internal API
@router.get('/tickets')
async def list_tickets(
    skip: int = 0,
    limit: int = 10,
    status: Optional[str] = None
):
    pass

# Consider Explicit if:
# - API is public and documented
# - Need validation constraints
# - Need custom descriptions
```

---

### 4. Use Explicit Query() For Public APIs

```python
# ✅ Good: Public API with documentation
@router.get('/tickets')
async def list_tickets(
    skip: int = Query(0, ge=0, description="Number to skip"),
    limit: int = Query(10, ge=1, le=100, description="Max to return"),
    status: Optional[str] = Query(None, enum=["open", "closed"])
):
    """Enhanced documentation for API consumers."""
    pass
```

---

### 5. Organize Models in Separate Files

```
project/
├── routes/
│   └── tickets.py
├── models/
│   └── database.py
├── schemas/
│   ├── requests.py      # CreateTicketRequest
│   └── responses.py     # TicketResponse
└── services/
    └── ticket_service.py
```

```python
# schemas/requests.py
from pydantic import BaseModel, Form

class CreateTicketRequest(BaseModel):
    subject: str
    description: str
    
    @classmethod
    def as_form(cls, ...):
        return cls(...)

# routes/tickets.py
from schemas.requests import CreateTicketRequest

@router.post('/tickets')
async def create_ticket(
    params: CreateTicketRequest = Depends(CreateTicketRequest.as_form)
):
    pass
```

---

### 6. Always Validate at the Model Level

```python
# ✅ Good: Validation in model
class TicketRequest(BaseModel):
    email: str
    priority: str
    
    @validator('email')
    def validate_email(cls, v):
        if '@' not in v:
            raise ValueError('Invalid email')
        return v
    
    @validator('priority')
    def validate_priority(cls, v):
        if v not in ['low', 'medium', 'high']:
            raise ValueError('Invalid priority')
        return v

# ❌ Bad: Validation in route
@router.post('/tickets')
async def create(params: TicketRequest):
    if '@' not in params.email:
        raise HTTPException(detail="Invalid")
    pass
```

---

### 7. Security: Always Validate File Uploads

```python
@router.post('/upload')
async def upload(file: UploadFile = File(...)):
    """Always validate files."""
    
    # 1. Check MIME type
    if file.content_type not in ['image/jpeg', 'image/png']:
        raise HTTPException(detail="Invalid file type")
    
    # 2. Check file size
    contents = await file.read()
    if len(contents) > 10 * 1024 * 1024:  # 10MB
        raise HTTPException(detail="File too large")
    
    # 3. Validate filename
    safe_filename = Path(file.filename).name
    if '..' in str(safe_filename):
        raise HTTPException(detail="Invalid filename")
    
    # 4. Save safely
    file_path = Path("uploads") / safe_filename
    async with aiofiles.open(file_path, 'wb') as f:
        await f.write(contents)
```

---

### 8. Use Response Models for API Consistency

```python
class TicketResponse(BaseModel):
    id: str
    subject: str
    created_at: datetime
    
    class Config:
        from_attributes = True  # Support ORM models

@router.post('/tickets', response_model=TicketResponse, status_code=201)
async def create_ticket(params: CreateTicketRequest):
    return await ticket_service.create_ticket(params)
```

---

### 9. Handle Errors Properly

```python
from fastapi import HTTPException

@router.get('/tickets/{ticket_id}')
async def get_ticket(ticket_id: int = Path(..., gt=0)):
    try:
        data = await ticket_service.get(ticket_id)
        if not data:
            raise HTTPException(
                status_code=404,
                detail="Ticket not found"
            )
        return {'data': data, 'status': 'SUCCESS'}
    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )
```

---

### 10. Performance: Streaming for Large Files

```python
@router.post('/large-upload')
async def upload_large(
    file: UploadFile = File(...)
):
    """Upload large file efficiently."""
    
    chunk_size = 1024 * 1024  # 1MB
    max_size = 100 * 1024 * 1024  # 100MB limit
    total_size = 0
    
    async with aiofiles.open('uploaded_file', 'wb') as f:
        while True:
            chunk = await file.read(chunk_size)
            if not chunk:
                break
            
            total_size += len(chunk)
            if total_size > max_size:
                raise HTTPException(detail="File too large")
            
            await f.write(chunk)
    
    return {'size': total_size}
```

---

## Decision Tree & When to Use What

### Quick Reference Guide

```
Do you need to receive data?
  │
  ├─ JSON body (structured data)?
  │   └─ Use Type 1: JSON Request Body
  │       - Pydantic model directly in route
  │       - No Query() needed for model
  │
  ├─ Query parameters (filtering/pagination)?
  │   ├─ Simple? (no validation needed)
  │   │   └─ Use IMPLICIT (without Query())
  │   │       - Just: parameter_name: type = default
  │   │
  │   └─ Complex? (validation/descriptions needed)
  │       └─ Use EXPLICIT (with Query())
  │           - Query(..., constraints, description)
  │
  ├─ File upload alone?
  │   └─ Use UploadFile directly
  │       - file: UploadFile = File(...)
  │
  ├─ File + form data together?
  │   └─ Use Type 3: Class Method Pattern
  │       - Class with @classmethod as_form()
  │       - Use Depends() in route
  │
  ├─ Resource ID / URL segment?
  │   └─ Use Type 4: Path Parameter
  │       - ticket_id: int = Path(..., gt=0)
  │
  ├─ Authentication / tracking?
  │   └─ Use Type 7: Headers
  │       - auth: str = Header(...)
  │
  └─ Large data / streaming?
      └─ Use Type 9: Streaming
          - StreamingResponse or FileResponse
```

---

## Summary: Your Questions Answered

| Question | Answer |
|----------|--------|
| **Do I need Query()?** | No, unless you need validation, descriptions, or constraints |
| **Why does implicit work?** | FastAPI auto-detects singular types as query params (Rule #4) |
| **Is implicit okay for production?** | Yes, for internal APIs; consider explicit for public APIs |
| **Best practice for form + file?** | Use class method pattern with @classmethod as_form() |
| **How does UploadFile work?** | Special class for file handling; use File() to declare it |
| **When use File vs bytes?** | UploadFile for streaming; bytes for small files |
| **Multiple files?** | list[UploadFile] = File(...) |
| **Should I validate files?** | Always: check type, size, filename, content |

---

## Final Recommendations 

✅ **For your codebase:**

1. **Use implicit query parameters** (no Query()) for:
   - Simple filters
   - Pagination
   - Internal APIs
   
2. **Use explicit Query()** when you need:
   - Validation constraints (ge, le, min_length, etc.)
   - Rich documentation
   - Public APIs
   - Complex filtering

3. **For file uploads:**
   - Always use `UploadFile` (not bytes)
   - Always use class method pattern with `@classmethod as_form()`
   - Always validate file type and size

4. **Organization:**
   - Keep models in `schemas/` directory
   - Keep routes in `routes/` directory
   - Keep services in `services/` directory
   - Extract common logic into dependencies

## Q: Do I need to use `Query()` in routes?

**A:** No. FastAPI automatically detects singular types (`str`, `int`, etc.) as query parameters.

Use `Query()` only when you need:
- Validation constraints
- Descriptions/examples
- Aliases
- Custom behavior

---

## Q: Will there be any issues if I don't use `Query()`?

**A:** None. Your code is completely fine.

FastAPI automatically handles simple query parameters internally.

### Limitations without `Query()`
- No validation constraints
- No custom Swagger descriptions
- Limited API documentation

Using `Query()` is mainly recommended for public or production APIs.

---

## Q: How does the `UploadFile` class work?

**A:** `UploadFile` is a special wrapper around uploaded files that provides:

- Streaming support (doesn't load full file into memory)
- Better memory efficiency
- File metadata (`filename`, `content_type`)
- Helper methods like:
  - `read()`
  - `seek()`
  - `write()`
  - `close()`

It is more efficient than using raw bytes for large file uploads.

---

## Q: Why use class method for form + file?

**A:** It keeps routes clean and centralizes validation logic.

The class method works like a:
> "form-to-model converter"

that FastAPI can inject as a dependency.

### Benefits
- Cleaner routes
- Reusable validation logic
- Better maintainability
- Organized form + file handling
