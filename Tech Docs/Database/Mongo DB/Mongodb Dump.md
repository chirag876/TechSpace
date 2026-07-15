MongoDB Dump & Restore – Step-by-Step Guide

### (For Local Development Environment)

---

## 🔹 Purpose

Is document ka goal hai:

* Office MongoDB (`vgu_devtest`) ka data **local system par lana**
* Production/Office database ko **touch kiye bina**
* Local development & testing ke liye safe environment banana

---

## 🔹 Prerequisites

Before starting, make sure:

* MongoDB Atlas / Remote DB ka access ho
* Internet connection stable ho
* System: Windows (steps isi ke according hain)

---

## 🧩 STEP 1: MongoDB Database Tools Install Karna

### 🔸 Why Required?

`mongodump` aur `mongorestore` commands MongoDB Database Tools ka part hote hain.
Ye default MongoDB installation ke saath nahi aate.

### 🔸 Download Steps:

1. Open browser
   👉 [https://www.mongodb.com/try/download/database-tools](https://www.mongodb.com/try/download/database-tools)
2. Select:

   * Platform: **Windows x64**
   * Package: **ZIP**
3. Download ZIP file

---

### 🔸 Install Steps:

1. ZIP extract karo (example path):

   ```
   C:\mongodb-database-tools\
   ```
2. Andar `bin` folder milega:

   ```
   C:\mongodb-database-tools\bin
   ```

---

### 🔸 Add to System PATH

1. `This PC` → Right Click → **Properties**
2. `Advanced system settings`
3. `Environment Variables`
4. Under **System Variables**, select `Path` → Edit
5. Click **New** → Paste:

   ```
   C:\mongodb-database-tools\bin
   ```
6. OK → OK → Restart Command Prompt

---

### ✅ Verify Installation

Open new CMD:

```bash
mongodump --version
```

Agar version show ho jaaye → installation successful ✔️

---

## 🧩 STEP 2: Create Database Dump (From Office DB)

### Command:

```bash
mongodump --uri "mongodb+srv://admin_db_user:MOXDPT03cSXaD0rz@cluster0.try4hm.mongodb.net/vgu_devtest?retryWrites=true&w=majority&appName=Cluster0" --out ./vgu_dump
```

### Output:

```
vgu_dump/
 └── vgu_devtest/
      ├── users.bson
      ├── assignments.bson
      ├── xyz.metadata.json
```

✔️ Matlab poora database successfully export ho gaya

---

## 🧩 STEP 3: Verify Dump Files

CMD me run:

```bash
cd vgu_dump
dir
```

Check:

* `vgu_devtest` folder present ho
* Multiple `.bson` files ho

---

## 🧩 STEP 4: Restore Dump to Local MongoDB

### Option 1: Same Database Name

```bash
mongorestore --uri="mongodb://localhost:27017/vgu_devtest" ./vgu_devtest
```

### Option 2 (Recommended): New Local DB Name

```bash
mongorestore --db vgu_devtest_local ./vgu_dump/vgu_devtest
```

✔️ Local MongoDB me naya database create ho jaayega
✔️ Office DB bilkul safe rahega

---

## 🧩 STEP 5: Verify Data in Mongo Shell

```bash
mongosh
```

```js
show dbs
use vgu_devtest_local
show collections
db.users.findOne()
```

Agar data aa raha hai → 🎉 DONE!

---

## 🧠 Common Issues & Fixes

| Issue                      | Solution                            |
| -------------------------- | ----------------------------------- |
| `mongodump not recognized` | Database Tools PATH me add nahi hua |
| Authentication error       | `authSource=admin` add karo         |
| Empty restore              | Galat folder restore ho raha        |
| Duplicate data             | `--drop` flag use karo              |

Example:

```bash
mongorestore --drop --db vgu_devtest_local ./vgu_dump/vgu_devtest
```

---

## ✅ Best Practices

* Local DB ka naam hamesha alag rakho
* Production credentials code me hardcode mat karo
* Dump file ko `.gitignore` me add karo
* Large DB ke liye `--gzip` use karo


