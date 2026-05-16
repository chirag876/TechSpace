# MongoDB Aggregation Pipeline — Complete Reference Guide
## Table of Contents

1. [What is the Aggregation Pipeline?](#1-what-is-the-aggregation-pipeline)
2. [Pipeline Syntax & Execution Model](#2-pipeline-syntax--execution-model)
3. [Core Stages — Must Know](#3-core-stages--must-know)
   - [$match](#match)
   - [$group](#group)
   - [$project](#project)
   - [$sort](#sort)
   - [$limit & $skip](#limit--skip)
   - [$unwind](#unwind)
   - [$lookup](#lookup)
   - [$addFields](#addfields)
   - [$replaceRoot / $replaceWith](#replaceroot--replacewith)
   - [$count](#count)
   - [$out & $merge](#out--merge)
4. [Accumulator Operators (used inside $group)](#4-accumulator-operators-used-inside-group)
5. [Expression Operators (used inside stages)](#5-expression-operators-used-inside-stages)
   - [Arithmetic](#arithmetic-operators)
   - [String](#string-operators)
   - [Date](#date-operators)
   - [Array](#array-operators)
   - [Conditional](#conditional-operators)
   - [Comparison](#comparison-operators)
   - [Type Conversion](#type-conversion-operators)
6. [Common Pipeline Combinations](#6-common-pipeline-combinations)
7. [Advanced Patterns](#7-advanced-patterns)
   - [Faceted Search ($facet)](#faceted-search-facet)
   - [Bucket & BucketAuto](#bucket--bucketauto)
   - [Graph Lookup](#graphlookup)
   - [Set Stages ($unionWith, $setWindowFields)](#set-stages)
8. [Performance & Indexes in Aggregation](#8-performance--indexes-in-aggregation)
9. [Common Errors & How to Fix Them](#9-common-errors--how-to-fix-them)
10. [Interview Must-Know Q&A](#10-interview-must-know-qa)

---

## 1. What is the Aggregation Pipeline?

The aggregation pipeline is MongoDB's framework for **data transformation and computation**. Think of it as a conveyor belt — documents enter one end, pass through a sequence of stages, and come out transformed on the other end.

Each **stage** takes documents as input, does something to them (filter, reshape, join, calculate), and passes the result to the next stage.

```
Collection → [Stage 1] → [Stage 2] → [Stage 3] → Result
```

**Why use it instead of `find()`?**
- `find()` only filters and projects. It cannot group, join, or compute.
- Aggregation can do everything `find()` does, plus joins (`$lookup`), grouping (`$group`), reshape (`$project`), and advanced analytics.

---

## 2. Pipeline Syntax & Execution Model

### Basic Syntax

```javascript
db.collection.aggregate([
  { stage1 },
  { stage2 },
  { stage3 }
])
```

Each element in the array is an object with a **single key** — the stage name (e.g., `$match`, `$group`).

### Options you can pass

```javascript
db.orders.aggregate(
  [ { $match: { status: "active" } } ],
  {
    allowDiskUse: true,    // allow spilling to disk for large datasets
    maxTimeMS: 5000,       // timeout after 5 seconds
    hint: { status: 1 },   // force index usage
    comment: "debug run"   // useful in logs
  }
)
```

### Memory Limit

By default, each stage is limited to **100 MB of RAM**. If your dataset exceeds that, use `allowDiskUse: true`. Without it, MongoDB throws an error — a very common interview/production gotcha.

---

## 3. Core Stages — Must Know

---

### $match

**Filters documents** — like a `WHERE` clause in SQL. Always put `$match` as early as possible to reduce the number of documents flowing through later stages.

```javascript
// Basic filter
{ $match: { status: "active" } }

// With multiple conditions (AND)
{ $match: { status: "active", age: { $gte: 18 } } }

// With OR
{ $match: { $or: [{ status: "active" }, { role: "admin" }] } }

// After a $group, you can match on computed fields
{ $match: { totalOrders: { $gt: 5 } } }
```

> ⚠️ **Common Error:** Using `$match` after a `$group` won't use indexes since the data is already in-memory. The first `$match` in a pipeline can use indexes — later ones cannot.

---

### $group

**Groups documents by a key** and computes aggregated values using accumulator operators. This is the most important stage in aggregation.

```javascript
// Syntax
{
  $group: {
    _id: <expression>,          // the GROUP BY field
    <field>: { <accumulator>: <expression> }
  }
}
```

```javascript
// Count orders per customer
{
  $group: {
    _id: "$customerId",
    totalOrders: { $sum: 1 },
    totalRevenue: { $sum: "$amount" },
    avgOrderValue: { $avg: "$amount" }
  }
}

// Group by multiple fields (compound key)
{
  $group: {
    _id: { year: { $year: "$createdAt" }, category: "$category" },
    count: { $sum: 1 }
  }
}

// _id: null — aggregate the whole collection into one document
{
  $group: {
    _id: null,
    grandTotal: { $sum: "$amount" },
    maxOrder: { $max: "$amount" }
  }
}
```

> ⚠️ **Common Error:** Trying to reference the original field after grouping. After `$group`, only `_id` and the fields you explicitly computed exist. All other fields from the original documents are gone.

---

### $project

**Reshapes documents** — include/exclude fields, rename fields, compute new fields. Like `SELECT` in SQL.

```javascript
// Include specific fields (1 = include, 0 = exclude)
{ $project: { name: 1, email: 1, _id: 0 } }

// Rename a field
{ $project: { customerName: "$name", _id: 0 } }

// Compute a new field
{
  $project: {
    fullName: { $concat: ["$firstName", " ", "$lastName"] },
    discountedPrice: { $multiply: ["$price", 0.9] },
    year: { $year: "$createdAt" }
  }
}
```

> ⚠️ **Common Error:** Mixing inclusion and exclusion in the same `$project` (except for `_id`). This throws `"You cannot currently mix including and excluding fields."` — keep it all 1s or all 0s.

---

### $sort

**Sorts documents** by one or more fields. `1` = ascending, `-1` = descending.

```javascript
{ $sort: { totalRevenue: -1 } }                     // highest first
{ $sort: { lastName: 1, firstName: 1 } }            // sort by two fields
```

> ✅ **Tip:** If `$sort` is placed **before** `$limit`, MongoDB can optimize it into a "top-N sort" which is much faster than sorting all documents and then limiting.

---

### $limit & $skip

**$limit** keeps only the first N documents. **$skip** skips the first N documents. Often used together for **pagination**.

```javascript
// Get page 3, with 10 results per page
{ $skip: 20 },
{ $limit: 10 }
```

> ⚠️ **Common Error:** Putting `$skip` after `$limit`. You lose documents. Always `$skip` first, then `$limit`.

---

### $unwind

**Deconstructs an array field** — each element in the array becomes a separate document. If a document has an array with 3 elements, `$unwind` outputs 3 documents.

```javascript
// Original document
{ _id: 1, name: "Alice", tags: ["mongodb", "python", "cloud"] }

// After { $unwind: "$tags" }
{ _id: 1, name: "Alice", tags: "mongodb" }
{ _id: 1, name: "Alice", tags: "python" }
{ _id: 1, name: "Alice", tags: "cloud" }
```

**Handle missing/null/empty arrays:**

```javascript
{
  $unwind: {
    path: "$tags",
    preserveNullAndEmptyArrays: true,   // keeps docs where tags is null/missing
    includeArrayIndex: "tagIndex"        // adds a field with the array index
  }
}
```

> ⚠️ **Common Error:** Forgetting that documents with a missing or null array field are **removed** by default. If you want to keep them, use `preserveNullAndEmptyArrays: true`.

---

### $lookup

**Performs a join** with another collection. Like SQL `LEFT OUTER JOIN`.

**Simple (equality) join:**

```javascript
{
  $lookup: {
    from: "products",           // the collection to join
    localField: "productId",    // field from current collection
    foreignField: "_id",        // field from joined collection
    as: "productDetails"        // output array field name
  }
}
// Result: productDetails is an array (even if only one match)
```

**Flatten single-match results** (very common pattern):

```javascript
{ $lookup: { from: "products", localField: "productId", foreignField: "_id", as: "productDetails" } },
{ $unwind: { path: "$productDetails", preserveNullAndEmptyArrays: true } }
// Now productDetails is an object, not an array
```

**Pipeline join (correlated sub-query) — MongoDB 3.6+:**

```javascript
{
  $lookup: {
    from: "orders",
    let: { userId: "$_id" },        // variables from the local document
    pipeline: [
      { $match: { $expr: { $eq: ["$customerId", "$$userId"] } } },
      { $match: { status: "completed" } },
      { $project: { amount: 1, createdAt: 1 } }
    ],
    as: "completedOrders"
  }
}
```

> ⚠️ **Common Error:** Using `$match` with a regular query inside `$lookup.pipeline` and referencing the `let` variable — you MUST use `$expr` with `$$variableName` (double dollar) to reference `let` variables.

---

### $addFields

**Adds new fields** to documents without removing existing ones. Unlike `$project`, which requires you to explicitly include every field you want to keep.

```javascript
{
  $addFields: {
    fullName: { $concat: ["$firstName", " ", "$lastName"] },
    isAdult: { $gte: ["$age", 18] },
    taxAmount: { $multiply: ["$price", 0.18] }
  }
}
```

> ✅ **When to use `$addFields` vs `$project`:**
> - Use `$addFields` when you want to **add** fields but keep everything else.
> - Use `$project` when you want to **select** specific fields (and possibly compute new ones).

---

### $replaceRoot / $replaceWith

**Replaces the entire document** with a specified embedded document or expression.

```javascript
// If each document has a nested "info" object, promote it to root
{ $replaceRoot: { newRoot: "$info" } }

// $replaceWith is shorthand for $replaceRoot
{ $replaceWith: "$info" }

// Merge nested doc with root to preserve some top-level fields
{ $replaceRoot: { newRoot: { $mergeObjects: ["$$ROOT", "$info"] } } }
```

---

### $count

**Counts the number of documents** in the pipeline at that point and outputs a single document.

```javascript
{ $count: "totalActiveUsers" }
// Output: { totalActiveUsers: 1523 }
```

> ✅ **Alternative:** `{ $group: { _id: null, count: { $sum: 1 } } }` does the same thing but is more verbose.

---

### $out & $merge

Write pipeline results to a collection.

```javascript
// $out — replaces the entire collection (atomic)
{ $out: "monthly_report" }

// $merge — upsert/merge into existing collection (more flexible)
{
  $merge: {
    into: "monthly_report",
    on: "_id",                          // match key
    whenMatched: "replace",             // or "merge", "keepExisting", "fail"
    whenNotMatched: "insert"
  }
}
```

> ⚠️ **Common Error:** `$out` **replaces the whole collection**. If your pipeline errors midway, the collection is gone. Use `$merge` for safer incremental writes.

---

## 4. Accumulator Operators (used inside $group)

These only work inside `$group` (and `$bucket`, `$bucketAuto`, `$setWindowFields`).

| Operator | What it does | Example |
|---|---|---|
| `$sum` | Sum of values; `$sum: 1` counts documents | `{ $sum: "$amount" }` |
| `$avg` | Average | `{ $avg: "$score" }` |
| `$min` | Minimum value | `{ $min: "$price" }` |
| `$max` | Maximum value | `{ $max: "$price" }` |
| `$first` | First value in group (depends on sort order) | `{ $first: "$name" }` |
| `$last` | Last value in group | `{ $last: "$status" }` |
| `$push` | Builds an array of all values | `{ $push: "$productId" }` |
| `$addToSet` | Builds an array of **unique** values | `{ $addToSet: "$tag" }` |
| `$stdDevPop` | Population standard deviation | `{ $stdDevPop: "$score" }` |
| `$stdDevSamp` | Sample standard deviation | `{ $stdDevSamp: "$score" }` |
| `$count` | (MongoDB 5.0+) Count of documents in group | `{ $count: {} }` |

```javascript
// Example using multiple accumulators
{
  $group: {
    _id: "$department",
    headcount: { $sum: 1 },
    avgSalary: { $avg: "$salary" },
    maxSalary: { $max: "$salary" },
    allEmployees: { $push: "$name" },
    uniqueRoles: { $addToSet: "$role" }
  }
}
```

---

## 5. Expression Operators (used inside stages)

These are used inside `$project`, `$addFields`, `$match` (with `$expr`), `$group`, etc.

---

### Arithmetic Operators

```javascript
{ $add: ["$price", "$tax"] }               // addition (also adds dates + ms)
{ $subtract: ["$total", "$discount"] }     // subtraction
{ $multiply: ["$qty", "$unitPrice"] }      // multiplication
{ $divide: ["$total", "$count"] }          // division
{ $mod: ["$value", 2] }                    // modulo (remainder)
{ $abs: "$temperature" }                   // absolute value
{ $ceil: "$rating" }                       // round up
{ $floor: "$rating" }                      // round down
{ $round: ["$price", 2] }                  // round to N decimal places
{ $sqrt: "$area" }                         // square root
{ $pow: ["$base", 2] }                     // base^exponent
{ $trunc: ["$price", 2] }                  // truncate (no rounding)
```

---

### String Operators

```javascript
{ $concat: ["$first", " ", "$last"] }      // join strings
{ $toUpper: "$name" }                      // uppercase
{ $toLower: "$email" }                     // lowercase
{ $trim: { input: "$name" } }              // trim whitespace
{ $ltrim: { input: "$name" } }             // left trim
{ $rtrim: { input: "$name" } }             // right trim
{ $substr: ["$code", 0, 3] }               // substring (start, length)
{ $strLenCP: "$name" }                     // string length (code points)
{ $split: ["$fullName", " "] }             // split into array
{ $indexOfCP: ["$email", "@"] }            // find character index (-1 if not found)
{ $regexFind: { input: "$email", regex: /\w+@\w+/ } }   // regex match
{ $regexMatch: { input: "$email", regex: /@gmail/ } }    // returns true/false
```

---

### Date Operators

```javascript
{ $year: "$createdAt" }                    // extract year
{ $month: "$createdAt" }                   // extract month (1-12)
{ $dayOfMonth: "$createdAt" }              // day of month (1-31)
{ $dayOfWeek: "$createdAt" }               // 1 = Sunday, 7 = Saturday
{ $hour: "$createdAt" }                    // 0-23
{ $minute: "$createdAt" }                  // 0-59
{ $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } }   // format date
{ $dateDiff: { startDate: "$startDate", endDate: "$endDate", unit: "day" } }  // 5.0+
{ $dateAdd: { startDate: "$createdAt", unit: "day", amount: 30 } }            // 5.0+
{ $toDate: "$isoDateString" }              // convert string to Date
```

---

### Array Operators

```javascript
{ $size: "$tags" }                         // array length
{ $arrayElemAt: ["$scores", 0] }           // element at index (0-based; -1 = last)
{ $first: "$scores" }                      // shorthand for index 0
{ $last: "$scores" }                       // shorthand for last element
{ $slice: ["$tags", 2] }                   // first N elements
{ $slice: ["$tags", 1, 3] }                // skip 1, take 3
{ $in: ["mongodb", "$tags"] }              // true if value is in array
{ $concatArrays: ["$arr1", "$arr2"] }      // merge arrays
{ $setUnion: ["$arr1", "$arr2"] }          // unique elements from both
{ $setIntersection: ["$arr1", "$arr2"] }   // elements in both
{ $setDifference: ["$arr1", "$arr2"] }     // in arr1 but not arr2
{ $indexOfArray: ["$tags", "python"] }     // index of value (-1 if not found)
{ $reverseArray: "$scores" }               // reverse an array

// $filter — filter array elements
{
  $filter: {
    input: "$scores",
    as: "score",
    cond: { $gte: ["$$score", 80] }   // keep scores >= 80
  }
}

// $map — transform each element
{
  $map: {
    input: "$prices",
    as: "price",
    in: { $multiply: ["$$price", 1.18] }  // apply 18% tax
  }
}

// $reduce — fold array into a single value
{
  $reduce: {
    input: "$scores",
    initialValue: 0,
    in: { $add: ["$$value", "$$this"] }   // sum all scores
  }
}

// $zip — merge arrays element-wise
{
  $zip: {
    inputs: ["$names", "$scores"],
    useLongestLength: false
  }
}
```

---

### Conditional Operators

```javascript
// $cond — if/then/else
{ $cond: { if: { $gte: ["$score", 90] }, then: "A", else: "B" } }
// Short form
{ $cond: [{ $gte: ["$score", 90] }, "A", "B"] }

// $switch — multiple branches (like CASE WHEN in SQL)
{
  $switch: {
    branches: [
      { case: { $gte: ["$score", 90] }, then: "A" },
      { case: { $gte: ["$score", 80] }, then: "B" },
      { case: { $gte: ["$score", 70] }, then: "C" }
    ],
    default: "F"
  }
}

// $ifNull — use fallback if value is null/missing
{ $ifNull: ["$middleName", "N/A"] }

// $nullIf — return null if two values are equal (useful to avoid division by zero)
{ $nullIf: ["$count", 0] }
```

---

### Comparison Operators

Used inside `$expr` or as part of expression contexts (not as query operators):

```javascript
{ $eq: ["$status", "active"] }    // equal
{ $ne: ["$role", "guest"] }       // not equal
{ $gt: ["$age", 18] }             // greater than
{ $gte: ["$score", 90] }          // greater than or equal
{ $lt: ["$price", 100] }          // less than
{ $lte: ["$qty", 50] }            // less than or equal
{ $cmp: ["$a", "$b"] }            // -1, 0, or 1
```

> ⚠️ **Common Error:** Using `{ status: "active" }` inside `$expr`. Inside `$expr`, everything must be an expression. Use `{ $eq: ["$status", "active"] }` instead.

---

### Type Conversion Operators

```javascript
{ $toString: "$price" }             // to string
{ $toInt: "$stringNum" }            // to integer
{ $toLong: "$value" }               // to 64-bit int
{ $toDouble: "$value" }             // to double
{ $toDecimal: "$price" }            // to Decimal128
{ $toBool: "$flag" }                // to boolean
{ $toDate: "$isoString" }           // to Date
{ $toObjectId: "$idString" }        // to ObjectId
{ $type: "$field" }                 // returns BSON type as string
{ $isNumber: "$field" }             // returns true if field is a number
```

---

## 6. Common Pipeline Combinations

These are the real-world patterns you'll encounter and be asked about in interviews.

---

### Pattern 1: Filter → Group → Sort → Limit (Top-N)

**Use case:** Find the top 5 customers by total spending in the last 30 days.

```javascript
db.orders.aggregate([
  // Step 1: Filter to relevant docs first (uses index)
  { $match: {
    createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
    status: "completed"
  }},

  // Step 2: Group by customer
  { $group: {
    _id: "$customerId",
    totalSpent: { $sum: "$amount" },
    orderCount: { $sum: 1 }
  }},

  // Step 3: Sort descending
  { $sort: { totalSpent: -1 } },

  // Step 4: Keep top 5
  { $limit: 5 },

  // Step 5: Enrich with customer details
  { $lookup: {
    from: "customers",
    localField: "_id",
    foreignField: "_id",
    as: "customer"
  }},
  { $unwind: "$customer" },

  // Step 6: Clean up output
  { $project: {
    _id: 0,
    customerId: "$_id",
    name: "$customer.name",
    totalSpent: 1,
    orderCount: 1
  }}
])
```

---

### Pattern 2: Unwind → Group (Array Analytics)

**Use case:** Count how many times each tag is used across all blog posts.

```javascript
db.posts.aggregate([
  { $match: { published: true } },

  // Flatten the tags array
  { $unwind: "$tags" },

  // Count per tag
  { $group: {
    _id: "$tags",
    count: { $sum: 1 }
  }},

  { $sort: { count: -1 } },
  { $limit: 10 }
])
```

---

### Pattern 3: Lookup → Unwind → Group (Join + Aggregate)

**Use case:** Get total revenue per product category (orders → products → categories).

```javascript
db.orders.aggregate([
  { $match: { status: "completed" } },

  // Join with products
  { $lookup: {
    from: "products",
    localField: "productId",
    foreignField: "_id",
    as: "product"
  }},
  { $unwind: "$product" },

  // Group by category
  { $group: {
    _id: "$product.category",
    totalRevenue: { $sum: { $multiply: ["$qty", "$product.price"] } },
    unitsSold: { $sum: "$qty" }
  }},

  { $sort: { totalRevenue: -1 } }
])
```

---

### Pattern 4: $addFields + $project (Field Transformation)

**Use case:** Compute age from birthdate and format names.

```javascript
db.users.aggregate([
  { $addFields: {
    age: {
      $dateDiff: {
        startDate: "$birthDate",
        endDate: "$$NOW",
        unit: "year"
      }
    },
    fullName: { $concat: ["$firstName", " ", "$lastName"] }
  }},

  { $project: {
    _id: 0,
    fullName: 1,
    age: 1,
    email: 1
  }}
])
```

---

### Pattern 5: Conditional Grouping with $cond

**Use case:** Count users by age bucket (0-17, 18-35, 36+).

```javascript
db.users.aggregate([
  { $group: {
    _id: {
      $switch: {
        branches: [
          { case: { $lt: ["$age", 18] }, then: "under_18" },
          { case: { $lt: ["$age", 36] }, then: "18_to_35" }
        ],
        default: "36_plus"
      }
    },
    count: { $sum: 1 },
    avgAge: { $avg: "$age" }
  }}
])
```

---

### Pattern 6: Self-Join / Multiple Lookups

**Use case:** Get an order with both customer and product details.

```javascript
db.orders.aggregate([
  { $match: { _id: orderId } },

  { $lookup: { from: "customers", localField: "customerId", foreignField: "_id", as: "customer" } },
  { $unwind: "$customer" },

  { $lookup: { from: "products", localField: "productId", foreignField: "_id", as: "product" } },
  { $unwind: "$product" },

  { $project: {
    orderDate: 1,
    quantity: 1,
    "customer.name": 1,
    "customer.email": 1,
    "product.name": 1,
    "product.price": 1
  }}
])
```

---

### Pattern 7: Pagination with $facet

**Use case:** Return paginated results AND total count in one query.

```javascript
db.products.aggregate([
  { $match: { category: "electronics" } },
  { $sort: { price: 1 } },
  {
    $facet: {
      data: [
        { $skip: 20 },
        { $limit: 10 }
      ],
      totalCount: [
        { $count: "count" }
      ]
    }
  },
  {
    $project: {
      data: 1,
      total: { $arrayElemAt: ["$totalCount.count", 0] }
    }
  }
])
```

---

### Pattern 8: $group with $push then $unwind (Regroup)

**Use case:** Collect all orders per user, then filter only users with more than 3 orders.

```javascript
db.orders.aggregate([
  { $group: {
    _id: "$userId",
    orders: { $push: "$$ROOT" },
    orderCount: { $sum: 1 }
  }},

  { $match: { orderCount: { $gt: 3 } } },

  { $project: {
    userId: "$_id",
    orderCount: 1,
    recentOrder: { $last: "$orders" }
  }}
])
```

---

## 7. Advanced Patterns

---

### Faceted Search ($facet)

Runs **multiple sub-pipelines in parallel** on the same input documents. Useful for building faceted search UIs (like filters on e-commerce sites).

```javascript
db.products.aggregate([
  { $match: { inStock: true } },
  {
    $facet: {
      // Facet 1: Price distribution
      priceRanges: [
        { $bucket: {
          groupBy: "$price",
          boundaries: [0, 50, 100, 200, 500],
          default: "500+",
          output: { count: { $sum: 1 }, avgPrice: { $avg: "$price" } }
        }}
      ],

      // Facet 2: Category counts
      categories: [
        { $group: { _id: "$category", count: { $sum: 1 } } },
        { $sort: { count: -1 } }
      ],

      // Facet 3: Top rated products
      topRated: [
        { $sort: { rating: -1 } },
        { $limit: 5 },
        { $project: { name: 1, rating: 1, price: 1 } }
      ]
    }
  }
])
```

---

### Bucket & BucketAuto

**$bucket** — manually defined range boundaries:

```javascript
{
  $bucket: {
    groupBy: "$price",
    boundaries: [0, 25, 50, 100, 200],   // must be sorted, ascending
    default: "Other",                      // for values outside boundaries
    output: {
      count: { $sum: 1 },
      products: { $push: "$name" }
    }
  }
}
```

**$bucketAuto** — automatically distributes into N even buckets:

```javascript
{
  $bucketAuto: {
    groupBy: "$price",
    buckets: 5,                   // number of buckets
    output: { count: { $sum: 1 }, avgPrice: { $avg: "$price" } },
    granularity: "R5"             // optional: use standard rounding granularity
  }
}
```

> ⚠️ **Common Error with $bucket:** The `boundaries` array must include all values. A value below the first boundary or above the last boundary causes an error unless you set `default`.

---

### $graphLookup

**Recursive lookup** — traverse a tree/graph structure (like org charts, category hierarchies, social networks).

```javascript
db.employees.aggregate([
  { $match: { name: "CEO" } },
  {
    $graphLookup: {
      from: "employees",
      startWith: "$_id",
      connectFromField: "_id",        // field on matched docs to follow
      connectToField: "managerId",    // field to match against
      as: "reportingChain",
      maxDepth: 3,                    // optional: limit recursion depth
      depthField: "level",            // optional: add depth level to results
      restrictSearchWithMatch: { department: "Engineering" }  // optional filter
    }
  }
])
```

---

### Set Stages

**$unionWith** — combine documents from two collections (like SQL UNION ALL):

```javascript
db.sales_2023.aggregate([
  { $project: { amount: 1, year: { $literal: 2023 } } },
  {
    $unionWith: {
      coll: "sales_2024",
      pipeline: [
        { $project: { amount: 1, year: { $literal: 2024 } } }
      ]
    }
  },
  { $group: { _id: "$year", total: { $sum: "$amount" } } }
])
```

**$setWindowFields** (MongoDB 5.0+) — running totals, ranks, moving averages:

```javascript
{
  $setWindowFields: {
    partitionBy: "$category",
    sortBy: { orderDate: 1 },
    output: {
      runningTotal: {
        $sum: "$amount",
        window: { documents: ["unbounded", "current"] }  // cumulative sum
      },
      movingAvg: {
        $avg: "$amount",
        window: { documents: [-2, 0] }   // last 3 docs including current
      },
      rank: { $rank: {} }
    }
  }
}
```

---

## 8. Performance & Indexes in Aggregation

Understanding this section is critical for senior-level interviews.

### Index Usage Rules

| Stage | Can Use Index? |
|---|---|
| First `$match` in pipeline | ✅ Yes |
| `$sort` at the beginning (before any transforms) | ✅ Yes |
| `$lookup` on `foreignField` | ✅ Yes (if indexed) |
| `$match` after `$group` | ❌ No (in-memory) |
| `$sort` after `$group` | ❌ No (in-memory) |

### Key Performance Rules

**1. Put `$match` as early as possible.**
This reduces the number of documents in the pipeline. Even partial filters early on help.

**2. Put `$sort` before `$limit` for top-N.**
MongoDB merges these into a single optimized step.

**3. Use `$project` or `$addFields` to shed unused fields early.**
Reducing document size speeds up every subsequent stage.

**4. In `$lookup`, index the `foreignField`.**
Without an index on `foreignField`, every join triggers a full collection scan.

**5. Use `allowDiskUse: true` for large datasets.**
Without it, you'll hit the 100MB stage memory limit.

**6. Use `$expr` with caution in `$match`.**
`$match: { $expr: { $eq: ["$a", "$b"] } }` cannot use a regular index. Use a partial filter expression index if needed.

```javascript
// Checking query execution plan
db.orders.explain("executionStats").aggregate([
  { $match: { status: "active" } },
  { $group: { _id: "$customerId", total: { $sum: "$amount" } } }
])
```

---

## 9. Common Errors & How to Fix Them

---

### Error 1: "Unrecognized expression '$fieldName'"

**Cause:** Forgetting the `$` prefix when referencing a field.

```javascript
// ❌ Wrong
{ $group: { _id: "customerId" } }     // "customerId" is treated as a literal string

// ✅ Correct
{ $group: { _id: "$customerId" } }    // "$customerId" refers to the field
```

---

### Error 2: "FieldPath field names may not start with '$'"

**Cause:** Using `$` prefix where a literal string is expected.

```javascript
// ❌ Wrong — "$match" key doesn't need $ when it's the stage key in pipeline
[{ "$match": { status: "active" } }]  // This is actually fine — $match is the stage name

// The real error is doing this inside a projection key:
{ $project: { "$newField": 1 } }      // ❌ keys in $project can't start with $

// ✅ Correct
{ $project: { newField: 1 } }
```

---

### Error 3: "Mixing inclusions and exclusions in $project"

**Cause:** Combining `field: 1` and `field: 0` in the same `$project` (except `_id`).

```javascript
// ❌ Wrong
{ $project: { name: 1, password: 0 } }

// ✅ Correct options:
{ $project: { name: 1, email: 1 } }         // include mode
{ $project: { password: 0, token: 0 } }     // exclude mode
{ $project: { name: 1, password: 0, _id: 0 } } // _id is the ONLY exception
```

---

### Error 4: "Exceeded memory limit for $group / $sort"

**Cause:** Dataset is too large for the 100MB in-memory stage limit.

```javascript
// ✅ Fix: Use allowDiskUse
db.orders.aggregate(
  [ { $group: { _id: "$customerId", total: { $sum: "$amount" } } } ],
  { allowDiskUse: true }
)
```

---

### Error 5: "Let variable not accessible in $lookup pipeline"

**Cause:** Referencing `let` variables without `$expr` and `$$` prefix.

```javascript
// ❌ Wrong
{ $lookup: {
  from: "orders",
  let: { uid: "$_id" },
  pipeline: [
    { $match: { customerId: "$uid" } }   // ❌ $uid is not a field; it's a let variable
  ],
  as: "orders"
}}

// ✅ Correct
{ $lookup: {
  from: "orders",
  let: { uid: "$_id" },
  pipeline: [
    { $match: { $expr: { $eq: ["$customerId", "$$uid"] } } }  // ✅ $$uid + $expr
  ],
  as: "orders"
}}
```

---

### Error 6: Division by Zero

**Cause:** Using `$divide` or `$avg` where denominator can be 0 or null.

```javascript
// ❌ Dangerous
{ $project: { avgOrderValue: { $divide: ["$totalRevenue", "$orderCount"] } } }

// ✅ Safe with $cond
{ $project: {
  avgOrderValue: {
    $cond: {
      if: { $eq: ["$orderCount", 0] },
      then: 0,
      else: { $divide: ["$totalRevenue", "$orderCount"] }
    }
  }
}}
```

---

### Error 7: Documents Missing After $unwind

**Cause:** Default `$unwind` drops documents where the array field is null, missing, or empty.

```javascript
// ❌ Documents with no tags get dropped
{ $unwind: "$tags" }

// ✅ Preserve them
{ $unwind: { path: "$tags", preserveNullAndEmptyArrays: true } }
```

---

### Error 8: $out Deletes Existing Collection on Error

**Cause:** If the pipeline errors after `$out` starts writing, the target collection may be partially or fully replaced.

```javascript
// ❌ Risky
{ $out: "summary_table" }

// ✅ Safer: use $merge with whenMatched strategy
{ $merge: {
  into: "summary_table",
  on: "_id",
  whenMatched: "replace",
  whenNotMatched: "insert"
}}
```

---

### Error 9: Incorrect $match with $expr vs Regular Query Syntax

**Cause:** Inside `$lookup.pipeline`, `$group.having`-style filters, or when comparing two document fields — you must use `$expr`.

```javascript
// ❌ This compares field to field — won't work as expected in expression context
{ $match: { "$fieldA": "$fieldB" } }

// ✅ Use $expr to compare two fields
{ $match: { $expr: { $gt: ["$endDate", "$startDate"] } } }
```

---

### Error 10: Wrong Stage Order Breaks Logic

```javascript
// ❌ Wrong order — limiting BEFORE grouping gives wrong results
{ $limit: 100 },
{ $group: { _id: "$category", count: { $sum: 1 } } }

// ✅ Group first, then limit
{ $group: { _id: "$category", count: { $sum: 1 } } },
{ $sort: { count: -1 } },
{ $limit: 10 }
```

---

## 10. Interview Must-Know Q&A

---

**Q: What is the difference between `$project` and `$addFields`?**

`$project` reshapes the document — you must explicitly include every field you want to keep (or exclude fields you want to drop). `$addFields` only adds or overwrites fields; all other existing fields are automatically preserved. Use `$addFields` when you want to enrich documents, and `$project` when you want to reshape/filter fields.

---

**Q: Can you use `$match` after `$group`? Does it use an index?**

Yes, you can use `$match` after `$group`. However, it will NOT use a collection index because by that point you're working on in-memory computed documents, not the original collection. This is fine — it just filters the grouped output in memory.

---

**Q: What is `$$ROOT` and when would you use it?**

`$$ROOT` is a system variable that refers to the entire current document. Commonly used in:
- `{ $push: "$$ROOT" }` — push the whole document into an array during grouping.
- `{ $replaceRoot: { newRoot: { $mergeObjects: ["$$ROOT", "$embedded"] } } }` — merge an embedded field with the root.
- `{ $group: { _id: "$x", docs: { $push: "$$ROOT" } } }` — group and collect full documents.

---

**Q: What is `$$NOW` and `$$REMOVE`?**

- `$$NOW` — the current datetime (UTC) at the time the aggregation runs.
- `$$REMOVE` — a special value used in `$project` or `$addFields` to conditionally remove a field:

```javascript
{ $addFields: {
  sensitiveField: {
    $cond: { if: "$isAdmin", then: "$secret", else: "$$REMOVE" }
  }
}}
```

---

**Q: How do you paginate efficiently in aggregation?**

Use `$skip` + `$limit`. For the total count, use a `$facet` to run both in one query:

```javascript
db.items.aggregate([
  { $match: filters },
  { $sort: { createdAt: -1 } },
  { $facet: {
    page: [{ $skip: (pageNum - 1) * pageSize }, { $limit: pageSize }],
    totalCount: [{ $count: "n" }]
  }}
])
```

---

**Q: What is the difference between `$lookup` with simple join vs pipeline join?**

Simple join (`localField`/`foreignField`) does an equality match on one field — like `ON a.id = b.id`. Pipeline join (`let` + `pipeline`) allows multiple conditions, filtering inside the sub-query, reshaping the joined documents, and running additional stages — much more powerful and flexible.

---

**Q: When should you use `$facet`?**

When you need **multiple independent aggregation results from the same filtered input** in a single query pass. Common use cases: search results with filter counts (categories, price ranges, brands), dashboard widgets from the same dataset, paginated results with total count.

---

**Q: Difference between `$push` and `$addToSet` in `$group`?**

- `$push` — adds every value including duplicates.
- `$addToSet` — adds only unique values (deduplicates). Note: `$addToSet` does not guarantee any particular order.

---

**Q: How would you find documents where field A > field B (two fields in same doc)?**

```javascript
{ $match: { $expr: { $gt: ["$endDate", "$startDate"] } } }
```
You need `$expr` because regular query syntax (`{ endDate: { $gt: "$startDate" } }`) doesn't work for cross-field comparisons.

---

**Q: What does `allowDiskUse` do and when do you need it?**

By default, each aggregation stage has a 100MB RAM limit. `allowDiskUse: true` allows MongoDB to spill temporary data to disk when this limit is hit, enabling large aggregations to complete. Use it for big `$group`, `$sort`, or `$lookup` operations on large collections. There is a performance cost due to disk I/O.

---

**Q: Can aggregation pipelines be used on sharded clusters?**

Yes. MongoDB's aggregation engine is shard-aware. `$match` and `$sort` can run on each shard in parallel. `$group`, `$lookup`, `$graphLookup`, and `$out` typically require a merge phase on the primary shard or mongos. `$lookup` can only join collections on the same shard (for sharded collections, both collections should be on the same shard or you need to use an unsharded collection).
