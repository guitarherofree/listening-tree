/*
 * Listening Tree feature template.
 *
 * A feature is a module: a class that the app creates at startup and calls at
 * fixed points (register services, resolve the ones it needs, init, deinit).
 * Audacity's own parts (record, playback, effects, ...) are modules of the same
 * kind, so their code in work/audacity/src is the best reference.
 */
#pragma once

#include "modularity/imodulesetup.h"

namespace lt::templatefeature {
class TemplateModule : public muse::modularity::IModuleSetup
{
public:
    std::string moduleName() const override;

    void registerExports() override;
    void onInit(const muse::IApplication::RunMode& mode) override;
};
}
