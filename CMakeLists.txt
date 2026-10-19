cmake_minimum_required(VERSION 3.12)
project(SparkChess VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Optimization flags
if(MSVC)
    add_compile_options(/O2 /Oi /Ot /GL /W3 /std:c++20 /permissive-)
    add_link_options(/LTCG)
else()
    add_compile_options(-O3 -Wall -Wextra -pthread)
    add_link_options(-pthread)
endif()

set(SOURCES
    src/bitboard.cpp
    src/board.cpp
    src/book.cpp
    src/evaluate.cpp
    src/main.cpp
    src/movegen.cpp
    src/nnue.cpp
    src/search.cpp
    src/trainer.cpp
    src/tt.cpp
    src/uci.cpp
    src/zobrist.cpp
)

set(HEADERS
    src/types.h
    src/bitboard.h
    src/book.h
    src/magics.h
    src/zobrist.h
    src/board.h
    src/movegen.h
    src/evaluate.h
    src/nnue.h
    src/tt.h
    src/search.h
    src/trainer.h
    src/uci.h
)

add_executable(sparkchess ${SOURCES} ${HEADERS})

target_include_directories(sparkchess PRIVATE src)

set_target_properties(sparkchess PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
