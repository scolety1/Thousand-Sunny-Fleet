# Responsive UI root cause

At a 375-pixel browser viewport, the document had expanded to 792 pixels. The overflow was structural: `html` imposed a 320-pixel minimum while page padding and grid/flex content added width; several grid/flex children retained automatic minimum content sizes; long mission, result, receipt, hash, branch, and path values could not break; some grid tracks used bare `1fr`; and narrow action/header groups could not reflow.

The correction removes the fixed page minimum, applies `min-width: 0` at the actual shrink boundaries, replaces responsive tracks with `minmax(0, 1fr)`, permits identifiers to wrap with `overflow-wrap: anywhere`, bounds genuine preformatted evidence to its own readable overflow container, and wraps or stacks narrow action/header groups. It does not set `overflow-x: hidden` on `html`, `body`, or the application shell, and it does not hide content or authority information.
