cmake_minimum_required(VERSION 3.20)
project(GekitotsuTurfPitch LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Directorios de inclusión
include_directories(
    src
    src/core
    src/designar
    src/story
    src/physics
)

# Búsqueda de fuentes
file(GLOB_RECURSE SOURCES
    src/*.cpp
    src/*.hpp
    src/*.h
)

# Definición de la biblioteca compartida para GDExtension
add_library(gekitotsu SHARED ${SOURCES})

# Configuración específica según plataforma
if(WIN32)
    set_target_properties(gekitotsu PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "gekitotsu.windows.${CMAKE_BUILD_TYPE}.x86_64"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    )
elseif(APPLE)
    set_target_properties(gekitotsu PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "gekitotsu.macos.${CMAKE_BUILD_TYPE}.universal"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    )
elseif(UNIX)
    set_target_properties(gekitotsu PROPERTIES
        PREFIX "lib"
        OUTPUT_NAME "gekitotsu.linux.${CMAKE_BUILD_TYPE}.x86_64"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    )
endif()
