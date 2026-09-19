# Editable hand-panel background

Open `HandPanels.svg` in Illustrator, Inkscape, Affinity Designer, or another
SVG-capable graphic editor. It is a vector editing copy of the existing panel
artwork, normalized to the application's **1500 × 612 pixel** coordinate system.
`HandPanels-preview.png` is a rendered preview of this copy, not the live app asset.

The SVG contains named layers for the white page, housings, trackballs, knobs,
buttons/selectors, indicator lights, and labels. Illustrator converted the labels
to vector outlines on export. They now have a bold charcoal treatment for better
contrast. The right trackball is a solid black vector ellipse; no embedded or
external images are required.

## Editing and exporting

- Keep the artboard at 1500 × 612 and export the **page/artboard**, not a tight
  crop around the drawing.
- Edit colors, text, outlines, and shading freely. Keep control centers and face
  sizes in place unless you also want us to update the application's hit areas.
- The final layer, **Control position guides - HIDE BEFORE EXPORT**, is hidden
  by default. Show it while editing to see the 27 control areas used by the app.
  Hide it again before exporting. Some editors show layers as named groups.
- Do not bake the new knob minus/plus marks, hover rings, selected rings, or
  unavailable-control slashes into the background. The Delphi application draws
  these separately. The original static Fine/Coarse and trackball symbols are
  part of the artwork and are retained.
- Save your edits as SVG and export a PNG at exactly **1500 × 612 pixels**.

This SVG is now the source for `../../VirtualHandPanel/HandPanelsBackground.png`.
The current PNG and `HandPanelAssets.res` include the black right trackball and
bold charcoal labels. Rebuild the Win32 application to use them.

For subsequent edits, export this SVG to that PNG at 1500 × 612, with the guides
hidden, then regenerate `HandPanelAssets.res` using
`../../VirtualHandPanel/build_hand_panel_resource.py` before rebuilding.
