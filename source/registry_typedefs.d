module registry_typedefs;

alias Identifier = ulong;
alias LocalIdentifier = ulong;
ref size_t index(ref return Identifier id) { return id; } 
ref Identifier ident(ref return size_t index) { return index; }
ref LocalIdentifier localIdent(ref return size_t index) { return index; }

struct GUID
{
    Identifier mod;
    Identifier category;
    Identifier offset;
}

/// Used when an item is known to be in a given category
struct InCategoryIdentifier
{
    Identifier mod;
    /// Offset off the start of the mod's counter.
    Identifier offset;
}

GUID withCategory(InCategoryIdentifier inCategoryIdentifier, Identifier category)
{
    return GUID(inCategoryIdentifier.mod, category, inCategoryIdentifier.offset);
}

struct Registry
{
    /// Indicates current counts per category, aka the total number of things in a given category
    Identifier[] counters;
    Identifier[][] offsets;

    /// The first mod always has the offset of 0, so there is no column for it.
    size_t numMods() { return offsets[0].length + 1; }
    size_t numCategories() { return counters.length; }
    size_t numItemsInCategory(Identifier categoryId) { return counters[categoryId.index]; }
}

Registry createRegistry(size_t numCategories)
{
    return Registry(new Identifier[](numCategories), new Identifier[][](numCategories));
}
unittest
{
    auto reg = createRegistry(2);
    assert(reg.numCategories == 2);
}

Identifier getLocalId(ref Registry registry, GUID identifier)
{
    return getLocalIdOffset(registry, identifier.category, identifier.mod) + identifier.offset;
}

LocalIdentifier getLocalIdOffset(ref Registry registry, Identifier category, Identifier mod)
{
    return registry.offsets[category.index][mod.index];
}

Identifier getModId(ref Registry registry, Identifier categoryId, LocalIdentifier localId) 
{
    // binary search
    auto offsetArray() { return registry.offsets[categoryId.index]; }
    size_t numBuckets = offsetArray.length;
    size_t a = 0;
    size_t b = numBuckets;

    while (a != b)
    {
        size_t modId = (a + b) / 2;
        if (offsetArray[modId] > localId.index)
            b = modId - 1;
        else if (offsetArray[modId + 1] > localId.index)
            return modId;
        else
            a = modId + 1;
    }
    return a;
}

InCategoryIdentifier getInCategoryId(ref Registry registry, Identifier categoryId, LocalIdentifier localId)
{
    size_t modId = getModId(registry, categoryId, localId);
    return InCategoryIdentifier(modId, localIdent(localId.index - getLocalIdOffset(registry, categoryId, modId).index));
}

GUID getGlobalId(ref Registry registry, Identifier categoryId, LocalIdentifier localId)
{
    return getInCategoryId(registry, categoryId, localId).withCategory(categoryId);
}

/// Will work correctly only when called on the latest mod.
LocalIdentifier allocateLocalId(ref Registry registry, Identifier categoryId)
{
    return localIdent(registry.counters[categoryId]++);
}

void finishGettingIdsForMod(ref Registry registry, Identifier modId)
{
    foreach (catIndex, count; registry.counters)
        registry.offsets[catIndex][modId] = count;
}

struct CategoryIdentifierAllocator
{
    size_t start;
    size_t end;

    LocalIdentifier next() in (start <= end)
    {
        return localIdent(start++);
    }
} 

CategoryIdentifierAllocator getLocalIdAllocatorForCategory(ref Registry registry, Identifier categoryId, size_t exactNumberOfItems)
{
    auto offset = &registry.counters[categoryId].index;
    auto start = *offset;
    (*offset) += exactNumberOfItems;
    return CategoryIdentifierAllocator(start, *offset);
}

struct IdentifierAllocator
{
    size_t[] starts;
    size_t[] ends;

    Identifier next(Identifier categoryId) in (start[categoryId.index] <= end[categoryId.index])
    {
        return start[categoryId]++;
    }
}

IdentifierAllocator getLocalIdAllocator(ref Registry registry, size_t[] exactNumberOfItemsPerCategory)
    in (registry.counters.length == exactNumberOfItemsPerCategory.length)
{
    auto start = registry.counters.dup;
    registry.counters[] += exactNumberOfItemsPerCategory[];
    return IdentifierAllocator(start, registry.counters);
}

bool validateDoneAllocator(IdentifierAllocator allocator, ref Registry registry)
{
    return allocator.ends[] == registry.counters[];
}

void allocateMods(ref Registry registry, size_t numMods)
{
    foreach (ref arr; registry.counters)
        arr = new Identifier[](numMods - 1);
}

Identifier allocateMod(ref Registry registry)
{
    registry.
}

enum Category : Identifier
{
    Item = 0, Entity = 1, Handler = 2
}


void main()
{

}