# UI/UX Overhaul Execution Plan

## Summary
6 大类 22 项 UI/UX 改进，按 P0→P3 分级执行。

## Iteration Reference
`iterations/REQ-ui-ux-overhaul/`

## Execution Order

### Phase P0 (3 tasks)
1. **P0-1** Overview 仪表盘重设计 → OverviewFeatureView.swift
2. **P0-2** Callout 泛滥治理 → 各 FeatureView.swift
3. **P0-3** 最小窗口尺寸 → AtlasApp.swift + AppShellView

### Phase P1 (5 tasks)
4. **P1-1** 侧边栏动态信息 → AtlasRoute + AppShellView
5. **P1-2** 卡片嵌套治理 → AppsFeatureView + SmartClean
6. **P1-3** 键盘快捷键增强 → AtlasAppCommands + AppShellView
7. **P1-4** Skeleton Loading → AtlasDesignSystem 新组件 + Overview/SmartClean
8. **P1-5** File Organizer Metric Cards 响应式 → FileOrganizerFeatureView

### Phase P2 (6 tasks)
9. **P2-1** Toast 组件 → AtlasDesignSystem + AtlasAppModel + AppShellView
10. **P2-2** Undo 机制统一 → AtlasUndoBanner + SmartClean
11. **P2-3** File Organizer 控制面板拆分 → FileOrganizerFeatureView
12. **P2-4** Filter Chips → SmartClean + Apps
13. **P2-5** Settings 嵌套 ScrollView → SettingsFeatureView
14. **P2-6** 图片缓存 → FileThumbnailView

### Phase P3 (4 tasks)
15. **P3-1** 统一 Segment 组件 → AtlasDesignSystem
16. **P3-2** Tooltip 组件 → AtlasDesignSystem
17. **P3-3** 可访问性增强 → 全局
18. **P3-4** Dynamic Type → AtlasTypography

## Key Constraints
- Swift 6.0 strict concurrency
- macOS 14.0+
- AtlasL10n 本地化 (zh-Hans + en)
- 设计 system token 不可修改，但可新增组件
- 不引入第三方依赖

## Checkpoint Protocol
每完成一个 P 级别: swift build → 汇报 → 等待确认 → 继续
