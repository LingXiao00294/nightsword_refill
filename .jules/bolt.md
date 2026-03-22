## 2025-05-15 - [Global Hook Overhead]
**Learning:** Using `AddComponentPostInit` to wrap component methods for specific items introduces a global performance penalty, as every instance of that component must now perform a tag check. In Don't Starve Together, components like `finiteuses` are extremely common, so this adds up.
**Action:** Use per-instance method overrides within `AddPrefabPostInit` for specific prefabs whenever possible to isolate the logic and avoid global overhead.
