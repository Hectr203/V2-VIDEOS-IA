# Networking

[Documentation](../README.md) · [Create a VM](create-and-run.md) · [Troubleshooting](troubleshooting.md)

Each VM has one network mode, stored in its `config.plist`. It is read when the
VM starts, so a change applies from the next launch.

| Mode | How the guest reaches the internet | Use it when |
| --- | --- | --- |
| `nat` | Virtualization.framework's built-in NAT | The default. The Mac has no VPN, or the VPN does not need to carry the guest. |
| `bridged` | Directly on a physical interface of the Mac, with its own address on that network | The guest has to be reachable from other machines on the LAN. |
| `tunnel` | Through ordinary connections opened by `vphone-vm` on the Mac | The Mac's traffic goes through a VPN or a proxy app, and the guest's traffic must follow it. |
| `none` | No network device | The guest must stay offline. |

## Choosing a mode

In Launchpad, stop the machine, then choose Settings… from the `⋯` menu or the
right-click menu. The Network section has a Mode picker. New Machine sets the mode under
Advanced Options.

From the command line:

```sh
vphone-cli vm config <name> --network tunnel
# or through Launchpad
vphone-launchpad-cli exec vm config <name> --network tunnel
```

`tunnel` needs a `VPhone.bundle` that lists it in `vphone-cli vm config --help`.
An older bundle rejects the setting.

## Why `tunnel` exists

`nat` and `bridged` send the guest's packets out through a physical interface.
When a VPN owns the Mac's default route (WireGuard, Cloudflare WARP, or a proxy
app in TUN mode such as Surge or Clash), those packets skip the VPN. They leave
unencrypted, or not at all.

In `tunnel` mode the guest's network card is implemented inside `vphone-vm`.
It answers DHCP, ARP and ping for the gateway, and turns each guest TCP
connection and UDP flow into a normal socket on the Mac. Those sockets follow
the Mac's routing table like any other app's, so the VPN carries them. It needs
no root, no new network interface and no change to the Mac's network settings.

In a proxy app the guest shows up as its own client, named after the machine,
and the app's rules apply to it as they would to any other app.

## What the guest sees

