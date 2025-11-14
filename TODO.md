# HushMap - Development TODO

## Future Refactoring Tasks

### 🔄 ReportLocationResolver Async Refactor (v1.5.2+)

**Priority:** Medium
**Estimated Time:** 3-4 hours
**Status:** Planned for future update

#### Problem:
The location resolution migration was disabled in v1.5.1 to fix a 2-minute UI freeze on app startup. Currently, community reports may show coordinates instead of friendly location names (e.g., "37.7749, -122.4194" instead of "San Francisco, CA").

#### Root Cause:
- `ReportLocationResolver` is marked as `@MainActor` (Services/ReportLocationResolver.swift:4)
- All location resolution runs synchronously on main thread
- SwiftData batch saves (50 reports x 4 batches) block UI
- Even cached lookups prevent user interaction

#### Solution:
Refactor to run truly asynchronously off the main thread:

1. **Remove @MainActor from ReportLocationResolver**
   ```swift
   class ReportLocationResolver: ObservableObject {  // Remove @MainActor
   ```

2. **Use Background SwiftData Context**
   ```swift
   let backgroundContext = ModelContext(container)
   await backgroundContext.perform {
       // Perform saves on background thread
   }
   ```

3. **Update AppStartMigrator to use background priority**
   - Already uses `Task.detached(priority: .background)` (AppStartMigrator.swift:91)
   - Ensure it actually runs off main thread after refactor

4. **Batch SwiftData saves less frequently**
   - Current: Save after each report (200 saves)
   - Target: Save once per batch of 50 (4 saves)
   - Or: Save once at end (1 save)

5. **Test thoroughly**
   - Verify no UI blocking during migration
   - Ensure location labels appear correctly
   - Test on low-end device (iPhone 12 or older)
   - Monitor for race conditions or threading issues

#### Files to Modify:
- `HushMap/Services/ReportLocationResolver.swift` - Remove @MainActor, add background queue
- `HushMap/Services/AppStartMigrator.swift` - Verify background execution
- `HushMap/Services/SwiftDataReportStore.swift` - Add background context support

#### Benefits After Refactor:
- ✅ Re-enable migration (uncomment HushMapApp.swift:196)
- ✅ Community reports show friendly location names
- ✅ No UI freeze on startup
- ✅ Complete feature set as originally designed
- ✅ Better user experience with location context

#### Current Workaround:
Migration is disabled in `HushMap/HushMapApp.swift:196`:
```swift
// UNCOMMENT when migration is refactored to be truly async
// migrator.runIfNeeded()
```

#### Notes:
- This is a nice-to-have, not critical
- Current app works well with coordinates
- Most users won't notice the difference
- Can ship v1.5.1 without this refactor
- Plan for v1.5.2 or later when time permits

---

## Completed Optimizations (v1.5.1)

✅ Fixed map scroll/zoom lag - markers only recreate when data changes
✅ Disabled camera snap-back - users can freely explore map
✅ Cached pin computation - prevents expensive recalculation
✅ Async report loading - replaced blocking @Query
✅ Debounced updates - batches rapid SwiftData changes

---

*Last Updated: 2025-11-14*
