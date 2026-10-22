/*
 * Host proof harness for the gate that keeps cameracaptured's 30 Hz frame
 * drive running only while a viewfinder stream or video sink exists
 * (VCamCaptured/Frames/VCamDriveGate.c).
 *
 * Build/run:  make -C VPhoneGuestComponents test-vcam-drive-gate
 */

#include "VCamDriveGate.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>

static int g_checks = 0;
static int g_fails = 0;

#define CHECK(cond, ...)                          \
  do {                                            \
    g_checks++;                                   \
    if (!(cond)) {                                \
      g_fails++;                                  \
      printf("FAIL %s:%d: ", __FILE__, __LINE__); \
      printf(__VA_ARGS__);                        \
      printf("\n");                               \
    }                                             \
  } while (0)

// The timer as the callbacks see it: armed or not, and how often each
// transition happened. A start while armed or a stop while disarmed would be
// a lost or doubled transition.
typedef struct {
  int armed;
  int starts;
  int stops;
  int bad;
} fake_timer_t;

static void fake_start(void *context) {
  fake_timer_t *t = context;
  if (t->armed) t->bad++;
  t->armed = 1;
  t->starts++;
}

static void fake_stop(void *context) {
  fake_timer_t *t = context;
  if (!t->armed) t->bad++;
  t->armed = 0;
  t->stops++;
}

static void test_starts_stopped(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  CHECK(!vcc_drive_gate_is_running(&gate), "a new gate must not run");
  CHECK(t.starts == 0 && t.stops == 0, "init must not touch the timer");
}

static void test_wake_starts_once(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  vcc_drive_gate_wake(&gate);
  vcc_drive_gate_wake(&gate);
  vcc_drive_gate_wake(&gate);
  CHECK(t.starts == 1, "three wakes started the timer %d times", t.starts);
  CHECK(t.armed && vcc_drive_gate_is_running(&gate), "the timer must run");
}

static void test_busy_tick_keeps_running(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  vcc_drive_gate_wake(&gate);
  for (int i = 0; i < 100; i++) {
    uint64_t seen = vcc_drive_gate_begin_tick(&gate);
    CHECK(!vcc_drive_gate_end_tick(&gate, seen, true), "a tick with consumers stopped the timer");
  }
  CHECK(t.armed && t.stops == 0, "the timer must still run");
}

static void test_idle_tick_stops(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  vcc_drive_gate_wake(&gate);
  uint64_t seen = vcc_drive_gate_begin_tick(&gate);
  CHECK(vcc_drive_gate_end_tick(&gate, seen, false), "an idle tick must stop the timer");
  CHECK(!t.armed && t.stops == 1, "the timer must be stopped once");
  // A late tick already queued when the timer stopped changes nothing.
  seen = vcc_drive_gate_begin_tick(&gate);
  CHECK(!vcc_drive_gate_end_tick(&gate, seen, false), "a stopped gate stopped again");
  CHECK(t.stops == 1 && t.bad == 0, "stops %d, bad transitions %d", t.stops, t.bad);
}

static void test_wake_during_tick_keeps_running(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  vcc_drive_gate_wake(&gate);
  // The tick snapshots no consumer, then a sink is built before it ends.
  uint64_t seen = vcc_drive_gate_begin_tick(&gate);
  vcc_drive_gate_wake(&gate);
  CHECK(!vcc_drive_gate_end_tick(&gate, seen, false),
        "a consumer that arrived during the tick was dropped");
  CHECK(t.armed && t.starts == 1 && t.stops == 0, "the timer must keep running");
  // The next tick sees it gone again and stops.
  seen = vcc_drive_gate_begin_tick(&gate);
  CHECK(vcc_drive_gate_end_tick(&gate, seen, false), "the following idle tick must stop");
}

static void test_restart_after_stop(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  for (int round = 0; round < 5; round++) {
    vcc_drive_gate_wake(&gate);
    uint64_t seen = vcc_drive_gate_begin_tick(&gate);
    vcc_drive_gate_end_tick(&gate, seen, true);
    seen = vcc_drive_gate_begin_tick(&gate);
    vcc_drive_gate_end_tick(&gate, seen, false);
  }
  CHECK(t.starts == 5 && t.stops == 5 && !t.armed && t.bad == 0,
        "five camera sessions: starts %d, stops %d, armed %d, bad %d", t.starts, t.stops, t.armed,
        t.bad);
}

// Wakes from graph-build threads race idle ticks from the drive queue. Every
// transition must alternate, and a wake must never be left with the timer off.
typedef struct {
  vcc_drive_gate_t *gate;
  atomic_int *done;
} race_arg_t;

static void *waker(void *arg) {
  race_arg_t *r = arg;
  for (int i = 0; i < 20000; i++) vcc_drive_gate_wake(r->gate);
  atomic_store(r->done, 1);
  return NULL;
}

static void test_concurrent_wakes_and_ticks(void) {
  fake_timer_t t = {0};
  vcc_drive_gate_t gate;
  vcc_drive_gate_init(&gate, fake_start, fake_stop, &t);
  atomic_int done = 0;
  race_arg_t arg = {&gate, &done};
  pthread_t thread;
  pthread_create(&thread, NULL, waker, &arg);
  while (!atomic_load(&done)) {
    uint64_t seen = vcc_drive_gate_begin_tick(&gate);
    vcc_drive_gate_end_tick(&gate, seen, false);
  }
  pthread_join(thread, NULL);
  CHECK(t.bad == 0, "%d transitions out of order", t.bad);
  CHECK(t.starts == t.stops + (t.armed ? 1 : 0), "starts %d, stops %d, armed %d", t.starts,
        t.stops, t.armed);
  CHECK(vcc_drive_gate_is_running(&gate) == (t.armed != 0), "gate and timer disagree");
}

int main(void) {
  test_starts_stopped();
  test_wake_starts_once();
  test_busy_tick_keeps_running();
  test_idle_tick_stops();
  test_wake_during_tick_keeps_running();
  test_restart_after_stop();
  test_concurrent_wakes_and_ticks();
  printf("VCamDriveGateTests: %d checks, %d failures\n", g_checks, g_fails);
  return g_fails == 0 ? 0 : 1;
}
