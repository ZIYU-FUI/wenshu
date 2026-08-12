# Third-Party Licenses

This directory contains license notices for third-party software bundled with 文枢 (Wenshu).

## Acknowledgements

文枢 (Wenshu) includes the following third-party software:

### Lucide for Swift (ISC)
- **Source**: https://github.com/ajaxjiang96/lucide-swift
- **Upstream**: https://lucide.dev | https://github.com/lucide-icons/lucide
- **License**: ISC — https://opensource.org/licenses/ISC
- **Used by**: WenshuApp target (added v0.05.0, ICON v2 phase)
- **Copyright**: Copyright (c) 2024 LucideSwift contributors (see `lucide-swift-LICENSE`)

### Lucide Icons (ISC)
- **Source**: https://github.com/lucide-icons/lucide
- **License**: ISC — https://opensource.org/licenses/ISC
- **Used by**: Lucide for Swift (indirect dependency)
- **Copyright**: Copyright (c) 2026 Lucide Icons and Contributors (see `lucide-icons-LICENSE`)

## Rationale

Per AGENTS.md §3.9 (AIF 拍板 / 2026-08-12) and t_b1e81260-ICON-v2-LIB §1,
the project adopts Lucide for Swift as the long-term ICON source-of-truth
to consolidate the 6-zone 37-icon mapping across the layout grammar.
The v0.05.0 phase adds the SPM dependency and bakes out the metadata
layer (`IconLibrary.lucideName`); the SF Symbol namespace remains as
the rendered path until v0.05.x completes the Lucide rendering migration
(`Image(uiImage:)` swap-in).

## License files in this directory

- `lucide-swift-LICENSE` — Copy of the ISC license from ajaxjiang96/lucide-swift@main
- `lucide-icons-LICENSE` — Copy of the ISC license from lucide-icons/lucide@main

Both files are committed as plain text to satisfy v0.05.0 packaging
compliance (third-party redistribution notice) ahead of any future
binary distribution.
