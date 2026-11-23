cmake_minimum_required(VERSION 3.21)
project(pinna VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 QuickEffects DBus Svg)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(pinna src/main.cpp src/backend.cpp src/backend.h)

set_source_files_properties(qml/Theme.qml qml/Store.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(pinna
    URI Pinna
    VERSION 1.0
    QML_FILES
        qml/Theme.qml
        qml/Store.qml
        qml/Main.qml
        qml/MainPage.qml
        qml/NavPage.qml
        qml/HoldPage.qml
        qml/AccessibilityPage.qml
        qml/ComputerPage.qml
        qml/NamePage.qml
        qml/Popup.qml
        qml/Hero.qml
        qml/PodArt.qml
        qml/BatteryRing.qml
        qml/ModeSwitch.qml
        qml/ModeIcon.qml
        qml/Group.qml
        qml/Choice.qml
        qml/SettingRow.qml
        qml/ToggleRow.qml
        qml/CheckRow.qml
        qml/SliderRow.qml
        qml/InfoRow.qml
        qml/Toggle.qml
        qml/Slider.qml
        qml/Speaker.qml
        qml/Spinner.qml
        qml/PillButton.qml
        qml/Disconnected.qml
        qml/Banner.qml
    RESOURCES
        fonts/Inter.ttf
        assets/bud.png
        assets/set.png
        assets/case.png
)

target_include_directories(pinna PRIVATE src)
target_link_libraries(pinna PRIVATE Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::QuickEffects Qt6::DBus Qt6::Svg)

install(TARGETS pinna RUNTIME DESTINATION bin)
