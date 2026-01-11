all:
	zig build-exe main.zig -femit-bin=grit -O Debug -cflags -fsanitize=address,undefined -- -freference-trace=10

release:
	zig build-exe main.zig -femit-bin=grit -O ReleaseFast -fstrip

clean:
	rm -f grit

