// Listening Tree: registers the feature modules listed in features/enabled.txt.
// Called from the app factory (src/app/appfactory.cpp, see patches/audacity/0003-*).
#pragma once

#include <functional>

namespace muse::modularity {
class IModuleSetup;
}

namespace lt {
void addFeatureModules(const std::function<void(muse::modularity::IModuleSetup*)>& addModule);
}
