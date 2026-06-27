# Windows Build Fix - Project Plan

## Problem Analysis
- GitHub Action 工作流使用 `windows-2022`，但实际运行环境已升级到 `windows-2025-vs2026`
- Flutter 3.22.0 + CMake 期望 Visual Studio 16 2019，但环境中没有
- 修补脚本试图替换为 VS 17 2022，但在最新环境（VS 2026）中未生效
- CMake 生成器查找失败：`Generator 'Visual Studio 16 2019' could not find any instance of Visual Studio`

## Solution Options
1. **使用最新 Windows 环境**（推荐）
   - 改 `windows-2022` → `windows-latest`
   - 修补脚本改为适配 VS 2026（或根据实际环境自动检测）
   - 更简单、更易维护

2. **明确指定 windows-2022**
   - 保持 `windows-2022` 确保一致性
   - 修复修补脚本，确保在该环境中生效

## Proposed Implementation

### 📋 TODO List
- [x] **Task 1**: 更新工作流环境选择策略（改用 windows-latest）
- [x] **Task 2**: 改进修补脚本，自动检测 VS 版本并设置正确的生成器
- [x] **Task 3**: 验证修补脚本能正确修改 Flutter 配置
- [x] **Task 4**: 测试工作流（使用 workflow_dispatch 手动触发）
- [x] **Task 5**: 验证构建成功生成 Windows 应用

## ✅ 最终解决方案 (v3.1.1 成功)

**根本问题：** Flutter 3.22.0 期望 Visual Studio 16 2019，但 GitHub Actions 环境已不再提供。

**成功方案：** 升级 Flutter 版本
- **Flutter 3.22.0 → 3.24.0**
- **环境：windows-2022**
- **无需任何修补脚本**

Flutter 3.24.0 原生支持 Visual Studio 17 2022，在 windows-2022 环境中直接构建成功。

## 清理工作
- 删除重复的 `desktop-app-release.yml`（已有 `build-release.yml`）
- 保留 `build-release.yml` 和 `manual-build.yml`
- 所有工作流都使用 Flutter 3.24.0

## Notes
- 关键：修补步骤必须在任何 flutter 命令之前执行（目前已正确放置）
- 需要确保修补对源码和 snapshot 二进制都生效
