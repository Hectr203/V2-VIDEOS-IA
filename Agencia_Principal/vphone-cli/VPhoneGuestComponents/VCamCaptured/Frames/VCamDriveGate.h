#ifndef VCAM_DRIVE_GATE_H
#define VCAM_DRIVE_GATE_H

// Keeps the 30 Hz frame drive timer running only while something can take a
// frame. The timer used to fire for the daemon's whole life, waking an idle
// cameracaptured 30 times a second with no camera client at all.
//
// Every new consumer (an opened viewfinder stream, a new video sink) wakes the
// gate, which starts the timer if it was stopped. A tick that finds nothing to
// drive stops it again, unless a consumer arrived while that tick ran. The
// start and stop callbacks run under the gate's lock, so a stop can never
// overtake a later start.

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

#pragma GCC visibility push(hidden)

typedef void (*vcc_drive_gate_fn)(void *context);

typedef struct vcc_drive_gate_s {
  pthread_mutex_t lock;
  // Bumped by every wake; a tick compares it with what it saw at its start.
  uint64_t demand;
  bool running;
  vcc_drive_gate_fn start;
  vcc_drive_gate_fn stop;
  void *context;
} vcc_drive_gate_t;

void vcc_drive_gate_init(vcc_drive_gate_t *gate,
                         vcc_drive_gate_fn start,
                         vcc_drive_gate_fn stop,
                         void *context);

// A consumer appeared. Starts the timer when it is stopped.
void vcc_drive_gate_wake(vcc_drive_gate_t *gate);

// Called at the beginning of a tick; pass the result to vcc_drive_gate_end_tick.
uint64_t vcc_drive_gate_begin_tick(vcc_drive_gate_t *gate);

// Called at the end of a tick. `found` is whether the tick had any consumer
// to drive. Returns true when the gate stopped the timer.
bool vcc_drive_gate_end_tick(vcc_drive_gate_t *gate, uint64_t seen, bool found);

bool vcc_drive_gate_is_running(vcc_drive_gate_t *gate);

#pragma GCC visibility pop

#endif
