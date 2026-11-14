# Listening Tree: branding and version settings for the Audacity build.
#
# The Audacity source's SetupConfigure.cmake includes this file (see
# patches/audacity/0001-*). It runs once at configure time and:
#   * reads config/app.env and VERSION from this repository,
#   * renames the app (name, bundle ID, settings namespace),
#   * writes lt_config.h, a small generated header with the values that C++
#     code needs (app version, GitHub repository, Keychain names).
#
# Audacity's own version (MUSE_APP_VERSION, e.g. 4.0.2) is left alone on purpose.
# The Audacity code uses it for project-file and plugin compatibility checks.
# Listening Tree's own version (VERSION file) is used for the app bundle, the
# About box and the updater.

if (NOT LT_ROOT)
    message(FATAL_ERROR "LT_ROOT is not set. Build Listening Tree with scripts/build.sh.")
endif()
get_filename_component(LT_ROOT "${LT_ROOT}" ABSOLUTE)

# --- Read config/app.env (KEY="value" lines) --------------------------------
file(STRINGS "${LT_ROOT}/config/app.env" _lt_env_lines REGEX "^[A-Z0-9_]+=")
foreach(_lt_line IN LISTS _lt_env_lines)
    # (two separate tests: CMake's if() does not short-circuit, so a combined
    # OR would let the second MATCHES overwrite CMAKE_MATCH_n)
    if (_lt_line MATCHES "^([A-Z0-9_]+)=\"([^\"]*)\"[ \t]*$")
        set(LT_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
    elseif (_lt_line MATCHES "^([A-Z0-9_]+)=([^ \t#\"]*)")
        set(LT_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
    endif()
endforeach()

foreach(_lt_required APP_NAME APP_BUNDLE_ID APP_SETTINGS_NAME APP_ORG_NAME APP_ORG_DOMAIN GITHUB_REPO
                     UPDATE_TOKEN_KEYCHAIN_SERVICE UPDATE_TOKEN_KEYCHAIN_ACCOUNT APP_ARTIFACT_PREFIX)
    if (NOT DEFINED LT_${_lt_required} OR "${LT_${_lt_required}}" STREQUAL "")
        message(FATAL_ERROR "config/app.env: ${_lt_required} is missing or empty")
    endif()
endforeach()

# --- Read VERSION -------------------------------------------------------------
file(STRINGS "${LT_ROOT}/VERSION" LT_APP_VERSION LIMIT_COUNT 1)
string(STRIP "${LT_APP_VERSION}" LT_APP_VERSION)
if (NOT LT_APP_VERSION MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z]+(\\.[0-9]+)?)?$")
    message(FATAL_ERROR "VERSION must look like 1.2.3 or 1.2.3-beta.1 (got '${LT_APP_VERSION}')")
endif()
string(REGEX MATCH "^[0-9]+\\.[0-9]+\\.[0-9]+" LT_APP_VERSION_NUMERIC "${LT_APP_VERSION}")

# Re-run CMake automatically when these files change.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${LT_ROOT}/config/app.env"
    "${LT_ROOT}/VERSION"
    "${LT_ROOT}/cmake/lt_config.h.in"
)

# --- Rename the app -------------------------------------------------------------
set(LT_AUDACITY_VERSION "${MUSE_APP_VERSION}")

set(MUSE_APP_NAME_HUMAN_READABLE        "${LT_APP_NAME}")
set(MUSE_APP_NAME_MACHINE_READABLE      "${LT_APP_SETTINGS_NAME}")
set(MUSE_APP_NAME_HUMAN_READABLE_COMPAT "${LT_APP_NAME}")
set(MUSE_APP_NAME_MACHINE_READABLE_COMPAT "${LT_APP_SETTINGS_NAME}")
set(MUSE_APP_TITLE                      "${LT_APP_NAME}")
set(MUSE_APP_NAME                       "${LT_APP_SETTINGS_NAME}")
set(MUSE_APP_GUI_IDENTIFIER             "${LT_APP_BUNDLE_ID}")

# --- Generated header for C++ -------------------------------------------------------
set(LT_GENERATED_DIR "${CMAKE_BINARY_DIR}/lt_generated")
configure_file("${LT_ROOT}/cmake/lt_config.h.in" "${LT_GENERATED_DIR}/lt_config.h" @ONLY)
include_directories("${LT_GENERATED_DIR}")

message(STATUS "Listening Tree ${LT_APP_VERSION} (based on Audacity ${LT_AUDACITY_VERSION}), "
               "bundle ID ${LT_APP_BUNDLE_ID}, updates from github.com/${LT_GITHUB_REPO}")
