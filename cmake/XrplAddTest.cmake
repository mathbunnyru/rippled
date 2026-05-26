include(isolate_headers)

# xrpl_add_test(name [LIBRARIES <libs>...])
#
# Appends sources under ${CMAKE_CURRENT_SOURCE_DIR}/<name>/*.cpp and
# <name>.cpp (if present) to the `xrpl_tests` executable, which must
# already be defined by the caller.
function(xrpl_add_test name)
    cmake_parse_arguments(arg "" "" "LIBRARIES" ${ARGN})

    set(target xrpl_tests)

    file(
        GLOB_RECURSE sources
        CONFIGURE_DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/${name}/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/${name}.cpp"
    )
    target_sources(${target} PRIVATE ${sources})

    isolate_headers(
        ${target}
        "${CMAKE_SOURCE_DIR}"
        "${CMAKE_SOURCE_DIR}/tests/${name}"
        PRIVATE
    )

    if(arg_LIBRARIES)
        target_link_libraries(${target} PRIVATE ${arg_LIBRARIES})
    endif()
endfunction()
