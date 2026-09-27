You are an expert in TypeScript, Angular, and scalable web application development. You write functional, maintainable, performant, and accessible code following Angular and TypeScript best practices.

> **Projektkontext:** Angular-Web-Part des Work Time Manager Monorepos.
> Architektur, Services und Firebase-Regeln: `CLAUDE.md` (in diesem Ordner), übergreifende Regeln: `../CLAUDE.md`, Arbeitsablauf: `../CONTRIBUTING.md`.
> Allgemeine Angular-Regeln stehen nur hier. `CLAUDE.md` und `.gemini/GEMINI.md` importieren diese Datei.
>
> Wichtigste Zusatzregeln:
> - KEIN `standalone: true` (Angular v20+ Default), KEIN `CommonModule`.
> - Firebase nur über `@angular/fire/*`, nie `firebase/*` mischen. Details in `CLAUDE.md`.
> - Neue User-Texte über ngx-translate, Keys in `public/i18n/de.json` und `en.json`.
> - Tests laufen mit Vitest: `npm test -- --watch=false`.
> - Dateinamen ohne Typ-Suffix (`dashboard.ts`, nicht `dashboard.component.ts`). Details unten.

## TypeScript Best Practices

- Use strict type checking
- Prefer type inference when the type is obvious
- Avoid the `any` type; use `unknown` when type is uncertain

## Dateinamen (#301)

Dateinamen ohne Typ-Suffix, entsprechend dem aktuellen Angular-Styleguide (v20): `dashboard.ts`
statt `dashboard.component.ts`, `work-entry.ts` statt `work-entry.service.ts`. Gilt für Components,
Services (Core-, Feature- und Domain-Services) und deren `.html`/`.scss`/`.spec.ts`-Begleitdateien.

**Ausnahme (Namenskollision):** Teilen sich eine Component und ein Service denselben Basisnamen
im selben Ordner — etwa `features/dashboard/dashboard.ts` (Component) und der zugehörige
Feature-Service —, behält der Service den Suffix `.service.ts` (`dashboard.service.ts`), damit
beide Dateien nebeneinander existieren können. Diese Ausnahme betrifft aktuell nur die
Feature-Services (`dashboard.service.ts`, `reports.service.ts`, `settings.service.ts`).

## Angular Best Practices

- Standalone components only, never NgModules — but do NOT set `standalone: true` explicitly
  inside Angular decorators, since it's the default in Angular v20+ and writing it is redundant.
- Use signals for state management
- Implement lazy loading for feature routes
- Do NOT use the `@HostBinding` and `@HostListener` decorators. Put host bindings inside the `host` object of the `@Component` or `@Directive` decorator instead
- Use `NgOptimizedImage` for all static images.
  - `NgOptimizedImage` does not work for inline base64 images.

## Accessibility Requirements

- It MUST pass all AXE checks.
- It MUST follow all WCAG AA minimums, including focus management, color contrast, and ARIA attributes.

### Components

- Keep components small and focused on a single responsibility
- Use `input()` and `output()` functions instead of decorators
- Use `computed()` for derived state
- Set `changeDetection: ChangeDetectionStrategy.OnPush` in `@Component` decorator
- Prefer inline templates for small components
- Prefer Reactive forms instead of Template-driven ones
- Do NOT use `ngClass`, use `class` bindings instead
- Do NOT use `ngStyle`, use `style` bindings instead
- When using external templates/styles, use paths relative to the component TS file.

## State Management

- Use signals for local component state
- Use `computed()` for derived state
- Keep state transformations pure and predictable
- Do NOT use `mutate` on signals, use `update` or `set` instead

## Templates

- Keep templates simple and avoid complex logic
- Use native control flow (`@if`, `@for`, `@switch`) instead of `*ngIf`, `*ngFor`, `*ngSwitch`
- Use the async pipe to handle observables
- Do not assume globals like (`new Date()`) are available.

## Services

- Design services around a single responsibility
- Use the `providedIn: 'root'` option for singleton services
- Use the `inject()` function instead of constructor injection
