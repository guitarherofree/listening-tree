#include "templatemodule.h"

#include "log.h"

using namespace lt::templatefeature;

std::string TemplateModule::moduleName() const
{
    return "lt_template";
}

void TemplateModule::registerExports()
{
    // Register this feature's services here so other code can use them, e.g.
    //   globalIoc()->registerExport<IMyService>(moduleName(), new MyService());
}

void TemplateModule::onInit(const muse::IApplication::RunMode& mode)
{
    if (mode != muse::IApplication::RunMode::GuiApp) {
        return;
    }
    LOGI() << "Listening Tree template feature loaded";
}
