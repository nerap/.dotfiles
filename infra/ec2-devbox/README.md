# EC2 devbox

One Graviton box that runs the whole worktree fleet, so 48GB of laptop RAM stops
being the ceiling. Everything you do today — `C-h/j/k/l/n/m/,/.` to switch worktrees,
`C-p` for the fleet dashboard, nvim, 4 Claudes in one worktree — works **unchanged**,
because it's the same tmux config on the other end of an SSH pipe.

## Why one box and not eight

The nav keys are `tmux switch-client` — a single-tmux-server operation. Across 8 hosts
there is no single server, so you'd need nested tmux (fighting over the prefix) and a
status agent per box for the dashboard. Cost is a wash (~$150-260/mo either way), so
it's decided on complexity — and one box needs **zero script changes**.

## What's here

| file | what |
|---|---|
| `main.tf` etc | instance, SG (SSH from your IP only), IAM+SSM, **separate 300GB work volume** |
| `user-data.sh` | first-boot: mount the work volume, `~/work` → `/data/work`. Secret-free. |
| `bootstrap.sh` | the real install — run over SSH **with agent forwarding**, so your private repos get cloned with your 1Password key and no credential ever lands on the box |
| `systemd/` | `fleet-boot` (rebuild tmux sessions after a stop) + `devbox-idle-stop` |

Plus two scripts in `etc/bin/.local/scripts/`: `devbox` (laptop CLI) and
`devbox-idle-stop` / `fleet-boot` (on the box).

## Setup

```sh
cd infra/ec2-devbox
cp terraform.tfvars.example terraform.tfvars   # add your pubkey + `curl -s ifconfig.me`/32
terraform init
terraform plan          # read it
terraform apply

devbox provision        # tooling + dotfiles (a few minutes)
devbox ssh
  clone-workspace -w git@github.com:<org>/prsnl_app.git   # 8 worktrees + 8 sessions
```

Then, forever after:

```sh
devbox up      # start, tunnel every dev port, attach tmux
devbox down    # stop now (or just walk away — see below)
devbox status
```

## The two things that make it feel local

**Ports.** `devbox up` writes `~/.ssh/devbox.conf` with a tunnel for every worktree's
vite (`8080+n`) and supabase (`54321+(n-1)*100`) ports. So `localhost:8081` in your
local browser still hits worktree 1. Nothing is exposed publicly.

**Sessions survive a stop.** Stopping an instance kills tmux. `fleet-boot.service`
rebuilds every `<repo>_<n>` session at boot with the usual layout, so you log back into
the same grid. Claude isn't auto-started (same as local — the right pane is a terminal);
your conversations are on disk, so `claude --continue` resumes them.

## Auto-stop

`devbox-idle-stop` runs every 5 min and stops the box after `idle_stop_minutes` of:
no tmux client attached **and** no Claude WORKING **and** low load average.

It reuses `fleet-card`'s Claude detection, so **a Claude that's mid-task is never
killed** — which a naive CPU-based idle check would happily do. Since
`instance_initiated_shutdown_behavior = "stop"`, this pauses billing rather than
destroying anything.

Disable it: `touch ~/.devbox-nostop` on the box.

## Cost

| | |
|---|---|
| `r7g.4xlarge` (16 vCPU / 128GB) | ~$0.96/hr Paris → **$145** @150h/mo, **$240** @250h/mo |
| 300GB gp3 work volume | **~$28/mo** — charged even while stopped |
| 40GB root + snapshots/egress | ~$10/mo |
| **total** | **~$180–280/mo** on-demand |

A 1-year Compute Savings Plan takes ~28% off the compute → **~$140–210/mo**.
The auto-stop is the biggest single lever; EBS is the floor you always pay.

Right-sizing: `r7g.2xlarge` (64GB) halves the hourly rate and is still 33% more RAM
than the laptop. Changing type later is stop → `terraform apply` → start; the work
volume is untouched (it has `prevent_destroy`).

## Gotchas worth knowing

- **`default` AWS profile can't do EC2.** It's `rush-uploader`. Use `admin` (already
  configured and verified).
- **Don't nest tmux.** SSH straight into the remote tmux (`devbox up` does). Keep the
  local tmux for other machines/windows.
- **Don't use mosh.** It doesn't reliably carry the CSI-u sequences that
  `Ctrl+M` / `Ctrl+,` / `Ctrl+.` depend on. Plain SSH + `ControlPersist` (configured).
- **Alacritty stays on the Mac.** It's the terminal emulator; it keeps emitting the
  CSI-u sequences and the remote tmux interprets them. Nothing to install on the box.
- **Region is a latency/price trade.** Paris ≈10-15ms; Stockholm is cheaper but ≈30-40ms,
  and you feel that on every keystroke.
