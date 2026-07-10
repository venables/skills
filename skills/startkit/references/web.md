# Variant: TanStack Start web app

STATUS: stub. Not yet implemented. Build the base first, then note to the user
that the web variant is not filled in yet.

Intended deltas over the base (to implement later):

- TanStack Start + React 19 + Vite, latest Tailwind v4 (global CSS file) +
  shadcn/ui. shadcn/ui MUST use Base UI (`@base-ui/react`) as the primitive
  layer, NOT Radix.
- oxlint gains the `react`, `react-perf`, and `jsx-a11y` plugins; `.tsx` files
  are still kebab-case.
- `dev`/`build`/`start` run through Vite instead of node.
- Optional auth: `better-auth`, wired behind a flag the user opts into.
- Data layer: TanStack Query; optional Cloudflare (Wrangler + D1 + kysely).
