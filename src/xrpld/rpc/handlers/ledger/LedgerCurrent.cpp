#include <xrpld/rpc/Context.h>

#include <xrpl/json/json_value.h>
#include <xrpl/protocol/jss.h>

namespace xrpl {

json::Value
doLedgerCurrent(RPC::JsonContext& context)
{
    json::Value jvResult;
    jvResult[jss::ledger_current_index] = context.ledgerMaster.getCurrentLedgerIndex();
    return jvResult;
}

}  // namespace xrpl
