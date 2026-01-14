#include <xrpl/basics/contract.h>

#include <gtest/gtest.h>

#include <stdexcept>
#include <string>

using namespace xrpl;

TEST(contract, contract)
{
    try
    {
        Throw<std::runtime_error>("Throw test");
    }
    catch (std::runtime_error const& e1)
    {
        EXPECT_EQ(std::string(e1.what()), "Throw test");

        try
        {
            Rethrow();
        }
        catch (std::runtime_error const& e2)
        {
            EXPECT_EQ(std::string(e2.what()), "Throw test");
        }
        catch (...)
        {
            FAIL() << "Should not reach here";
        }
    }
    catch (...)
    {
        FAIL() << "Should not reach here";
    }
}
