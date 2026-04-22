# Caching and Performance Optimization in Course API

## 1. Introduction

This document explains the implementation, reasoning, and impact of introducing caching in the course-related API system. It is intended for both technical and semi-technical stakeholders to understand the optimization strategy.

API: /api/v1/lms/staff/courses/paginated in staff_courses in lms server

---

## 2. Problem Statement

The API responsible for fetching course data was experiencing performance issues due to repeated database calls. Specifically:

* Each API request triggered multiple database queries.
* A permission check function executed 3 database calls per request:

  * Fetch user
  * Fetch resource
  * Fetch role permissions

### Impact:

* Increased latency
* Higher database load
* Reduced scalability under concurrent usage

---

## 3. Solution Overview

A caching mechanism was introduced using an in-memory cache with the following configuration:

* Max size: 512 entries
* TTL (Time To Live): 60 seconds

This cache stores the result of the permission check per user.

---

## 4. How the Cache Works

### Key Concept:

* Cache key: `user_id`
* Cache value: Boolean (`True` or `False` for permission)

### Flow:

1. When a user makes a request:

   * The system checks if the user exists in cache.

2. If present (Cache Hit):

   * Return the cached result instantly.
   * No database calls are made.

3. If not present (Cache Miss):

   * Execute database queries.
   * Store the result in cache.

---

## 5. Cache Behavior Details

### 5.1 Max Size (512)

* The cache can store up to 512 unique users.
* If a 513th user is added:

  * The least recently used (LRU) entry is removed.

### 5.2 TTL (60 seconds)

* Each cache entry expires after 60 seconds.
* After expiration, the next request triggers a fresh database lookup.

### 5.3 Eviction Policy (LRU)

* Only one entry is removed at a time when the cache is full.
* The least recently accessed user is evicted.

---

## 6. Performance Improvement

### Before Caching:

* 3 database calls per API request
* Repeated for every request, even for the same user

### After Caching:

* First request: 3 database calls
* Subsequent requests (within 60 seconds): 0 database calls

### Result:

* Reduced database load
* Faster response time
* Improved scalability

---

## 7. Why Caching Was Applied Only to Permission Logic

Caching was intentionally applied only to the permission-checking logic and not to the course data.

### Reasons:

#### 7.1 Data Size

* Permission data is small (boolean)
* Course data is large (hundreds/thousands of records)

#### 7.2 Data Volatility

* Permissions change infrequently
* Course data changes frequently (status, content, metadata)

#### 7.3 Query Complexity

* Permission logic is consistent per user
* Course queries vary based on filters, pagination, and parameters

#### 7.4 Cache Efficiency

* Permission cache has high reuse
* Course data cache would have low hit rate due to multiple combinations

---

## 8. Alternative Optimizations (Without Cache)

### 8.1 Query Optimization

* Combine multiple database calls into a single aggregation query

### 8.2 Static Data Preloading

* Load rarely changing data (e.g., resources) into memory at startup

### 8.3 Role-Based Permission Mapping

* Cache permissions at role level instead of user level

---

## 9. Limitations of Current Approach

* Cache is in-memory (not shared across instances)
* Data may be stale for up to 60 seconds
* Eviction occurs when user count exceeds 512

---

## 10. Future Improvements

### 10.1 Use Distributed Cache

* Replace in-memory cache with Redis

### 10.2 Cache Invalidation

* Invalidate cache on role/permission updates

### 10.3 Aggregation Optimization

* Reduce number of lookups in MongoDB pipeline
* Add proper indexing

### 10.4 Pagination-Based Caching

* Cache course data per page instead of full dataset

---

## 11. Business Explanation (For Non-Technical Stakeholders)

### Simple Explanation:

Previously, the system was re-checking user permissions from the database on every request. This caused unnecessary delays.

Now, the system temporarily remembers the permission result for a short duration. This avoids repeated checks and improves response time.

### Analogy:

