package main

import (
	"log"
	"os"
	"runtime"
	"runtime/pprof"
)

func main() {
	// CPU profiling
	cpuFile, err := os.Create("cpu.prof")
	if err != nil {
		log.Fatal(err)
	}
	defer cpuFile.Close()

	if err := pprof.StartCPUProfile(cpuFile); err != nil {
		log.Fatal(err)
	}
	defer pprof.StopCPUProfile()

	log.Println("Starting CPU profiling workload...")
	runComputeWorkloads()
	log.Println("CPU profiling complete")

	// Memory profiling
	log.Println("Starting memory profiling workload...")
	runAllocateWorkloads()
	log.Println("Memory profiling complete")

	runtime.GC()

	memFile, err := os.Create("mem.prof")
	if err != nil {
		log.Fatal(err)
	}
	defer memFile.Close()

	if err := pprof.WriteHeapProfile(memFile); err != nil {
		log.Fatal(err)
	}

	log.Println("Profiles written: cpu.prof, mem.prof")
}
