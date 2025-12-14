# FixHighDPIFrameDesign
Fixes wrong scaling when opening inherited frames in High DPI designer

The sizes and positions of an inherited Frame and its controls are not scaled when opened in High DPI designer.

When an inherited frame is designed in 96 dpi and later opened in a higher dpi designer, the Width and Height of the frame as well as the contained controls are not scaled. Note that the Width and Height of a TLabel are scaled when its AutoSize is set (following the font). The same happens for the Height of a TEdit (for the same reason).

This plugin intercepts the loading of the DFM and injects a property `PixelsPerInch = 96`, which results in a proper the scaling.
