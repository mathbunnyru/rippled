include(isolate_headers)

# Our normal build only ever compiles `.cpp` files, so a header is only ever
# checked through whatever translation unit happens to include it. A header that
# is missing an `#include` is never caught as long as every `.cpp` that uses it
# includes its missing dependency first. To check a header on its own we compile
# it directly as a translation unit.
#
# Compiling the header itself - rather than a `.cpp` wrapper that includes it -
# gives two checks at once:
#   * the compiler fails if the header is not self-contained, i.e. it uses a
#     declaration that is not available (directly or transitively); and
#   * the header is the *main file* of its `compile_commands.json` entry, so
#     clang-tidy's misc-include-cleaner analyses (and can --fix) the header's own
#     includes - flagging a dependency that is only available transitively, which
#     a plain compile cannot catch. A wrapper would be the main file instead, and
#     include-cleaner never looks inside the headers a main file includes.
#
# The objects are never linked anywhere; we build them only for these checks.

# Verify the headers of an add_module library. The verify library compiles each
# header exactly as the module does, inheriting the module's usage requirements
# (its public include directories, the include directories of every module it
# links, and its compile options) by linking the module. Private headers live
# behind a PRIVATE include directory that does not propagate through linking, so
# we re-isolate them on the verify library, mirroring `add_module`.
#
# verify_module_headers(target parent name)
function(verify_module_headers target parent name)
    set(verify ${target}.verify)
    add_library(${verify} OBJECT EXCLUDE_FROM_ALL)
    # A unity build would concatenate the headers into a single translation unit,
    # where a header missing an include could be satisfied by one that precedes it
    # in the blob - exactly the bug we want to catch.
    set_target_properties(${verify} PROPERTIES UNITY_BUILD OFF)
    # The link scope is PRIVATE because nothing links ${verify} in turn; linking
    # an object library propagates its usage requirements, not its objects.
    target_link_libraries(${verify} PRIVATE ${target})
    isolate_headers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/lib${parent}/${name}"
        PRIVATE
    )
    _verify_add_headers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/include/${parent}/${name}"
    )
    _verify_add_headers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/src/lib${parent}/${name}"
    )
    add_dependencies(verify-headers ${verify})
endfunction()

# Verify the headers of a target that is not built with add_module - the xrpld
# executable and the test binaries, whose headers share a single include root
# rather than living in isolated per-module directories.
#
# This reuses ${target}'s own compile environment: its include directories,
# compile options and definitions, and the libraries it links. An executable
# cannot be linked, so we copy its resolved usage requirements through generator
# expressions and link the same libraries it links (for their transitive include
# directories and definitions). The verify library is created once; call this
# repeatedly to add more header directories (e.g. src/xrpld and src/test both
# belong to xrpld).
#
# verify_target_headers(target headers_dir)
function(verify_target_headers target headers_dir)
    set(verify ${target}.verify)
    if(NOT TARGET ${verify})
        add_library(${verify} OBJECT EXCLUDE_FROM_ALL)
        set_target_properties(${verify} PROPERTIES UNITY_BUILD OFF)
        target_include_directories(
            ${verify}
            PRIVATE $<TARGET_PROPERTY:${target},INCLUDE_DIRECTORIES>
        )
        target_compile_definitions(
            ${verify}
            PRIVATE $<TARGET_PROPERTY:${target},COMPILE_DEFINITIONS>
        )
        target_compile_options(
            ${verify}
            PRIVATE $<TARGET_PROPERTY:${target},COMPILE_OPTIONS>
        )
        target_link_libraries(
            ${verify}
            PRIVATE $<TARGET_PROPERTY:${target},LINK_LIBRARIES>
        )
        add_dependencies(verify-headers ${verify})
    endif()
    _verify_add_headers(${verify} "${headers_dir}")
endfunction()

# Add every .h/.hpp under dir to target as a directly-compiled C++ translation
# unit. .ipp files are inline-implementation fragments included by their owning
# header (often after a class declaration), so they are not self-contained on
# their own and are verified transitively when that header is verified.
function(_verify_add_headers target dir)
    file(GLOB_RECURSE headers CONFIGURE_DEPENDS "${dir}/*.h" "${dir}/*.hpp")
    if(NOT headers)
        return()
    endif()
    # `-xc++` forces the header to be compiled as a C++ translation unit; a lone
    # `.h` is otherwise treated as a header to precompile. `#pragma once` is
    # harmless (and warns) when the header is the main file, so silence it.
    set_source_files_properties(
        ${headers}
        PROPERTIES
            LANGUAGE CXX
            COMPILE_OPTIONS "-xc++;-Wno-pragma-once-outside-header"
    )
    target_sources(${target} PRIVATE ${headers})
endfunction()
