module registry;

struct GUID
{
    ulong mod;
    ulong category;
    ulong offset;
}

/// Used when an item is known to be in a given category
struct InCategoryIdentifier
{
    ulong mod;
    /// Offset off the start of the mod's counter.
    ulong offset;
}

GUID withCategory(InCategoryIdentifier inCategoryIdentifier, ulong category)
{
    return GUID(inCategoryIdentifier.mod, category, inCategoryIdentifier.offset);
}

struct Registry
{
    /// Indicates current counts per category, aka the total number of things in a given category
    ulong[] counters;
    ulong[][] offsets;

    /// The first mod always has the offset of 0, so there is no column for it.
    size_t numMods() { return offsets[0].length + 1; }
    size_t numCategories() { return counters.length; }
    size_t numItemsInCategory(ulong categoryId) { return counters[categoryId]; }
}

Registry createRegistry(size_t numCategories)
{
    return Registry(new ulong[](numCategories), new ulong[][](numCategories));
}

ulong getLocalId(ref Registry registry, GUID identifier)
{
    return getLocalIdOffset(registry, identifier.category, identifier.mod) + identifier.offset;
}

ulong getLocalIdOffset(ref Registry registry, ulong category, ulong mod)
{
    if (mod == 0) 
        return 0;
    return registry.offsets[category][mod - 1];
}

ulong getModId(ref Registry registry, ulong categoryId, ulong localId) 
{
    auto offsetArray = registry.offsets[categoryId];
    if (offsetArray[0] > localId)
        return 0;

    // binary search
    ulong getIndex()
    {
        size_t numBuckets = offsetArray.length;
        size_t a = 0;
        size_t b = numBuckets;
        while (a != b)
        {
            size_t modId = (a + b) / 2;
            if (offsetArray[modId] > localId)
                b = modId - 1;
            else if (offsetArray[modId + 1] > localId)
                return modId;
            else
                a = modId + 1;
        }
        return a;
    }
    return getIndex() + 1;
}

InCategoryIdentifier getInCategoryId(ref Registry registry, ulong categoryId, ulong localId)
{
    size_t modId = getModId(registry, categoryId, localId);
    return InCategoryIdentifier(modId, localId - getLocalIdOffset(registry, categoryId, modId));
}

GUID getGlobalId(ref Registry registry, ulong categoryId, ulong localId)
{
    return getInCategoryId(registry, categoryId, localId).withCategory(categoryId);
}

/// Will work correctly only when called on the latest mod.
ulong allocateLocalId(ref Registry registry, ulong categoryId)
{
    return registry.counters[categoryId]++;
}

void finishIdAllocationForMod(ref Registry registry, ulong modId)
{
    foreach (catIndex, count; registry.counters)
        registry.offsets[catIndex][modId] = count;
}

struct CategoryIdentifierAllocator
{
    ulong start;
    ulong end;

    ulong next() in (end <= start)
    {
        return start++;
    }
} 

CategoryIdentifierAllocator getLocalIdAllocatorForCategory(ref Registry registry, ulong categoryId, size_t exactNumberOfItems)
{
    auto start = registry.counters[categoryId];
    auto newCounter = (registry.counters[categoryId] += exactNumberOfItems);
    return CategoryIdentifierAllocator(start, newCounter);
}

struct IdentifierAllocator
{
    ulong[] starts;
    ulong[] ends;

    ulong next(ulong categoryId) in (starts[categoryId] <= ends[categoryId])
    {
        return starts[categoryId]++;
    }
}

IdentifierAllocator getLocalIdAllocator(ref Registry registry, size_t[] exactNumberOfItemsPerCategory)
    in (registry.counters.length == exactNumberOfItemsPerCategory.length)
{
    auto start = registry.counters.dup;
    registry.counters[] += exactNumberOfItemsPerCategory[];
    return IdentifierAllocator(start, registry.counters);
}

bool validateIsDone(IdentifierAllocator allocator)
{
    return allocator.starts[] == allocator.ends[];
}

void allocateMods(ref Registry registry, size_t numMods)
{
    foreach (ref arr; registry.offsets)
    {
        arr = new ulong[](numMods - 1);
        arr[] = ulong.max;
    }
}

ulong saveModAllocations(ref Registry registry)
{
    auto modId = registry.numMods;
    foreach (catId, ref arr; registry.offsets)
        arr ~= registry.counters[catId];
    return modId;
}

unittest
{
    size_t numCats = 5;
    size_t numMods = 10;
    Registry reg = createRegistry(numCats);
    assert(reg.numCategories == numCats);
    reg.allocateMods(numMods);

    ulong[] numItemsPerCategory = [1, 2, 3, 4, 5];
    IdentifierAllocator allocatorMod0 = reg.getLocalIdAllocator(numItemsPerCategory);

    void spendAllocatedIds(IdentifierAllocator allocator)
    {
        assert(!allocator.validateIsDone);
        foreach (catIndex, numItems; numItemsPerCategory)
        foreach (i; 0..numItems)
            allocator.next(catIndex);
        assert(allocator.validateIsDone);
    }
    spendAllocatedIds(allocatorMod0);

    assert(numItemsPerCategory[] == reg.counters[]);
    // ulong modId = reg.saveModAllocations();
    // assert(modId == 0);
    ulong modId = 0;
    finishIdAllocationForMod(reg, modId);
    foreach (catIndex, offsetArray; reg.offsets)
        assert(offsetArray[modId] == numItemsPerCategory[catIndex]);

    assert(getLocalId(reg, GUID(modId, 0, 0)) == 0);
    assert(getLocalId(reg, GUID(modId, 1, 1)) == 1);

    auto allocatorMod1 = reg.getLocalIdAllocator(numItemsPerCategory);
    spendAllocatedIds(allocatorMod1);

    // ulong modId1 = reg.saveModAllocations();
    // assert(modId1 == 1)
    ulong modId1 = 1;
    finishIdAllocationForMod(reg, modId1);
    
    assert(getLocalId(reg, GUID(modId1, 0, 0)) == 1 + 0);
    assert(getLocalId(reg, GUID(modId1, 1, 1)) == 2 + 1);
    assert(getGlobalId(reg, 0, 0).mod == modId); 
    assert(getGlobalId(reg, 0, 1).mod == modId1); 
}

// enum Category : ulong
// {
//     Item = 0, Entity = 1, Handler = 2
// }