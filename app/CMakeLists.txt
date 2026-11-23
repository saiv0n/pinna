cmake_minimum_required(VERSION 3.21)
project(earshot VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 QuickEffects DBus Svg)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(earshot src/main.cpp src/backend.cpp src/backend.h)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(earshot
    URI Earshot
    VERSION 1.0
    QML_FILES
        qml/Theme.qml
        qml/Main.qml
        qml/Popup.qml
        qml/Hero.qml
        qml/PodArt.qml
        qml/BatteryRing.qml
        qml/ModeSwitch.qml
        qml/ModeIcon.qml
        qml/Group.qml
        qml/SettingRow.qml
        qml/ToggleRow.qml
        qml/ChoiceRow.qml
        qml/SliderRow.qml
        qml/InfoRow.qml
        qml/Toggle.qml
        qml/Segmented.qml
        qml/Slider.qml
        qml/CheckRow.qml
        qml/Disconnected.qml
        qml/Toast.qml
    RESOURCES
        fonts/InstrumentSans.ttf
        assets/bud.png
        assets/set.png
)

target_include_directories(earshot PRIVATE src)
target_link_libraries(earshot PRIVATE Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::QuickEffects Qt6::DBus Qt6::Svg)

install(TARGETS earshot RUNTIME DESTINATION bin)
