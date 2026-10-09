// hello-api is a tiny HTTP app used as the deploy target across OpsForge labs.
// Standard library only.
//
// Usage:
//
//	HOST=127.0.0.1 PORT=8000 ./hello-api
//	./hello-api healthcheck    # exit 0 if /health answers, for Docker HEALTHCHECK
//
// Endpoints:
//
//	GET  /        app info (hostname, time, client IP)
//	GET  /health  liveness: the process is up
//	GET  /ready   readiness: Postgres and Redis (if configured) are reachable
//	GET  /visits  visit counts from Redis and Postgres
//	POST /visits  record a visit in both
//
// Postgres and Redis are optional, enabled by DATABASE_URL and REDIS_URL.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// version is set at build time: go build -ldflags "-X main.version=1.0.0"
var version = "dev"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		os.Exit(healthcheck())
	}

	addr := net.JoinHostPort(getenv("HOST", "127.0.0.1"), getenv("PORT", "8000"))

	// Stop gracefully on SIGTERM (systemd stop, docker stop) so in-flight
	// requests finish instead of being dropped.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	st, err := openStore(ctx)
	if err != nil {
		log.Fatal(err)
	}
	defer st.close()

	srv := &http.Server{
		Addr:              addr,
		Handler:           logRequests(newMux(st)),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("hello-api %s listening on %s", version, addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	log.Print("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Print(err)
	}
}

// newMux wires the routes. Separate from main so tests can call it directly.
func newMux(st *store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		writeJSON(w, http.StatusOK, map[string]string{
			"app":     "hello-api",
			"version": version,
			"host":    host,
			"time":    time.Now().UTC().Format(time.RFC3339),
			// Behind Nginx the real client IP arrives in X-Real-IP.
			"client_ip": clientIP(r),
		})
	})
	mux.HandleFunc("GET /ready", func(w http.ResponseWriter, r *http.Request) {
		checkCtx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		checks, ok := st.ready(checkCtx)
		status := http.StatusOK
		if !ok {
			status = http.StatusServiceUnavailable
		}
		writeJSON(w, status, checks)
	})
	mux.HandleFunc("GET /visits", func(w http.ResponseWriter, r *http.Request) {
		v, err := st.visits(r.Context())
		writeResult(w, v, err)
	})
	mux.HandleFunc("POST /visits", func(w http.ResponseWriter, r *http.Request) {
		v, err := st.recordVisit(r.Context(), clientIP(r))
		writeResult(w, v, err)
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
	})
	return mux
}

// healthcheck lets the container check itself without curl or wget,
// which the distroless image doesn't have.
func healthcheck() int {
	url := "http://" + net.JoinHostPort("127.0.0.1", getenv("PORT", "8000")) + "/health"
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return 1
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return 1
	}
	return 0
}

func clientIP(r *http.Request) string {
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(body)
}

func writeResult(w http.ResponseWriter, body any, err error) {
	switch {
	case errors.Is(err, errNotConfigured):
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": err.Error()})
	case err != nil:
		log.Print(err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
	default:
		writeJSON(w, http.StatusOK, body)
	}
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s %s", clientIP(r), r.Method, r.URL.Path, time.Since(start))
	})
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
