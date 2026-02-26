include_guard()

find_package(Git REQUIRED)

set(GIT_COMMAND branch --show-current)
execute_process(COMMAND ${GIT_EXECUTABLE} ${GIT_COMMAND} WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                OUTPUT_VARIABLE GIT_BUILD_BRANCH OUTPUT_STRIP_TRAILING_WHITESPACE
                                                 COMMAND_ERROR_IS_FATAL ANY)

set(GIT_COMMAND rev-parse HEAD)
execute_process(COMMAND ${GIT_EXECUTABLE} ${GIT_COMMAND} WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                OUTPUT_VARIABLE GIT_COMMIT_HASH OUTPUT_STRIP_TRAILING_WHITESPACE
                                                COMMAND_ERROR_IS_FATAL ANY)

message(STATUS "Git branch: ${GIT_BUILD_BRANCH}")
message(STATUS "Git commit hash: ${GIT_COMMIT_HASH}")