Instead of verifying a person’s ID every time they enter a room, the system remembers them for a short time after the first check.

---

## 12. Conclusion

The caching implementation provides a quick and effective performance improvement by reducing redundant database calls. While it is not a complete optimization, it significantly enhances response time for repeated requests and lays the foundation for further scalability improvements.

---

---

## 13. Implementation Code

```python
import aiohttp
from cachetools import TTLCache

_draft_permission_cache: TTLCache = TTLCache(maxsize=512, ttl=60)

@router.post('/courses/paginated', summary='Gets courses in paginated form')
async def get_all_courses_details_paginated(
    parent_node_id: str = None,
    label: CourseLabels = None,
    course_status: CourseStaffStatus = None,
    stream_ids: list[str] = Query(None),
    filter_data: CourseFilter = None,
    user=Depends(JWTAuthUser(['lms.course:list'])),
) -> dict[str, Any]:
    data = await course_service.get_courses_details_paginated_v2(
        parent_node_id=parent_node_id,
        label=label,
        course_status=course_status,
        stream_ids=stream_ids,
        filter_data=filter_data.dict() if filter_data else {},
        user_id=user['_id']
    )
    return {'data': data, 'status': 'SUCCESS'}

async def check_staff_course_draft_permission(user_id: str) -> bool:
    if user_id in _draft_permission_cache:
        return _draft_permission_cache[user_id]

    user = await core_service.read_one(
        Collections.USERS,
        {'_id': user_id, 'is_deleted': False},
        {'roles': 1, 'user_type': 1}
    )

    if not user or user.get('user_type') != 'Staff':
        _draft_permission_cache[user_id] = False
        return False

    role_ids = user.get('roles', [])
    if not role_ids:
        _draft_permission_cache[user_id] = False
        return False

    resource = await core_service.read_one(
        Collections.RESOURCES,
        {'identifier': 'lms.course', 'is_deleted': False},
        {'_id': 1}
    )

    if not resource:
        _draft_permission_cache[user_id] = False
        return False

    role_permissions = await core_service.read_many(
        Collections.ROLE_PERMISSIONS,
        {
            'role_id': {'$in': role_ids},
            'resource_id': resource['_id'],
            'is_deleted': False
        },
        {'permission_type': 1}
    )

    all_permissions = set()
    for rp in role_permissions:
        perm = rp.get('permission_type', [])
        if isinstance(perm, list):
            all_permissions.update(perm)
        else:
            all_permissions.add(perm)

    has_perm = 'create' in all_permissions and 'edit' in all_permissions
    _draft_permission_cache[user_id] = has_perm

    return has_perm

async def get_courses_details_paginated_v2(
    parent_node_id: str = None, label: CourseLabels = None, course_status: CourseStaffStatus = None, stream_ids: list[str] = None, filter_data: CourseFilter = None, user_id: str = None
) -> list[dict[str, Any]]:

    can_view_draft = False
    if course_status == 'DRAFT':
        can_view_draft = await check_staff_course_draft_permission(user_id)

    if course_status:
        course_filter = {'is_deleted': False, 'status': course_status}
    elif can_view_draft:
        course_filter = {'is_deleted': False}
    else:
        course_filter = {'is_deleted': False, 'status': {'$ne': 'DRAFT'}}

    if label:
        course_filter['label'] = label
    if is_valid_list(stream_ids):
        course_filter['stream_ids'] = {'$in': stream_ids}
    if parent_node_id:
        course_filter['parent_node_id'] = parent_node_id

    aggregate_pipeline: list[dict] = [
        {'$match': {'is_deleted': False, 'user_id': user_id}},
        {'$unwind': '$relation'},
        # Courses join
        {'$lookup': {'from': Collections.COURSES, 'localField': 'relation.entity_id', 'foreignField': 'course_node' if parent_node_id else '_id', 'as': 'courses'}},
        {'$unwind': {'path': '$courses', 'preserveNullAndEmptyArrays': False}},
        {'$replaceRoot': {'newRoot': '$courses'}},
        # Course filter apply
        {'$match': course_filter},
        # Videos — simple lookup, no expr
        {'$lookup': {'from': Collections.COURSES, 'localField': '_id', 'foreignField': 'course_node', 'as': 'all_videos'}},
        # Program relations — simple lookup, no expr
        {'$lookup': {'from': 'program_course_relations', 'localField': '_id', 'foreignField': 'course_id', 'as': 'program_relations'}},
        # Programs — simple lookup, no expr
        {'$lookup': {'from': 'programs', 'localField': 'program_relations.program_id', 'foreignField': '_id', 'as': 'programs_raw'}},
        # Coordinator — simple lookup, no expr
        {'$lookup': {'from': Collections.USERS, 'localField': 'course_coordinator_id', 'foreignField': '_id', 'as': 'coordinator_raw'}},
        # Departments — simple lookup, no expr
        {'$lookup': {'from': Collections.DEPARTMENTS, 'localField': 'stream_ids', 'foreignField': 'stream_id', 'as': 'department_details'}},
        # Streams — simple lookup, no expr
        {'$lookup': {'from': Collections.STREAMS, 'localField': 'stream_ids', 'foreignField': '_id', 'as': 'stream_details'}},
        # Completion — simple lookup, no expr
        {'$lookup': {'from': Collections.COURSE_COORDINATION_COURSE_COMPLETION, 'localField': '_id', 'foreignField': 'lms_node_id', 'as': 'completion_raw'}},
        # ── All filtering + derivation in $addFields ──────────────────────────
        {
            '$addFields': {
                # Filter videos: is_deleted=false, multilingual_video exists, is_multilingual true or missing
                'videos_filtered': {'$filter': {'input': '$all_videos', 'as': 'v', 'cond': {'$and': [{'$eq': ['$$v.is_deleted', False]}, {'$ifNull': ['$$v.multilingual_video', False]}]}}},
                # Filter program_relations: is_deleted=false
                'program_relations_active': {'$filter': {'input': '$program_relations', 'as': 'pr', 'cond': {'$eq': ['$$pr.is_deleted', False]}}},
                # Filter departments: is_deleted=false
                'department_details': {'$filter': {'input': '$department_details', 'as': 'd', 'cond': {'$eq': ['$$d.is_deleted', False]}}},
                # Filter completion: is_deleted=false
                'completion_active': {'$filter': {'input': '$completion_raw', 'as': 'cd', 'cond': {'$eq': ['$$cd.is_deleted', False]}}},
                # Submodule count from meta_data
                'submodule_count': {'$ifNull': ['$meta_data.total_submodules', 0]},
            }
        },
        # ── Compute ML stats ─────────────────────────────────────────────────
        {
            '$addFields': {
                'total_ml_videos': {'$size': {'$ifNull': ['$videos_filtered', []]}},
                '_ml_pending': {'$size': {'$filter': {'input': {'$ifNull': ['$videos_filtered', []]}, 'as': 'v', 'cond': {'$eq': ['$$v.multilingual_video.status', MultilingualVideoStatus.PENDING]}}}},
                '_ml_success': {'$size': {'$filter': {'input': {'$ifNull': ['$videos_filtered', []]}, 'as': 'v', 'cond': {'$eq': ['$$v.multilingual_video.status', MultilingualVideoStatus.SUCCESS]}}}},
                '_ml_failed': {'$size': {'$filter': {'input': {'$ifNull': ['$videos_filtered', []]}, 'as': 'v', 'cond': {'$eq': ['$$v.multilingual_video.status', MultilingualVideoStatus.FAIL]}}}},
                '_total_stages': {
                    '$reduce': {'input': {'$ifNull': ['$videos_filtered', []]}, 'initialValue': 0, 'in': {'$add': ['$$value', {'$ifNull': ['$$this.multilingual_video.stages_completed', 0]}]}}
                },
                # Programs — map to only _id + name
                'programs': {'$map': {'input': {'$ifNull': ['$programs_raw', []]}, 'as': 'p', 'in': {'_id': '$$p._id', 'name': '$$p.name'}}},
                # Streams — map to only _id + stream_name
                'stream_ids': {'$map': {'input': {'$ifNull': ['$stream_details', []]}, 'as': 's', 'in': {'_id': '$$s._id', 'stream_name': '$$s.stream_name'}}},
                # Department — map to only _id + name
                'department_details': {'$map': {'input': {'$ifNull': ['$department_details', []]}, 'as': 'd', 'in': {'_id': '$$d._id', 'name': '$$d.name'}}},
                # Coordinator — only for label=course AND status=PUBLISHED
                # No $expr — use $cond on outer doc fields directly
                '_coordinator': {'$cond': {'if': {'$and': [{'$eq': ['$label', 'course']}, {'$eq': ['$status', 'PUBLISHED']}]}, 'then': {'$arrayElemAt': ['$coordinator_raw', 0]}, 'else': None}},
                # Completion
                'is_completed': {'$arrayElemAt': ['$completion_active.is_completed', 0]},
                'completed_date': {'$arrayElemAt': ['$completion_active.completed_date', 0]},
            }
        },
        # ── Coordinator fields extract ────────────────────────────────────────
        {'$addFields': {'course_coordinator_name': '$_coordinator.first_name', 'course_coordinator_email': '$_coordinator.email', 'profile_image_data': '$_coordinator.profile_image_data'}},
        # ── ML status — using $cond chain instead of $switch (more compatible) ─
        {
            '$addFields': {
                'multilingual_video_status': {
                    '$cond': {
                        'if': {'$and': [{'$gt': ['$total_ml_videos', 0]}, {'$eq': ['$_ml_pending', 0]}, {'$eq': ['$_ml_success', '$total_ml_videos']}]},
                        'then': MultilingualVideoStatus.SUCCESS,
                        'else': {
                            '$cond': {
                                'if': {'$and': [{'$gt': ['$total_ml_videos', 0]}, {'$eq': ['$_ml_pending', 0]}, {'$eq': ['$_ml_failed', '$total_ml_videos']}]},
                                'then': MultilingualVideoStatus.FAIL,
                                'else': {
                                    '$cond': {
                                        'if': {'$and': [{'$gt': ['$total_ml_videos', 0]}, {'$eq': ['$_ml_pending', 0]}]},
                                        'then': MultilingualVideoStatus.PARTIAL,
                                        'else': MultilingualVideoStatus.PENDING,
                                    }
                                },
                            }
                        },
                    }
                },
                'completion_percentage': {
                    '$cond': {'if': {'$gt': ['$total_ml_videos', 0]}, 'then': {'$multiply': [{'$divide': ['$_total_stages', {'$multiply': ['$total_ml_videos', 7]}]}, 100]}, 'else': 0}
                },
                # Sort key
                'sort_key': {
                    '$cond': {
                        'if': {'$and': [{'$eq': ['$label', 'course']}, {'$eq': ['$node_level', 1]}]},
                        'then': {'$cond': {'if': {'$eq': [course_status, 'PUBLISHED']}, 'then': '$published_at', 'else': '$created_at'}},
                        'else': None,
                    }
                },
            }
        },
    ]

    # ── Filters ──────────────────────────────────────────────────────────────
    if is_valid_list(filter_data.get('faculty')):
        aggregate_pipeline.append({'$match': {'stream_ids._id': {'$in': filter_data['faculty']}}})

    if is_valid_list(filter_data.get('program')):
        aggregate_pipeline.append({'$match': {'department_details._id': {'$in': filter_data['program']}}})

    if is_valid_list(filter_data.get('batch')):
        aggregate_pipeline.append({'$match': {'programs._id': {'$in': filter_data['batch']}}})

    # ── Sort ─────────────────────────────────────────────────────────────────
    aggregate_pipeline.append({'$sort': {'order': 1, 'sort_key': -1, 'created_at': 1}})

    # ── Final $project ────────────────────────────────────────────────────────
    aggregate_pipeline.append(
        {
            '$project': {
                '_id': 1,
                'created_at': 1,
                'updated_at': 1,
                'is_deleted': 1,
                'course_type': 1,
                'description': 1,
                'node_level': 1,
                'label': 1,
                'parent_identifier': 1,
                'status': 1,
                'title': 1,
                'course_code': {'$ifNull': ['$course_code', 'NA']},
                'course_credit': {'$ifNull': ['$course_credit', 'NA']},
                'program_id': 1,
                'submodule_count': 1,
                'programs': 1,
                'department': '$department_details',
                'completion_percentage': 1,
                'file_data.file_name': 1,
                'file_data.key': {'$ifNull': ['$multilingual_video.key', '$file_data.key']},
                'file_data.file_size': {'$ifNull': ['$multilingual_video.file_size', '$file_data.file_size']},
                'file_data.mime_type': {'$ifNull': ['$multilingual_video.mime_type', '$file_data.mime_type']},
                'file_data.file': {'$ifNull': ['$multilingual_video.file', '$file_data.file']},
                'file_data.languages': {'$ifNull': ['$multilingual_video.languages', []]},
                'preview_image_data': 1,
                'staff_assigned_status': 1,
                'parent_node_id': 1,
                'department_id': 1,
                'published_at': 1,
                'stream_ids': 1,
                'course_coordinator_name': 1,
                'course_coordinator_email': 1,
                'profile_image_data': 1,
                'desired_gender': 1,
                'is_completed': 1,
                'completed_date': 1,
                'multilingual_video_status': 1,
                'total_ml_videos': 1,
                'is_multilingual': {'$ifNull': ['$is_multilingual', True]},
                'is_track_progress': {'$ifNull': ['$is_track_progress', True]},
                'resources': {'$ifNull': ['$resources', []]},
                'is_view': {'$ifNull': ['$is_view', True]},
            }
        }
    )

    course_list_data = await core_service.query_read_all(collection_name=Collections.LMS_MAPPING, aggregate=aggregate_pipeline)

    await generate_presigned_urls_for_profile_images(course_list_data, is_paginated=False)
    await validate_course_list_response(course_list_data)

    return course_list_data


async def generate_presigned_urls_for_profile_images(data: list[dict], is_paginated: bool) -> None:
    """Mutates data in-place. All HTTP calls run concurrently."""
    target_data = data['data'] if is_paginated else data
    if not target_data:
        return

    async def _process_item(item: dict) -> None:
        tasks = []

        if item.get('profile_image_data') and item['profile_image_data'].get('key'):

            async def _set_profile_url(i=item):
                i['profile_image_data']['file_url'] = await generate_presigned_url(i['profile_image_data']['key'])

            tasks.append(_set_profile_url())

        if item.get('file_data') and item['file_data'].get('key'):
            file_name = item['file_data'].get('file_name', '')
            if file_name.lower().endswith('.pdf'):

                async def _set_file_url(i=item):
                    url = i['file_data']['file']
                    async with aiohttp.ClientSession() as session:
                        try:
                            async with session.head(url, timeout=aiohttp.ClientTimeout(total=3)) as resp:
                                if resp.status != 200 and config.AWS_HOST:
                                    i['file_data']['file'] = config.AWS_HOST + i['file_data']['key']
                        except Exception:
                            if config.AWS_HOST:
                                i['file_data']['file'] = config.AWS_HOST + i['file_data']['key']

                tasks.append(_set_file_url())

        if tasks:
            await asyncio.gather(*tasks)

    # All items processed concurrently
    await asyncio.gather(*[_process_item(item) for item in target_data])
