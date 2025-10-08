cmake_minimum_required(VERSION 3.18)
project(TankBattleC)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/build)
set(GLAD_SRC_DIR ${CMAKE_SOURCE_DIR}/build/gladsources/glad)


include(FetchContent)

# Enable GLM experimental features
add_definitions(-DGLM_ENABLE_EXPERIMENTAL)

# Dependencies: GLFW, GLAD, GLM (header-only)

# GLFW
FetchContent_Declare(
  glfw
  GIT_REPOSITORY https://github.com/glfw/glfw.git
  GIT_TAG 3.4
)
FetchContent_MakeAvailable(glfw)

FetchContent_Declare(
    glad
    GIT_REPOSITORY https://github.com/Dav1dde/glad.git
    GIT_TAG        v2.0.8
    GIT_PROGRESS   TRUE
    SOURCE_SUBDIR  cmake # This is crucial as GLAD's CMakeLists.txt is in a subdirectory
)
FetchContent_MakeAvailable(glad)

FetchContent_Declare(
	glm
	GIT_REPOSITORY	https://github.com/g-truc/glm.git
	GIT_TAG 1.0.1
)
FetchContent_MakeAvailable(glm)

# STB (header-only, for PNG loading)
FetchContent_Declare(
stb
GIT_REPOSITORY https://github.com/nothings/stb.git
GIT_TAG master
)
FetchContent_MakeAvailable(stb)

glad_add_library(glad STATIC REPRODUCIBLE LOADER API gl:core=3.3)
find_package(OpenGL REQUIRED)

# Add executable
add_executable(${PROJECT_NAME} 
  ${CMAKE_SOURCE_DIR}/src/main.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/shaders.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/collision.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/input.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/engine.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/tilemap.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/entity.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/tank.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/camera2D.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/texture2D.cpp
  ${CMAKE_SOURCE_DIR}/src/engine/renderer2D.cpp
)

# Include directories
target_include_directories(${PROJECT_NAME} PRIVATE 
  ${GLAD_SRC_DIR}/include 
  ${CMAKE_SOURCE_DIR}/src
  ${stb_SOURCE_DIR}
  )

# Link libraries
target_link_libraries(${PROJECT_NAME}
    PRIVATE
    glad
    glfw
    glm::glm
)

if (WIN32)
  target_compile_definitions(${PROJECT_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# For MacOS, we need to specify this to avoid linker errors
if(APPLE)
  target_compile_definitions(${PROJECT_NAME} PRIVATE GL_SILENCE_DEPRECATION)
  target_link_libraries(${PROJECT_NAME} PRIVATE "-framework Cocoa" "-framework IOKit" "-framework CoreVideo")
endif()

# Copy shader files to build directory
file(COPY ${CMAKE_SOURCE_DIR}/shaders/ DESTINATION ${CMAKE_BINARY_DIR}/shaders/ FILES_MATCHING PATTERN "*.glsl")
