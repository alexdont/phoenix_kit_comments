# Changelog

All notable changes to PhoenixKitComments will be documented in this file.

## Unreleased

### Features

- Add resource path templates with metadata placeholder support. Admins can configure URL patterns
  per resource type in settings (e.g. `/order/shoes/:uuid`). Templates support `:uuid` and
  `:metadata.KEY` placeholders for building links from comment metadata. Shows unconfigured
  resource types from the DB with comment counts for easy setup.

### Bug Fixes

- Fix nested forms in settings page — Resource Link Patterns card was rendered inside the main
  settings `<form>`, producing invalid HTML. Moved outside the form to prevent unpredictable
  browser behavior.
- Fix stale assigns after adding/removing resource path templates — `unconfigured_types` now
  stays in sync without requiring a page refresh.
- Add path template input validation — templates must start with `/` and cannot contain `://`,
  preventing XSS via `javascript:` URIs and open redirects via protocol-relative URLs.
- Add `Logger.warning` to rescue blocks in `count_comments_by_type/0` and
  `get_resource_path_templates/0` instead of silently swallowing errors.

## v0.1.0 — 2026-03-27

### Features

- Initial release — polymorphic comments module extracted from PhoenixKit.
- Resource-agnostic design via `(resource_type, resource_uuid)` tuples with no FK constraints.
- Unlimited self-referencing comment threading with configurable max depth.
- Like/dislike system with denormalized counters and transactional safety.
- Moderation workflow: pending, published, hidden, deleted statuses with bulk operations.
- Admin UI: paginated comment list with search, status filters, and resource type grouping.
- Settings UI: toggles for enable/moderation, configurable max depth and max length.
- Resource handler callbacks for `on_comment_created/3` and `on_comment_deleted/3`.
- Resource resolution system with handler-based and path-template-based fallbacks.
- ILIKE search with proper wildcard escaping.
- Soft delete preserving comment tree structure.
