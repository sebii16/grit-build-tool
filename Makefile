all:
	zig build-exe main.zig -femit-bin=grit

release:
	zig build-exe main.zig -femit-bin=grit -O ReleaseFast
