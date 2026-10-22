# The machine socket: vphone.sock

Every launch (headless too) serves `<library>/<name>/vphone.sock`, a Unix
socket that takes one JSON object per connection and returns one JSON line.
Connections are served concurrently. `vphone-launchpad-cli guest send` is the
normal way to use it; for scripts `nc -U` works the same:

```sh
vphone-launchpad-cli guest send myphone '{"t":"ping"}'
printf '%s\n' '{"t":"ping"}' | nc -U ~/.vphone/machines/myphone/vphone.sock
```

Use `controlSocket` from `vm list` as the path; it is null when the socket is
not there yet.

## Contents

- Requests
- Replies and the attached screen
- Coordinates
- Typing text
- Patterns that work

## Requests

| Request | Does |
| --- | --- |
| `{"t":"ping"}` | Checks that vphoned answers |
| `{"t":"screenshot","path":"/abs/shot.png"}` | Full-resolution capture to `path` (PNG or JPEG by extension). Without `path` it saves to the Desktop |
| `{"t":"tap","x":645,"y":1398}` | Tap |
| `{"t":"swipe","x1":645,"y1":2600,"x2":645,"y2":1400,"ms":300}` | Swipe; `ms` defaults to 300 |
| `{"t":"key","name":"home"}` | `home`, `power`, `volup`, `voldown` are hardware HID keys. Any other name (`return`, `cmd+v`) goes to vphoned `input.key` |
| `{"t":"type","text":"Hello"}` | Sets the **guest clipboard**; it does not type |
| `{"t":"rpc","method":"<vphoned method>","params":{…}}` | Calls any vphoned method; see [rpc-methods](rpc-methods.md) |

Unknown `t`, or missing fields, give `{"ok":false,"error":"…"}`.

## Replies and the attached screen

Success is `{"ok":true}`, with `result` for `rpc`, `path` for `screenshot`, and
`image` when a screen is attached. Failure is `{"ok":false,"error":"…"}`.

- `image` is a **small grayscale JPEG, base64**, meant for a quick "did
  something change" glance. It is not the real screen. For anything you must
  read (text, colors, layout), take a `screenshot` to a file and open the file,
  or use `ui.describe` / `ui.ocr`.
- `tap`, `swipe`, `key` and `type` attach one by default, 500 ms after the
  action. Add `"screen":false` to skip it; add `"delay":<ms>` for slow
  animations. `rpc` attaches none unless `"screen":true` (CLI: `guest rpc … --screen`).
- Inputs on the socket are serialized by the host, so a quick series of
  `tap` calls keeps its order. Wait for the reply before issuing the next.

## Coordinates

The socket's `tap` and `swipe` take **pixel coordinates of the 1290×2796
screen** (origin top left). The vphoned methods `input.tap`, `input.swipe` and
friends take **screen points**, as `device.screen` reports. Do not mix the two
in one script. When you do not know where a control is, do not guess: call
`ui.tree` or `ui.ocr`, which return positions, or use `ui.tap_element` with a
text selector and skip coordinates entirely.

## Typing text

`{"t":"type"}` only fills the clipboard. It stays in the guest: a guest
clipboard change made while the VM window is key is copied to the Mac
clipboard when the window loses focus, but not one made by `type`. A
`clipboard.set` through `rpc` is treated like a copy in the guest. Either
follow it with a paste:

```sh
vphone-launchpad-cli guest send myphone '{"t":"type","text":"hello","screen":false}'
vphone-launchpad-cli guest send myphone '{"t":"key","name":"cmd+v"}'
```

or call `input.type` through RPC, which sends key events (`delay_ms` between
keys, default 30), or `input.paste`. Use `input.type` for short ASCII and
paste for long or non-ASCII text.

## Patterns that work

- **Wake and unlock:** `vphone-launchpad-cli guest unlock myphone` (add
  `--passcode` when the guest has one). It works from any state; the keys only
  toggle. Check with `ping`, then `screenshot` to a file and look at it.
  A machine with `vm config <name> --unlock-at-startup on` (run through
  `vphone-launchpad-cli exec`) is unlocked by the host each time it starts.
- **Home:** `{"t":"key","name":"home"}`; **power** wakes or locks.
- **Open an app without hunting for its icon:** `apps.launch` with the bundle id.
- **Scroll a list:** swipe from lower to upper y, e.g. 2600 → 1400 at x 645.
- **Retry on flaps:** `guest not connected` (shown as `客体代理未连接` in the
  app) means the guest connection dropped mid-call. Wait a second and repeat; see [troubleshooting](troubleshooting.md).
