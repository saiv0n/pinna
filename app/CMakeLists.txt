cmake_minimum_required(VERSION 3.21)
project(pinna VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Widgets Quick QuickControls2 QuickEffects DBus Svg)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(pinna src/main.cpp src/backend.cpp src/backend.h src/tray.cpp src/tray.h)
target_compile_definitions(pinna PRIVATE PINNA_VERSION="${PROJECT_VERSION}")

set_source_files_properties(qml/Theme.qml qml/Store.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(pinna
    URI Pinna
    VERSION 1.0
    QML_FILES
        qml/AboutPage.qml
        qml/AccessibilityPage.qml
        qml/AudioPage.qml
        qml/BatteryChart.qml
        qml/BatteryRing.qml
        qml/Block.qml
        qml/Button.qml
        qml/CheckBox.qml
        qml/ComputerPage.qml
        qml/Confirm.qml
        qml/ControlsPage.qml
        qml/Dropdown.qml
        qml/Field.qml
        qml/FocusRing.qml
        qml/GeneralPage.qml
        qml/HeadView.qml
        qml/IconButton.qml
        qml/Main.qml
        qml/Menu.qml
        qml/MenuItemLike.qml
        qml/ModeIcon.qml
        qml/ModePicker.qml
        qml/NoisePage.qml
        qml/Page.qml
        qml/Popup.qml
        qml/Section.qml
        qml/Segmented.qml
        qml/Setting.qml
        qml/Sidebar.qml
        qml/Slider.qml
        qml/Spinner.qml
        qml/Store.qml
        qml/Switch.qml
        qml/Theme.qml
        qml/Toast.qml
    RESOURCES
        fonts/Inter.ttf
        assets/bud.png
        assets/set.png
        assets/case.png
        assets/tray.png
)

# çeviriler; Qt kurulumunda LinguistTools yoksa sistemdeki lrelease kullanılır
find_program(LRELEASE NAMES lrelease lrelease-qt6 PATHS ${QT6_INSTALL_PREFIX}/bin /usr/lib/qt6/bin)
if(LRELEASE)
    set(QM ${CMAKE_CURRENT_BINARY_DIR}/pinna_en.qm)
    add_custom_command(OUTPUT ${QM}
        COMMAND ${LRELEASE} -silent ${CMAKE_CURRENT_SOURCE_DIR}/i18n/pinna_en.ts -qm ${QM}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/i18n/pinna_en.ts)
    set_source_files_properties(${QM} PROPERTIES QT_RESOURCE_ALIAS pinna_en.qm)
    qt_add_resources(pinna i18n PREFIX /i18n FILES ${QM})
endif()

target_include_directories(pinna PRIVATE src)
target_link_libraries(pinna PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Quick Qt6::QuickControls2 Qt6::QuickEffects Qt6::DBus Qt6::Svg)

install(TARGETS pinna RUNTIME DESTINATION bin)
