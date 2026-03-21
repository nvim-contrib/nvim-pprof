package main

// directSliceAllocation allocates slices directly (tracked in memory profile).
func directSliceAllocation(n int) {
	for range n {
		// Direct make() calls are tracked in memory profile
		_ = make([]byte, 4096)
	}
}

// recursiveAllocation allocates on the stack through recursion.
// Each recursive call allocates a slice.
func recursiveAllocation(depth int, size int) {
	if depth == 0 {
		return
	}
	// Direct allocation tracked in profile
	_ = make([]int, size)
	recursiveAllocation(depth-1, size)
}

// mapAllocationWorkload allocates map nodes directly.
func mapAllocationWorkload(n int) {
	m := make(map[int][]byte)
	for i := range n {
		// Each assignment allocates a new key in the map and a byte slice
		m[i] = make([]byte, 256)
	}
}

// sliceAppendWorkload grows slices with append calls.
// append() allocates new backing arrays.
func sliceAppendWorkload(n int) {
	s := make([][]byte, 0)
	for range n {
		// append allocates new backing array as slice grows
		s = append(s, make([]byte, 128))
	}
}

// nestedAllocation allocates nested data structures.
func nestedAllocation(n int) {
	type Node struct {
		Data  []byte
		Child *Node
	}
	var head *Node
	for range n {
		// Each iteration allocates a new Node with embedded slice
		head = &Node{
			Data:  make([]byte, 512),
			Child: head,
		}
	}
}

// allocateStrings allocates string data through explicit byte slices.
func allocateStrings(n int, strLen int) {
	for i := range n {
		// Make a byte slice and convert to string (allocates string)
		b := make([]byte, strLen)
		for j := range b {
			b[j] = byte((i + j) % 256)
		}
		_ = string(b)
	}
}

// runAllocateWorkloads is the entry point for memory-intensive workloads, called from main.
// Allocations are retained in a global to prevent garbage collection before profile is taken.
var globalAllocs []interface{} // Keeps allocations alive for heap profile

func runAllocateWorkloads() {
	globalAllocs = make([]interface{}, 0)

	for range 5 {
		// Direct slice allocations with retention
		tempSlices := make([][]byte, 50000)
		for i := range 50000 {
			tempSlices[i] = make([]byte, 4096)
		}
		globalAllocs = append(globalAllocs, tempSlices)

		// Map allocations with retention
		tempMap := make(map[int][]byte)
		for i := range 100000 {
			tempMap[i] = make([]byte, 256)
		}
		globalAllocs = append(globalAllocs, tempMap)

		// Slice append allocations with retention
		tempSliceAppend := make([][]byte, 0)
		for range 50000 {
			tempSliceAppend = append(tempSliceAppend, make([]byte, 128))
		}
		globalAllocs = append(globalAllocs, tempSliceAppend)

		// Large byte slices
		for range 10000 {
			largeBytes := make([]byte, 1024)
			globalAllocs = append(globalAllocs, largeBytes)
		}

		// String allocations from byte slices
		stringData := make([]string, 0, 50000)
		for i := range 50000 {
			b := make([]byte, 256)
			for j := range b {
				b[j] = byte((i + j) % 256)
			}
			stringData = append(stringData, string(b))
		}
		globalAllocs = append(globalAllocs, stringData)
	}
}
