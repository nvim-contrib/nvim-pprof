package main

import (
	"math"
	"sort"
)

// matrixMultiply performs matrix multiplication with varied per-line heat.
// The inner accumulation line is the hottest.
func matrixMultiply(a, b [][]float64, n int) [][]float64 {
	c := make([][]float64, n)
	for i := range n {
		c[i] = make([]float64, n)
		for k := range n {
			for j := range n {
				c[i][j] += a[i][k] * b[k][j]
			}
		}
	}
	return c
}

// newMatrix fills a matrix with sin/cos values.
func newMatrix(n int, seed float64) [][]float64 {
	m := make([][]float64, n)
	for i := range n {
		m[i] = make([]float64, n)
		for j := range n {
			m[i][j] = math.Sin(seed + float64(i)*0.1 + float64(j)*0.05)
		}
	}
	return m
}

// sieveOfEratosthenes computes primes with an inner marking loop that's hottest.
func sieveOfEratosthenes(limit int) []bool {
	primes := make([]bool, limit+1)
	for i := 2; i <= limit; i++ {
		primes[i] = true
	}
	for i := 2; i*i <= limit; i++ {
		if primes[i] {
			for j := i * i; j <= limit; j += i {
				primes[j] = false
			}
		}
	}
	return primes
}

// sortWorkload performs tight refill and sort operations.
func sortWorkload(n, repetitions int) {
	for range repetitions {
		data := make([]float64, n)
		for i := range n {
			data[i] = float64(n - i)
		}
		sort.Float64s(data)
	}
}

// fibonacciIterative computes fibonacci with a single hot line for accumulation.
func fibonacciIterative(n int) uint64 {
	a, b := uint64(0), uint64(1)
	for range n {
		a, b = b, a+b
	}
	return a
}

// trigWorkload calls three transcendental functions on separate lines for graduated heat.
func trigWorkload(iterations int) {
	for i := range iterations {
		x := float64(i) / 100.0
		_ = math.Sin(x)
		_ = math.Cos(x)
		_ = math.Tan(x)
	}
}

// runComputeWorkloads is the entry point for CPU-intensive workloads, called from main.
// It runs multiple passes with larger workloads to accumulate enough profile data for visualization.
func runComputeWorkloads() {
	for range 20 {
		// Matrix multiplication with large matrices
		a := newMatrix(512, 1.0)
		b := newMatrix(512, 2.0)
		_ = matrixMultiply(a, b, 512)

		// Sieve of Eratosthenes
		_ = sieveOfEratosthenes(500000)

		// Sort workload
		sortWorkload(100000, 500)

		// Fibonacci
		_ = fibonacciIterative(2000000)

		// Trigonometric workload
		trigWorkload(5000000)
	}
}
