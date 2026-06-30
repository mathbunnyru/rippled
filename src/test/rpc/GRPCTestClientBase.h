#pragma once

#include <test/jtx/envconfig.h>

#include <xrpl/beast/net/IPEndpoint.h>
#include <xrpl/proto/org/xrpl/rpc/v1/xrp_ledger.grpc.pb.h>

#include <grpcpp/grpcpp.h>

namespace xrpl::test {

struct GRPCTestClientBase
{
    explicit GRPCTestClientBase(std::string const& port)
        : stub(
              org::xrpl::rpc::v1::XRPLedgerAPIService::NewStub(
                  grpc::CreateChannel(
                      beast::IP::to_string(
                          beast::IP::Endpoint(
                              boost::asio::ip::make_address(getEnvLocalhostAddr()),
                              std::stoi(port))),
                      grpc::InsecureChannelCredentials())))
    {
    }

    grpc::Status status;
    grpc::ClientContext context;
    std::unique_ptr<org::xrpl::rpc::v1::XRPLedgerAPIService::Stub> stub;
};

}  // namespace xrpl::test
