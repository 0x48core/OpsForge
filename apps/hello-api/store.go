package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// store holds the optional backing services. Each is enabled by its env var:
// DATABASE_URL (PostgreSQL) and REDIS_URL (Redis). Unset means "not used",
// so the app still runs on its own (lab 02).
type store struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

var errNotConfigured = errors.New("visits need both DATABASE_URL and REDIS_URL")

func openStore(ctx context.Context) (*store, error) {
	s := &store{}

	if url := os.Getenv("DATABASE_URL"); url != "" {
		db, err := pgxpool.New(ctx, url)
		if err != nil {
			return nil, fmt.Errorf("postgres: %w", err)
		}
		s.db = db
		if err := s.migrate(ctx); err != nil {
			return nil, fmt.Errorf("postgres migrate: %w", err)
		}
	}

	if url := os.Getenv("REDIS_URL"); url != "" {
		opt, err := redis.ParseURL(url)
		if err != nil {
			return nil, fmt.Errorf("redis: %w", err)
		}
		s.cache = redis.NewClient(opt)
	}

	return s, nil
}

func (s *store) migrate(ctx context.Context) error {
	_, err := s.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS visits (
			id         BIGSERIAL PRIMARY KEY,
			client_ip  TEXT        NOT NULL,
			visited_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`)
	return err
}

// ready reports the state of each backing service and whether all
// configured ones are reachable.
func (s *store) ready(ctx context.Context) (map[string]string, bool) {
	checks := map[string]string{"postgres": "not configured", "redis": "not configured"}
	ok := true

	if s.db != nil {
		checks["postgres"] = "ok"
		if err := s.db.Ping(ctx); err != nil {
			checks["postgres"], ok = "error: "+err.Error(), false
		}
	}
	if s.cache != nil {
		checks["redis"] = "ok"
		if err := s.cache.Ping(ctx).Err(); err != nil {
			checks["redis"], ok = "error: "+err.Error(), false
		}
	}
	return checks, ok
}

type visitStats struct {
	RedisCount int64 `json:"redis_count"`
	DBTotal    int64 `json:"db_total"`
}

func (s *store) visits(ctx context.Context) (visitStats, error) {
	if s.db == nil || s.cache == nil {
		return visitStats{}, errNotConfigured
	}
	var v visitStats
	n, err := s.cache.Get(ctx, "visits").Int64()
	if err != nil && !errors.Is(err, redis.Nil) {
		return v, err
	}
	v.RedisCount = n
	err = s.db.QueryRow(ctx, `SELECT count(*) FROM visits`).Scan(&v.DBTotal)
	return v, err
}

func (s *store) recordVisit(ctx context.Context, clientIP string) (visitStats, error) {
	if s.db == nil || s.cache == nil {
		return visitStats{}, errNotConfigured
	}
	if err := s.cache.Incr(ctx, "visits").Err(); err != nil {
		return visitStats{}, err
	}
	if _, err := s.db.Exec(ctx, `INSERT INTO visits (client_ip) VALUES ($1)`, clientIP); err != nil {
		return visitStats{}, err
	}
	return s.visits(ctx)
}

func (s *store) close() {
	if s.db != nil {
		s.db.Close()
	}
	if s.cache != nil {
		s.cache.Close()
	}
}
