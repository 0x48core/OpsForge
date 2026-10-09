# Lab 20 — Performance troubleshooting

- **Phase:** 7 — Linux & OS internals
- **Status:** ⬜ todo
- **Started / finished:** — / —
- **Environment:** Fake VPS and the observability stack (lab 11)
- **Builds on:** Labs 11, 17, 19

> 📖 **Learn first:** `knowledge.md` is written when the lab starts.

## Goal

Find the cause of a slow or broken server quickly, with a method instead of guessing.

## Done when

- [ ] Apply the USE method (lab 11) with `top`/`htop`, `vmstat`, `iostat`, `pidstat`, `free`, and `sar`
- [ ] Diagnose five injected problems (`stress-ng`, small scripts): CPU hog, memory leak to OOM, disk saturation, file-descriptor leak, too many processes
- [ ] Use `strace` and `lsof` to see what a stuck process is waiting for
- [ ] Make a CPU flame graph with `perf` for hello-api under load
- [ ] Write a short incident note for each problem: symptom, evidence, cause, fix

## Steps

## Code

## What broke

## Lessons learned

## References
