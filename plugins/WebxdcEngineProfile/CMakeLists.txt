set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -Wall")
set(PLUGIN "WebxdcEngineProfile")

set(
    SRC
    plugin.cpp
    webxdcEngineProfile.cpp
    webxdcRequestInterceptor.cpp
    webxdcSchemeHandler.cpp
)

set(CMAKE_AUTOMOC ON)

add_library(deltachat SHARED IMPORTED)
set_property(TARGET deltachat PROPERTY IMPORTED_LOCATION "${CMAKE_CURRENT_BINARY_DIR}/libdeltachat.so")

add_library(${PLUGIN} MODULE ${SRC})
set_target_properties(${PLUGIN} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PLUGIN})

# According to some articles on the net,
# qt5_use_modules is deprecated, so
# it's replaced by corresponding find_package calls
#qt5_use_modules(${PLUGIN} Qml Quick DBus)
find_package(Qt5 COMPONENTS Qml REQUIRED)
find_package(Qt5 COMPONENTS Quick REQUIRED)
find_package(Qt5 COMPONENTS DBus REQUIRED)
find_package(Qt5 COMPONENTS Multimedia REQUIRED)
find_package(Qt5WebEngine REQUIRED)
target_link_libraries(${PLUGIN} Qt5::Qml Qt5::Quick Qt5::DBus Qt5::Multimedia Qt5::WebEngine deltachat)

execute_process(
    COMMAND dpkg-architecture -qDEB_HOST_MULTIARCH
    OUTPUT_VARIABLE ARCH_TRIPLET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(QT_IMPORTS_DIR "/lib/${ARCH_TRIPLET}")

install(TARGETS ${PLUGIN} DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
install(FILES qmldir DESTINATION ${QT_IMPORTS_DIR}/${PLUGIN}/)
