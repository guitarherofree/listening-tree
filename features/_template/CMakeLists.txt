# Builds the feature as a module, the same way Audacity's own modules are built
# (see src/usageinfo/CMakeLists.txt in work/audacity for another small example).

declare_module(lt_template)

set(MODULE_SRC
    ${CMAKE_CURRENT_LIST_DIR}/templatemodule.cpp
    ${CMAKE_CURRENT_LIST_DIR}/templatemodule.h
)

# Libraries this feature uses, e.g. muse::actions, Qt::Network, or Audacity
# modules such as record or playback (see their CMakeLists.txt for target names).
set(MODULE_LINK
    muse::global
)

setup_module()
