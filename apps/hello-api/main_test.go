package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// do sends a request to the app without a real server or network.
func do(t *testing.T, method, path string, header map[string]string) (*httptest.ResponseRecorder, map[string]any) {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	for k, v := range header {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	newMux(&store{}).ServeHTTP(rec, req) // no Postgres or Redis configured

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("%s %s: response is not JSON: %q", method, path, rec.Body.String())
	}
	return rec, body
}

func TestRoutes(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		path       string
		wantStatus int
		wantKey    string
		wantValue  string
	}{
		{"health is ok", "GET", "/health", http.StatusOK, "status", "ok"},
		{"root shows app name", "GET", "/", http.StatusOK, "app", "hello-api"},
		{"ready without backends", "GET", "/ready", http.StatusOK, "postgres", "not configured"},
		{"visits need backends", "GET", "/visits", http.StatusServiceUnavailable, "error", errNotConfigured.Error()},
		{"record visit needs backends", "POST", "/visits", http.StatusServiceUnavailable, "error", errNotConfigured.Error()},
		{"unknown path", "GET", "/nope", http.StatusNotFound, "error", "not found"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec, body := do(t, tt.method, tt.path, nil)
			if rec.Code != tt.wantStatus {
				t.Errorf("status = %d, want %d", rec.Code, tt.wantStatus)
			}
			if got := body[tt.wantKey]; got != tt.wantValue {
				t.Errorf("%s = %v, want %q", tt.wantKey, got, tt.wantValue)
			}
			if ct := rec.Header().Get("Content-Type"); !strings.HasPrefix(ct, "application/json") {
				t.Errorf("Content-Type = %q, want application/json", ct)
			}
		})
	}
}

func TestClientIP(t *testing.T) {
	_, body := do(t, "GET", "/", map[string]string{"X-Real-IP": "203.0.113.7"})
	if got := body["client_ip"]; got != "203.0.113.7" {
		t.Errorf("client_ip = %v, want the X-Real-IP header value", got)
	}

	_, body = do(t, "GET", "/", nil)
	if got := body["client_ip"]; got != "192.0.2.1" { // httptest's default RemoteAddr
		t.Errorf("client_ip = %v, want 192.0.2.1 without X-Real-IP", got)
	}
}

func TestHealthWhileDraining(t *testing.T) {
	draining.Store(true)
	defer draining.Store(false)

	rec, body := do(t, "GET", "/health", nil)
	if rec.Code != http.StatusServiceUnavailable || body["status"] != "draining" {
		t.Errorf("got %d %v, want 503 draining", rec.Code, body)
	}
	// Real traffic is still served while draining.
	if rec, _ := do(t, "GET", "/", nil); rec.Code != http.StatusOK {
		t.Errorf("GET / while draining = %d, want 200", rec.Code)
	}
}
