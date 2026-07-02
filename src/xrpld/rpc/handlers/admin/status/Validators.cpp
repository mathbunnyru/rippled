#include <xrpld/rpc/Context.h>

#include <xrpl/json/json_value.h>

namespace xrpl {

json::Value
doValidators(RPC::JsonContext& context)
{
    return context.app.getValidators().getJson();
}

}  // namespace xrpl
