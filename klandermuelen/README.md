# De Klander Muelen: modern redesign

A redesign concept for https://klandermuelen.nl/: one static page with no build step. Open `index.html` in a browser.

## What's interactive
- **Live open/closed badge.** It uses Dordrecht time (Europe/Amsterdam), and the hours table highlights today.
- **Menu filter.** Category tabs have a sliding indicator, there's instant search, and the cards have a cursor spotlight and 3D tilt.
- **Reservation widget.** Pick the number of guests, a day and a time slot (slots follow the opening hours, and times that have passed today are disabled). A note appears for groups of 10 or more. Submitting opens a pre-filled e-mail to info@klandermuelen.nl.
- **Motion.** The headline animates in, the hero has parallax blobs and a spinning windmill, a marquee scrolls, and sections fade in with count-up stats and a drawn timeline.
- **Navigation.** A sticky, auto-hiding navbar with a scroll progress bar and active-section highlighting. The full-screen mobile menu opens with a circular reveal, and a floating "Reserveer" button appears as you scroll.
- **Theme.** Light and dark mode follow the system setting and can be toggled manually (the choice is remembered).
- It respects `prefers-reduced-motion` and is responsive down to 320px.

## To finish before going live
- Replace the gradient placeholders in the gallery (`.g1`–`.g3` in `styles.css`) with real photos.
- Check the menu items and add prices. The dishes shown come from public listings.
- If you want bookings to land in a reservation system instead of e-mail, connect the form to it.
