include(isolate_headers)

# Our normal build only ever compiles `.cpp` files, so a header is only ever
# checked through whatever translation unit happens to include it. A header that
# is missing an `#include` is never caught as long as every `.cpp` that uses it
# includes its missing dependency first. The only way to guarantee that a header
# is self-contained - that it includes, directly or transitively, every
# declaration it uses - is to compile it on its own.
#
# `verify_module_headers` creates an OBJECT library `${target}.verify` whose
# sources are generated `.cpp` files, one per header in the module, each of
# which does nothing but `#include` that header. The library is never linked
# into anything, so the objects are thrown away; we build it only for the side
# effect of compiling each header in isolation. Because the generated
# translation units also land in `compile_commands.json`, clang-tidy lints each
# header on its own as well.
#
# The verify library needs to compile each header exactly as the module does, so
# it inherits the module's usage requirements (its public include directories,
# the include directories of every module it links, and its compile options) by
# linking the module. Private headers live behind a PRIVATE include directory
# that does not propagate through linking, so we re-isolate them directly on the
# verify library, mirroring `add_module`.
#
# verify_module_headers(target parent name)
function(verify_module_headers target parent name)
    set(verify ${target}.verify)
    add_library(${verify} OBJECT EXCLUDE_FROM_ALL)
    # A unity build would concatenate the per-header wrappers into a single
    # translation unit, so a header missing an include could be satisfied by a
    # header that precedes it in the blob - exactly the bug we want to catch.
    set_target_properties(${verify} PROPERTIES UNITY_BUILD OFF)
    # Inherit ${target}'s public include directories, the include directories of
    # every module it links, and its compile options. The link scope is PRIVATE
    # because nothing links ${verify} in turn; linking an object library does not
    # pull in its objects, only its usage requirements.
    target_link_libraries(${verify} PRIVATE ${target})
    # Make the module's private headers reachable under their canonical include
    # path, exactly as `add_module` does for the module itself.
    isolate_headers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/lib${parent}/${name}"
        PRIVATE
    )
    _verify_generate_wrappers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/include/${parent}/${name}"
    )
    _verify_generate_wrappers(
        ${verify}
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/lib${parent}/${name}"
    )
    add_dependencies(verify-headers ${verify})
endfunction()

# Verify the headers of a target that is not built with add_module - in
# particular the xrpld executable and the test binaries, whose headers live
# under a single include root rather than in isolated per-module directories.
#
# Unlike verify_module_headers, this reuses ${target}'s own compile environment:
# its include directories, compile options and definitions, and the libraries it
# links. An executable cannot be linked, so we copy its resolved usage
# requirements through generator expressions and link the same libraries it
# links (for their transitive include directories and definitions). The verify
# library is created once; call this repeatedly to add more header directories
# (e.g. src/xrpld and src/test both belong to xrpld).
#
# headers_root is the include root the headers are reached through, so the
# include path is each header's path relative to headers_root.
#
# verify_target_headers(target headers_root headers_dir)
function(verify_target_headers target headers_root headers_dir)
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
    _verify_generate_wrappers(${verify} "${headers_root}" "${headers_dir}")
endfunction()

# Generate one `#include`-only translation unit for every header found under B,
# using the same relative include path C (from A to the header) that the rest of
# the code base uses to include it. See `isolate_headers` for the A/B/C model.
function(_verify_generate_wrappers target A B)
    # .ipp files are inline-implementation fragments included by their owning
    # header (often after a class declaration), so they are not self-contained on
    # their own and are verified transitively when that header is verified.
    file(GLOB_RECURSE headers CONFIGURE_DEPENDS "${B}/*.h" "${B}/*.hpp")
    set(wrappers "")
    foreach(header ${headers})
        # C is the canonical path used to `#include` the header (relative to the
        # include root A); see isolate_headers.
        file(RELATIVE_PATH C "${A}" "${header}")
        # Name the wrapper after the header's path relative to the source tree
        # (e.g. include/xrpl/basics/Foo.h.cpp), not after C. clang-tidy is
        # selected by `run-clang-tidy` with a regex matched against the path of
        # each translation unit, and the changed-files list it is given on a
        # partial run contains repo-relative header paths. Mirroring that path
        # here lets a changed header match its own wrapper.
        file(RELATIVE_PATH relative "${CMAKE_CURRENT_SOURCE_DIR}" "${header}")
        set(wrapper
            "${CMAKE_CURRENT_BINARY_DIR}/verify-headers/${relative}.cpp"
        )
        # The wrapper references no symbols from the header, so include-cleaner
        # would flag the include as unused. Suppress only that diagnostic; the
        # point of the wrapper - that the header compiles on its own - is checked
        # by the compiler regardless.
        set(content "#include <${C}> // NOLINT(misc-include-cleaner)\n")
        # Only (re)write the wrapper when its content changes, so configuring
        # does not needlessly invalidate the compiled objects.
        set(existing "")
        if(EXISTS "${wrapper}")
            file(READ "${wrapper}" existing)
        endif()
        if(NOT existing STREQUAL content)
            file(WRITE "${wrapper}" "${content}")
        endif()
        list(APPEND wrappers "${wrapper}")
    endforeach()
    target_sources(${target} PRIVATE ${wrappers})
endfunction()
