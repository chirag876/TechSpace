# This script copies indexes from all collections in one MongoDB database to another, ensuring that the target database maintains the same indexing structure as the source. It helps keep query performance consistent across environments by replicating index configurations without manually recreating them. This is especially useful during database migrations, backups, or when setting up staging and production environments.

from motor.motor_asyncio import AsyncIOMotorClient
import asyncio

SOURCE_URI = "SOURCE_MONGO_URL"
TARGET_URI = "TARGET_MONGO_URI"

SOURCE_DB = "SOURCE_DB"
TARGET_DB = "TARGET_DB"


async def copy_indexes():
    source_client = AsyncIOMotorClient(SOURCE_URI)
    target_client = AsyncIOMotorClient(TARGET_URI)

    source_db = source_client[SOURCE_DB]
    target_db = target_client[TARGET_DB]

    print("🚀 Starting index sync...\n")

    # 🔹 Only real collections (views auto skip)
    cursor = await source_db.list_collections()
    collections_info = await cursor.to_list(length=None)

    collections = []
    for coll in collections_info:
        if coll.get("type") == "collection":
            collections.append(coll["name"])
        else:
            print(f"⚠️ Skipping {coll['name']} (type: {coll.get('type')})")
    total_created = 0
    total_skipped = 0
    total_failed = 0

    for coll_name in collections:
        print(f"\n📦 Processing: {coll_name}")

        try:
            source_coll = source_db[coll_name]
            target_coll = target_db[coll_name]

            source_indexes = await source_coll.index_information()
            target_indexes = await target_coll.index_information()

            # 🔹 Existing target index keys
            target_index_keys = [idx["key"] for idx in target_indexes.values()]

            for idx_name, idx_info in source_indexes.items():

                # 🔹 Skip default _id index
                if idx_name == "_id_":
                    continue

                index_keys = idx_info["key"]

                # 🔹 Skip if same fields already exist
                if index_keys in target_index_keys:
                    print(f"  ⚠️ Skipped {idx_name} (already exists)")
                    total_skipped += 1
                    continue

                # 🔹 Copy options (important)
                options = {
                    k: v for k, v in idx_info.items()
                    if k not in ["key", "v"]
                }

                try:
                    await target_coll.create_index(
                        index_keys,
                        name=idx_name,
                        **options
                    )
                    print(f"  ✅ Created {idx_name}")
                    total_created += 1

                except Exception as e:
                    print(f"  ❌ Failed {idx_name}: {str(e)}")
                    total_failed += 1

        except Exception as e:
            print(f"  ❌ Collection failed: {str(e)}")
            total_failed += 1

    print("\n🎉 Index sync completed!\n")

    # 🔥 Summary
    print("📊 Summary:")
    print(f"  ✅ Created: {total_created}")
    print(f"  ⚠️ Skipped: {total_skipped}")
    print(f"  ❌ Failed: {total_failed}")


if __name__ == "__main__":
    asyncio.run(copy_indexes())
