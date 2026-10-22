#include "VCamDriveGate.h"

void vcc_drive_gate_init(vcc_drive_gate_t *gate,
                         vcc_drive_gate_fn start,
                         vcc_drive_gate_fn stop,
                         void *context) {
  pthread_mutex_init(&gate->lock, NULL);
  gate->demand = 0;
  gate->running = false;
  gate->start = start;
  gate->stop = stop;
  gate->context = context;
}

void vcc_drive_gate_wake(vcc_drive_gate_t *gate) {
  pthread_mutex_lock(&gate->lock);
  gate->demand++;
  if (!gate->running) {
    gate->running = true;
    gate->start(gate->context);
  }
  pthread_mutex_unlock(&gate->lock);
}

uint64_t vcc_drive_gate_begin_tick(vcc_drive_gate_t *gate) {
  pthread_mutex_lock(&gate->lock);
  uint64_t seen = gate->demand;
  pthread_mutex_unlock(&gate->lock);
  return seen;
}

bool vcc_drive_gate_end_tick(vcc_drive_gate_t *gate, uint64_t seen, bool found) {
  if (found) return false;
  bool stopped = false;
  pthread_mutex_lock(&gate->lock);
  // A consumer that arrived during the tick may not have been in its
  // snapshot; the next tick sees it.
  if (gate->running && gate->demand == seen) {
    gate->running = false;
    gate->stop(gate->context);
    stopped = true;
  }
  pthread_mutex_unlock(&gate->lock);
  return stopped;
}

bool vcc_drive_gate_is_running(vcc_drive_gate_t *gate) {
  pthread_mutex_lock(&gate->lock);
  bool running = gate->running;
  pthread_mutex_unlock(&gate->lock);
  return running;
}
