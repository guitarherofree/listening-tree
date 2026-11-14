# Describes this feature to features/CMakeLists.txt.
# Copy the _template folder, rename things, then add the folder name to features/enabled.txt.

# CMake target built by this folder's CMakeLists.txt (prefix with lt_)
set(FEATURE_TARGET lt_template)

# Header (relative to this folder) that declares the module class
set(FEATURE_HEADER templatemodule.h)

# Fully qualified class name of the module; the app creates one at startup
set(FEATURE_MODULE_CLASS lt::templatefeature::TemplateModule)
