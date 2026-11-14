# Listening Tree feature modules.
#
# The Audacity build includes this file (see patches/audacity/0003-*). It adds
# every feature listed in enabled.txt and generates lt_features.cpp, which
# registers their modules with the app at startup. With no features enabled it
# builds an empty lt_features library, so the hook is always exercised.
#
# A feature is a folder here containing:
#   feature.cmake    sets FEATURE_TARGET, FEATURE_HEADER and FEATURE_MODULE_CLASS
#   CMakeLists.txt   builds FEATURE_TARGET (declare_module(...) / setup_module())
#   the module's sources
# See _template/ and docs/DEVELOPING.md.

set(LT_FEATURES_DIR "${CMAKE_CURRENT_LIST_DIR}")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${LT_FEATURES_DIR}/enabled.txt")

file(STRINGS "${LT_FEATURES_DIR}/enabled.txt" _lt_feature_lines)

set(_lt_feature_targets)
set(LT_FEATURE_INCLUDES "")
set(LT_FEATURE_REGISTRATIONS "")

foreach(_lt_line IN LISTS _lt_feature_lines)
    string(REGEX REPLACE "#.*$" "" _lt_name "${_lt_line}")
    string(STRIP "${_lt_name}" _lt_name)
    if (_lt_name STREQUAL "")
        continue()
    endif()

    set(_lt_dir "${LT_FEATURES_DIR}/${_lt_name}")
    if (NOT EXISTS "${_lt_dir}/feature.cmake")
        message(FATAL_ERROR "features/enabled.txt lists '${_lt_name}', but features/${_lt_name}/feature.cmake does not exist")
    endif()

    unset(FEATURE_TARGET)
    unset(FEATURE_HEADER)
    unset(FEATURE_MODULE_CLASS)
    include("${_lt_dir}/feature.cmake")
    foreach(_lt_var FEATURE_TARGET FEATURE_HEADER FEATURE_MODULE_CLASS)
        if (NOT ${_lt_var})
            message(FATAL_ERROR "features/${_lt_name}/feature.cmake must set ${_lt_var}")
        endif()
    endforeach()

    add_subdirectory("${_lt_dir}" "${CMAKE_CURRENT_BINARY_DIR}/${_lt_name}")

    list(APPEND _lt_feature_targets ${FEATURE_TARGET})
    string(APPEND LT_FEATURE_INCLUDES "#include \"${_lt_dir}/${FEATURE_HEADER}\"\n")
    string(APPEND LT_FEATURE_REGISTRATIONS "    addModule(new ${FEATURE_MODULE_CLASS}());\n")
    message(STATUS "Listening Tree feature: ${_lt_name}")
endforeach()

configure_file("${LT_FEATURES_DIR}/lt_features.cpp.in" "${CMAKE_CURRENT_BINARY_DIR}/lt_features.cpp" @ONLY)

# Built like any other module (same include paths and Qt setup as Audacity's modules).
muse_create_module(lt_features NO_PCH NO_UNITY)
target_sources(lt_features PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/lt_features.cpp"
    "${LT_FEATURES_DIR}/lt_features.h"
)
target_include_directories(lt_features PUBLIC "${LT_FEATURES_DIR}")
target_link_libraries(lt_features PRIVATE ${_lt_feature_targets})
