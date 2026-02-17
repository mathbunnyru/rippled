include("${CMAKE_CURRENT_LIST_DIR}/XrplVersion.cmake")

set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/xrpl")
set(CPACK_PACKAGE_VERSION "${xrpld_version}")
set(CPACK_STRIP_FILES TRUE)

include(pkg/deb)
include(CPack)
