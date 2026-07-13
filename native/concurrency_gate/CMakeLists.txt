cmake_minimum_required(VERSION 3.20)
project(concurrency_gate LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Threads REQUIRED)

add_subdirectory(godot-cpp)

add_library(concurrency_gate SHARED
	src/entry.cpp
	src/register_types.cpp
	src/concurrency_gate.cpp
	src/kill_arbiter.cpp
	src/shop.cpp
	src/spirit_house.cpp
)

target_include_directories(concurrency_gate PRIVATE src)
target_link_libraries(concurrency_gate PRIVATE godot-cpp Threads::Threads)

# output in res://bin
set_target_properties(concurrency_gate PROPERTIES
	LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../../bin"
)
