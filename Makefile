CXX ?= g++
CXXFLAGS = -O3 -std=c++17 -Wall -Wextra -pthread
LDFLAGS = -pthread

SRCDIR = src
OBJDIR = obj
BINDIR = bin

SOURCES = src/bitboard.cpp src/board.cpp src/book.cpp src/evaluate.cpp src/main.cpp src/movegen.cpp src/nnue.cpp src/search.cpp src/trainer.cpp src/tt.cpp src/uci.cpp src/zobrist.cpp
OBJECTS = obj/bitboard.o obj/board.o obj/book.o obj/evaluate.o obj/main.o obj/movegen.o obj/nnue.o obj/search.o obj/trainer.o obj/tt.o obj/uci.o obj/zobrist.o
TARGET = $(BINDIR)/sparkchess

all: $(TARGET)

$(TARGET): $(OBJECTS) | $(BINDIR)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)

obj/bitboard.o: src/bitboard.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/bitboard.cpp -o $@

obj/board.o: src/board.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/board.cpp -o $@

obj/book.o: src/book.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/book.cpp -o $@

obj/evaluate.o: src/evaluate.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/evaluate.cpp -o $@

obj/main.o: src/main.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/main.cpp -o $@

obj/movegen.o: src/movegen.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/movegen.cpp -o $@

obj/nnue.o: src/nnue.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/nnue.cpp -o $@

obj/search.o: src/search.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/search.cpp -o $@

obj/trainer.o: src/trainer.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/trainer.cpp -o $@

obj/tt.o: src/tt.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/tt.cpp -o $@

obj/uci.o: src/uci.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/uci.cpp -o $@

obj/zobrist.o: src/zobrist.cpp | $(OBJDIR)
	$(CXX) $(CXXFLAGS) -c src/zobrist.cpp -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(BINDIR):
	mkdir -p $(BINDIR)

clean:
	rm -rf $(OBJDIR) $(BINDIR)

.PHONY: all clean
