include(GoogleTest)
include(XrplAddTest)

# Test requirements.
find_package(GTest REQUIRED)

# Custom target for all tests defined in this file
add_custom_target(xrpl.tests)

# Test helpers
add_library(xrpl.helpers.test STATIC)
target_sources(
    xrpl.helpers.test
    PRIVATE helpers/Account.cpp helpers/TestSink.cpp helpers/TxTest.cpp
)
target_include_directories(xrpl.helpers.test PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(xrpl.helpers.test PUBLIC xrpl.libxrpl gtest::gtest)

# Common library dependencies for the rest of the tests.
add_library(xrpl.imports.test INTERFACE)
target_link_libraries(
    xrpl.imports.test
    INTERFACE gtest::gtest xrpl.libxrpl xrpl.helpers.test
)

# Single combined gtest binary; each xrpl_add_test() call appends to it.
add_executable(xrpl_tests main.cpp)
set_target_properties(
    xrpl_tests
    PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)
target_link_libraries(xrpl_tests PRIVATE GTest::gtest)
gtest_discover_tests(xrpl_tests)

xrpl_add_test(basics LIBRARIES xrpl.imports.test)
xrpl_add_test(crypto LIBRARIES xrpl.imports.test)
xrpl_add_test(json LIBRARIES xrpl.imports.test)
xrpl_add_test(tx LIBRARIES xrpl.imports.test)
xrpl_add_test(protocol_autogen LIBRARIES xrpl.imports.test)

# Network unit tests are currently not supported on Windows
if(NOT WIN32)
    xrpl_add_test(net LIBRARIES xrpl.imports.test)
endif()

add_dependencies(xrpl.tests xrpl_tests)