| Item | Value |
| --- | --- |
| Guest address | `192.168.127.3/24` by DHCP, or the [fixed address](#fixed-address) |
| Gateway and DNS | `192.168.127.1`, or the first address of the fixed address's subnet |
| MTU | 1500 |
| DNS | Queries to `192.168.127.1` go to the Mac's resolver |
| Other connections to the gateway | The Mac's loopback, `127.0.0.1` (TCP and UDP) |

## Limits

- **IPv4 only.** The guest gets no IPv6 address, and IPv6 traffic is dropped.
- **Outbound only, apart from forwarded ports.** Nothing on the Mac or the LAN
  can reach the guest through this network except the ports listed under
  [Port forwarding](#port-forwarding). USB access (`iproxy`, `ideviceinstaller`)
  and `vphone.sock` do not use the guest network, so they still work.
- **Ping reaches the gateway only.** ICMP to the internet is not forwarded,
  so `ping 1.1.1.1` in the guest fails even while TCP and UDP work.
- **Throughput is limited by `vphone-vm`.** Every packet is handled in this
  process. Downloads and video work, but `nat` is faster when no VPN is involved.

## Checking it works

1. Start the machine and wait for it to finish booting.
2. Read the guest's address:

   ```sh
   vphone-launchpad-cli guest rpc <name> device.network
   ```

   `en0` should show `192.168.127.3`. If it shows only an `fe80::` address,
   DHCP has not finished yet. Wait a few seconds and try again.
3. Open a page in the guest:

   ```sh
   vphone-launchpad-cli guest rpc <name> apps.open_url '{"url":"https://example.com"}'
   ```

4. On the Mac, the connections belong to `vphone-vm` and use the VPN's address:

   ```sh
   lsof -nP -a -i -p "$(pgrep -f 'vphone-vm.*<name>')"
   ```

## MAC address

The first launch gives the guest's network card a random, locally administered
MAC address and saves it in `config.plist`, the way it saves the machine
identifier. The guest then keeps one identity, and one DHCP lease, across
launches. To set or replace it:

```sh
vphone-cli vm config <name> --mac 02:11:22:33:44:55
vphone-cli vm config <name> --mac random   # a new one now
vphone-cli vm config <name> --mac auto     # a new one at the next launch
```

A cloned machine keeps the MAC of the original, like its machine identifier.
Clone with `vm clone --new-identity` to give the copy new ones, or give it a
new MAC before running both at once. `--new-identity` also clears the copy's
fixed address, port forwards and mDNS name.

## Addresses held by old MACs

In `nat` mode the Mac's DHCP server keeps each address bound to the MAC it
was given to, even after the lease runs out. It hands that address to anyone
else only once every other address in the range is taken. Deleting a machine
or replacing its MAC leaves its address bound to a MAC nothing uses any more,
and so does every launch made before MACs were saved. New guests then get
higher and higher addresses, until they reach the fixed addresses picked high
in the range.

`vm leases` lists the leases on the shared network and who owns each. It
needs `VPhone.bundle` 2.5 or later:

```sh
vphone-cli vm leases
sudo vphone-cli vm leases --release-orphans
```

An orphan is an iOS or iPadOS guest's lease whose MAC belongs to no machine in
the library and whose lease has run out. `--release-orphans` removes the
orphans from `/var/db/dhcpd_leases` and has the DHCP server read the file
again, so it needs root. It never touches:

- a machine's own lease, even one that ran out while the machine was stopped;
- a lease that has not run out, such as a running guest's whose MAC was just
  replaced;
- leases of other VM apps, or of devices on Internet Sharing.

Machines in another library count only when that library is named too:
repeat `--library-root` for each. The release refuses to run when a library
has no machines or a machine's settings cannot be read, since every lease
there would look orphaned.

In Launchpad, Host Setup shows the count under NAT Network, and Release…
frees them after an administrator approves. It compares against every
library Launchpad lists. From the command line:

```sh
vphone-launchpad-cli vm leases
vphone-launchpad-cli vm leases --release
```

## Fixed address

`--ip` gives the guest a fixed IPv4 address. Without a prefix, `/24` is
assumed. `--gateway` and `--dns` are optional; `auto` returns them to the
default, and `--ip dhcp` removes the fixed address.

```sh
vphone-cli vm config <name> --ip 192.168.64.50
vphone-cli vm config <name> --network tunnel --ip 10.20.0.5/16 --dns 1.1.1.1
vphone-cli vm config <name> --ip dhcp
```

How the address reaches the guest depends on the mode:

| Mode | Address | How it is applied |
| --- | --- | --- |
| `nat` | On the Mac's shared NAT network, normally `192.168.64.0/24` | vphoned writes it into the guest's network settings. The gateway and DNS are the Mac, `192.168.64.1`. |
| `tunnel` | Any private subnet | The tunnel's own DHCP hands it out. The gateway, which is also the DNS resolver, is the subnet's first address unless `--gateway` names another. |
| `bridged` | An address on the physical network | vphoned writes it into the guest. Set `--gateway` and `--dns` to the network's own. |

In `nat` mode the address has to be on the shared network, the one every `nat`
VM uses (vmnet's `Shared_Net_Address`, if it has been moved). For any other
subnet, use `tunnel`. macOS 26 can give a VM a NAT network of its own, but the
subnet then stays reserved after the VM stops (still so 40 minutes later in
testing), and every launch on it fails meanwhile, so vphone does not use it.

vphoned applies the address each time `vphone-vm` connects to it, so a guest
changed while the Mac was not looking is put back. It only ever undoes its own
setting: an address typed into the guest's Settings app is left alone when the
VM goes back to DHCP. An address on the shared `nat` network is not reserved in
the Mac's DHCP server, so pick one high in the range, such as `.200`, that DHCP
is unlikely to have handed to another VM.

## Port forwarding

`--forward` carries a port on the Mac into the guest, in `nat` and `tunnel`
modes. The form is `[tcp|udp:][host-address:]host-port:guest-port`. A forward
listens on `127.0.0.1` unless a host address is given; `0.0.0.0` makes it
reachable from other devices on the LAN.

```sh
vphone-cli vm config <name> --forward tcp:8022:22
vphone-cli vm config <name> --forward udp:0.0.0.0:5353:53
vphone-cli vm config <name> --remove-forward 8022
vphone-cli vm config <name> --clear-forwards
```

`vphone-vm` opens the listeners when the VM starts and closes them when it
stops. In `nat` mode it connects to the guest's address: the fixed one, or the
one vphoned reports. In `tunnel` mode the connection reaches the guest as if it
came from the gateway. A port that is already taken on the Mac is reported in
the VM's log and skipped; the rest still work. `bridged` puts the guest on the
LAN with its own address, so it needs no forwards.

## Name on the local network (mDNS)

Off by default. `--mdns on` makes the guest answer to `<vm-name>.local`, with
anything but letters and digits in the VM name turned into hyphens
(`ipad_pro.13` becomes `ipad-pro-13.local`). `--mdns <name>` picks another
name, and `--mdns off` puts the guest's own name back.

```sh
vphone-cli vm config <name> --mdns on
ping <vm-name>.local
```

vphoned sets the name in the guest's network settings (`LocalHostName`) each
time `vphone-vm` connects, and the guest's mDNSResponder announces it on every
link it has. Besides its network card, a guest has the network link a USB-connected
iPhone gives the Mac, which shows up on the Mac as an `en` interface with a
`169.254` address. So the name works in
every mode, `none` included:

| Mode | `<name>.local` resolves to |
| --- | --- |
| `nat` | The guest's address on the shared network, and its USB link address |
| `bridged` | The guest's LAN address, for every device on the LAN, and its USB link address on the Mac |
| `tunnel`, `none` | The guest's USB link address, on the Mac only |

The USB link address is link-local, but the Mac reaches the guest on it
directly, so in `tunnel` mode a connection to `<name>.local` reaches a guest
service without a port forward.

If another device already uses the name, mDNS renames the guest (`name-2`).
Renaming the VM with `vm rename` renames a name `--mdns on` derived from it;
one picked by hand stays. A VM stopped with `vm stop` or by closing its window
cannot withdraw its announcement, so the Mac's resolver keeps returning the
old address until the cached record expires, which for a host address is 75
minutes (TTL 4500 s).

## This Mac's name in the guest

On by default. The guest resolves this Mac's mDNS name (`scutil --get
LocalHostName`, plus `.local`) at once, to the address it reaches the Mac at:

| Mode | `<Mac>.local` in the guest |
| --- | --- |
| `nat` | The Mac on the shared network, usually `192.168.64.1` |
| `tunnel` | The gateway, `192.168.127.1` by default. Connections to it reach the Mac's loopback (`127.0.0.1`), the way `10.0.2.2` does in QEMU and VirtualBox |
| `bridged` | The Mac's address on the bridged interface |

Over mDNS alone, an IPv4 lookup of the Mac's name in the guest could fail. The
guest also hears the Mac on the network link a USB-connected iPhone gives the
Mac, where the Mac has no IPv4 address and answers "no such record". Whichever
link answers first decides the lookup, so an app that wants an IPv4 address
got an error until a real answer had been cached from another link.

vphoned registers the name with the guest's own mDNSResponder the way it
holds an `/etc/hosts` line: as a local record that answers an IPv4 lookup at
once, with that one address, without asking the network and without the
answers it has cached. It does so each time `vphone-vm` connects, and again
when vphoned starts, so the name is in place before apps run after a reboot.
The guest's system volume is read-only, so `/etc/hosts` itself is not edited,
and nothing is announced on any network. IPv6 lookups still go to mDNS.

Without it, a lookup also listed the Mac's `169.254` address on the USB link,
first. iOS routes `169.254.0.0/16` through its primary interface, so a plain
socket connecting to that address could leave through `en0`, where nothing
answers, and wait out its timeout.

```sh
vphone-cli vm config <name> --mac-name off   # withdraw it
```

To see what the guest's resolver returns, and whether each address connects:

```sh
vphone-launchpad-cli guest rpc <name> network.resolve '{"host":"<Mac>.local","family":"ipv4","port":8000}'
```

## Unplugging a running VM

`vm network` acts on a VM that is running, and nothing it does is saved:

```sh
vphone-cli vm network <name>               # state of the NIC
vphone-cli vm network <name> --link down   # unplug the cable
vphone-cli vm network <name> --link up     # plug it back in
```

The guest sees the link drop and come back. The same is available on
`vphone.sock` as `{"t":"network"}`, with `"link":"down"` or `"link":"up"`.

A running VM cannot move to another network. Virtualization accepts the
change and then stops the VM with an internal error, so `vm network` only ever
puts back the network the VM started on. Change the mode with `vm config` and
restart.

In Launchpad, Settings… has Address and Port Forwarding sections when one
machine is selected.
