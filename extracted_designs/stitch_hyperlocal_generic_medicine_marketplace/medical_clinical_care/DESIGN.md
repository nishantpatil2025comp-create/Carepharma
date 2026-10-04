---
name: Medical & Clinical Care
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#3d4947'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#6d7a77'
  outline-variant: '#bcc9c6'
  surface-tint: '#006a61'
  primary: '#00685f'
  on-primary: '#ffffff'
  primary-container: '#008378'
  on-primary-container: '#f4fffc'
  inverse-primary: '#6bd8cb'
  secondary: '#006b5f'
  on-secondary: '#ffffff'
  secondary-container: '#6df5e1'
  on-secondary-container: '#006f64'
  tertiary: '#924628'
  on-tertiary: '#ffffff'
  tertiary-container: '#b05e3d'
  on-tertiary-container: '#fffbff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#89f5e7'
  primary-fixed-dim: '#6bd8cb'
  on-primary-fixed: '#00201d'
  on-primary-fixed-variant: '#005049'
  secondary-fixed: '#71f8e4'
  secondary-fixed-dim: '#4fdbc8'
  on-secondary-fixed: '#00201c'
  on-secondary-fixed-variant: '#005048'
  tertiary-fixed: '#ffdbce'
  tertiary-fixed-dim: '#ffb59a'
  on-tertiary-fixed: '#370e00'
  on-tertiary-fixed-variant: '#773215'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
  headline-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-sm:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  label-md:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter-sm: 0.75rem
  gutter-md: 1.5rem
  gutter-lg: 2rem
  margin-screen: 1.5rem
  column-span-1: 8.33%
  column-span-2: 16.66%
  column-span-4: 33.33%
  column-span-6: 50.00%
  column-span-12: 100.00%
---

## Brand & Style

This design system embodies a calm, approachable, and trustworthy clinical aesthetic. Designed specifically for healthcare applications, it combines clinical precision with human warmth to reduce patient anxiety and foster absolute confidence. 

The aesthetic style is **Corporate / Modern** blended with soft **Minimalism**. It relies on generous whitespace, exceptionally legible typography tailored for users of all ages, and comforting organic teal tones that project reliability and health.

## Colors

The color palette anchors the user in a serene, professional environment. 

- **Primary (`#0D9488`):** Deep clinical teal used for primary actions, key interactive states, and strong branding accents.
- **Secondary (`#14B8A6`):** Vibrant mint used for supportive UI elements, positive status indicators, and subtle highlights.
- **Neutral (`#F8FAFC`):** Crisp, light cool-gray background that reduces eye strain while maintaining high contrast against dark slate text.
- **Functional Tints:** Soft surface containers utilize desaturated teal tints to indicate active states, warnings, or informational banners without alarming the user.

## Typography

Legibility is paramount for this user base, spanning patients, elderly individuals, and medical professionals. We utilize *Atkinson Hyperlegible Next* across all hierarchy levels to ensure unambiguous character distinction and maximum readability at any scale.

- **Scale:** Generous base font sizes (16px for body-md, 18px for body-lg) prevent eye strain.
- **Line Heights:** Generous spacing ensures dense medical data remains easily scannable and digestible.

## Layout & Spacing

The layout follows a responsive **Fluid Grid** system optimized for both dense desktop portals and touch-friendly mobile devices.

- **Rhythm:** Built on an 8px baseline grid with generous spacing tokens to ensure comfortable touch targets and breathing room around critical health metrics.
- **Breakpoints:** Mobile (up to 640px) uses single-column stacking with 16px horizontal margins. Tablet (641px to 1024px) introduces two-column card grids. Desktop (1025px and above) utilizes a structured multi-column dashboard layout with a maximum content width of 1280px.

## Elevation & Depth

Depth is communicated through **Ambient shadows** paired with **Tonal layers**. 

- **Surfaces:** Cards and floating action elements use soft, extra-diffused shadows tinted with subtle teal undertones (`rgba(13, 148, 136, 0.08)`) rather than stark black, reinforcing the calming aesthetic.
- **Hierarchy:** Layering relies on elevated white surfaces resting on the soft neutral background (`#F8FAFC`), establishing clear spatial relationships for interactive elements like modals and dropdowns.

## Shapes

The shape language uses a **Rounded** standard (level 2), featuring 0.5rem base radius for standard UI elements and 1rem (`rounded-lg`) for container cards. 

This approachable geometry avoids harsh 90-degree angles, projecting a gentle, welcoming, and safe environment for patients and clinical staff alike.

## Components

- **Buttons:** High-affordance click targets. Primary buttons utilize the deep teal (`#0D9488`) with white text and a subtle hover lift. Secondary actions use outlined mint or ghost styles. Minimum height of 48px ensures accessibility for all age groups.
- **Cards:** Soft surfaces with generous internal padding, 1rem border-radius, and low-opacity ambient shadows to group patient vitals, appointments, or medical records.
- **Input Fields:** Clear, high-contrast borders with floating or persistent labels in `body-md`. Focus states trigger a bold primary teal outline and light mint background tint to confirm active input.
- **Checkboxes & Radio Buttons:** Oversized hit areas with distinct checkmark indicators, ensuring effortless navigation for users with motor or visual impairments.
- **Chips / Badges:** Pill-shaped indicators used for status tags (e.g., "Confirmed", "Pending Review") utilizing soft pastel teal/mint backgrounds with dark matching text.
- **Lists:** Generously spaced list items with clear dividing lines or separated card rows, optimized for readability when scanning medication schedules or lab results.