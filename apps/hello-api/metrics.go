package main

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Prometheus metrics (lab 11). Scraped from GET /metrics.
var (
	registry = prometheus.NewRegistry()

	// RED metrics: Rate and Errors (by code) and Duration, per route.
	httpRequests = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "HTTP requests handled, by method, route pattern, and status code.",
	}, []string{"method", "route", "code"})

	httpDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request latency, by method and route pattern.",
		Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5},
	}, []string{"method", "route"})

	// A business metric: what the app is for, not just how it runs.
	visitsRecorded = prometheus.NewCounter(prometheus.CounterOpts{
		Name: "hello_api_visits_recorded_total",
		Help: "Visits successfully recorded in Postgres and Redis.",
	})
)

func init() {
	registry.MustRegister(
		httpRequests, httpDuration, visitsRecorded,
		collectors.NewGoCollector(),                                       // goroutines, GC, memory
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}), // CPU, open files, RSS
	)
}

func metricsHandler() http.Handler {
	return promhttp.HandlerFor(registry, promhttp.HandlerOpts{})
}

// statusRecorder remembers the status code a handler wrote.
type statusRecorder struct {
	http.ResponseWriter
	code int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.code = code
	r.ResponseWriter.WriteHeader(code)
}

// instrument records every request. It uses the matched route pattern
// (e.g. "GET /visits"), never the raw path, so that random URLs can't create
// unlimited label values (high cardinality) in Prometheus.
func instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, code: http.StatusOK}
		next.ServeHTTP(rec, r)

		route := r.Pattern // set by ServeMux on this request
		if route == "" || route == "/" {
			route = "unmatched"
		}
		httpRequests.WithLabelValues(r.Method, route, strconv.Itoa(rec.code)).Inc()
		httpDuration.WithLabelValues(r.Method, route).Observe(time.Since(start).Seconds())
	})
}
