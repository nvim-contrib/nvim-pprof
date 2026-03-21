.PHONY: profile clean help

profile:
	@echo "Building demo binary..."
	go build -o demo-pprof main.go compute.go allocate.go
	@echo "Running profiling workload (this may take 30-60 seconds)..."
	./demo-pprof
	@echo "Cleaning up binary..."
	rm -f demo-pprof
	@echo "Done! Generated cpu.prof and mem.prof"

clean:
	rm -f cpu.prof mem.prof demo-pprof

help:
	@echo "nvim-pprof demo Makefile targets:"
	@echo "  make profile  - Build binary, run profiling, generate cpu.prof and mem.prof"
	@echo "  make clean    - Remove generated profile and binary files"
	@echo "  make help     - Show this help message"
