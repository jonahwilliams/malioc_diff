A tool for processing the output of malioc (mali offline compiler)

### Example

1. Collect report on current set of shaders:

`malioc_diff -i out/android_debug/gen/flutter/impeller/entity/gles -o archive`

2. Make changes to shaders and recompile.
3. Analyze changes to shader performance:

`malioc_diff -i out/android_debug/gen/flutter/impeller/entity/gles -d archive`
