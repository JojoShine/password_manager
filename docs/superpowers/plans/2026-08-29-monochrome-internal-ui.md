# Monochrome Internal UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a restrained black, white, and warm-gray visual system to light-mode internal pages and dialogs without changing the homepage, dark mode, or application behavior.

**Architecture:** Add a scoped `InternalUiTheme` and reusable light-mode visual tokens instead of changing the app-wide `ThemeData`. Wrap only the settings page, browser-extension page, and selected dialogs, then replace their local gradients, large radii, colored decorative surfaces, and ordinary shadows with the scoped styles.

**Tech Stack:** Flutter, Material 3, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-08-29-monochrome-internal-ui-design.md`

## Global Constraints

- Do not add UI dependencies.
- Keep homepage layout, password list, category structure, login page, and dark-mode color direction unchanged.
- Light surfaces use `#F4F4F1`, `#FBFBFA`, `#181817`, `#6F6F6B`, `#D8D8D3`, and `#EFEFEC`.
- Controls use `6px`, groups use `8px`, and dialogs use `12px` radii.
- Ordinary surfaces and controls have zero shadow; only actual overlays may use a subtle shadow.
- Do not change download, save, import/export, encryption, or password-management behavior.

---

### Task 1: Scoped internal visual system

**Files:**
- Create: `lib/theme/internal_ui_theme.dart`
- Create: `test/internal_ui_theme_test.dart`

**Interfaces:**
- Produces: `InternalUiTokens` color/radius constants, `InternalUiTheme.resolve(ThemeData)`, `InternalUiTheme.surfaceDecoration(BuildContext, {double radius})`, and the `InternalUiTheme` wrapper widget.

- [ ] **Step 1: Write failing theme tests**

Test literal requirements: light-mode elevated buttons resolve to elevation `0`, radius `6`, near-black background; outlined buttons use radius `6`; inputs use radius `6`; dark input and button themes remain the exact base theme instances; light surface decoration has radius `8`, one neutral border, and no box shadow.

- [ ] **Step 2: Run the focused test and confirm the missing API failure**

Run: `flutter test test/internal_ui_theme_test.dart`

- [ ] **Step 3: Implement the scoped theme**

Create constants for the six approved colors and three radii. `resolve` returns the original theme for dark mode and a `copyWith` theme for light mode:

```dart
static ThemeData resolve(ThemeData base) {
  if (base.brightness == Brightness.dark) return base;
  return base.copyWith(
    scaffoldBackgroundColor: InternalUiTokens.pageBackground,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: InternalUiTokens.ink,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    ),
  );
}
```

Add equivalent outlined, text, icon-button, and input themes. Keep dark mode unchanged.

- [ ] **Step 4: Run the focused test**

Run: `flutter test test/internal_ui_theme_test.dart`

---

### Task 2: Settings and browser-extension pages

**Files:**
- Modify: `lib/pages/settings_page.dart`
- Modify: `lib/pages/browser_extension_page.dart`
- Test: `test/internal_pages_style_test.dart`

**Interfaces:**
- Consumes: `InternalUiTheme`, `InternalUiTokens`, and `surfaceDecoration` from Task 1.

- [ ] **Step 1: Write page-level widget tests**

Pump both pages under a light base theme and assert: their scoped `Scaffold` uses `#F4F4F1`; settings section surfaces have elevation `0`, radius `8`, and a neutral border; the extension download action uses the near-black internal primary style; no overflow exception occurs at `1280×800`.

- [ ] **Step 2: Run tests and confirm current visual properties fail**

Run: `flutter test test/internal_pages_style_test.dart`

- [ ] **Step 3: Apply the scoped theme and neutral surfaces**

Wrap each page with `InternalUiTheme`. Replace settings `Card(elevation: 2, radius: 16)` with a zero-shadow bordered `Container` using `surfaceDecoration`. Constrain settings content to a centered maximum width. On the extension page, replace the blue gradient download card, colored feature pills, amber notice, circular step badges, and blue icon tiles with neutral surfaces, `4/6/8px` radii, and semantic typography. Preserve all callbacks and download state.

- [ ] **Step 4: Run page tests**

Run: `flutter test test/internal_pages_style_test.dart`

---

### Task 3: Internal dialogs

**Files:**
- Modify: `lib/widgets/password_add_dialog.dart`
- Modify: `lib/widgets/password_generator_dialog.dart`
- Modify: `lib/widgets/decrypt_password_dialog.dart`
- Modify: `lib/widgets/export_options_dialog.dart`
- Test: `test/internal_dialog_style_test.dart`

**Interfaces:**
- Consumes: `InternalUiTheme`, `InternalUiTokens`, and dialog/surface helpers from Task 1.

- [ ] **Step 1: Write dialog style tests**

Pump representative dialogs in light and dark themes. Assert light dialogs use radius `12`, neutral headers, zero nested-surface shadows, and `6px` controls; assert dark dialog colors continue to resolve from the original dark theme. Verify visible primary actions and absence of layout exceptions.

- [ ] **Step 2: Run tests and confirm current `16/20px` radii and decorative colors fail**

Run: `flutter test test/internal_dialog_style_test.dart`

- [ ] **Step 3: Apply dialog visual rules**

Wrap dialog content with `InternalUiTheme`, change dialog radius to `12`, remove manually added ordinary shadows, change internal cards to neutral weak backgrounds and borders, use `6px` controls and `8px` information groups, and reserve red/green for destructive/success states. Keep every form controller, validator, animation, and callback unchanged.

- [ ] **Step 4: Run dialog tests**

Run: `flutter test test/internal_dialog_style_test.dart`

---

### Task 4: Regression and visual verification

**Files:**
- Modify only if required by verified regressions: files already listed above

- [ ] **Step 1: Format and statically analyze changed Dart files**

Run: `dart format lib/theme/internal_ui_theme.dart lib/pages/settings_page.dart lib/pages/browser_extension_page.dart lib/widgets/password_add_dialog.dart lib/widgets/password_generator_dialog.dart lib/widgets/decrypt_password_dialog.dart lib/widgets/export_options_dialog.dart test/internal_ui_theme_test.dart test/internal_pages_style_test.dart test/internal_dialog_style_test.dart`

Run: `flutter analyze`

- [ ] **Step 2: Run the complete Flutter test suite**

Run: `flutter test`

- [ ] **Step 3: Render representative light-mode pages**

Run the macOS application or focused widget harness at a desktop viewport, capture the settings page, browser-extension page, and one dialog, and verify the spec checklist: no ordinary shadow, `6/8/12px` radius hierarchy, neutral button hierarchy, unchanged homepage structure, and no overflow.

- [ ] **Step 4: Review the final diff**

Confirm every changed production line maps to the approved spec and that the existing unrelated browser-extension ZIP change remains untouched.
