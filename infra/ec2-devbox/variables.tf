variable "aws_profile" {
  description = "AWS CLI profile to use. Must have EC2 rights. 'personal' is an SSO admin profile in a dedicated account (592197479706); run `aws sso login --profile personal` if creds expire."
  type        = string
  default     = "personal"
}

variable "region" {
  description = <<-EOT
    Region to run the devbox in.
      eu-west-3  (Paris)     — ~10-15ms from FR. Best typing feel. (default)
      eu-north-1 (Stockholm) — ~30-40ms, but ~10-15% cheaper.
    Latency matters here: every keystroke in tmux is a round trip.
  EOT
  type        = string
  default     = "eu-west-3"
}

variable "availability_zone" {
  description = "AZ for the instance + work volume. They must match (EBS is AZ-bound)."
  type        = string
  default     = "eu-west-3a"
}

variable "name" {
  description = "Name tag / prefix for all resources. The devbox CLI finds the instance by this tag."
  type        = string
  default     = "devbox"
}

variable "instance_type" {
  description = <<-EOT
    r7g.4xlarge = 16 vCPU / 128 GB, Graviton (arm64, matches your M-series Mac).
    Downshift to r7g.2xlarge (8 vCPU / 64 GB) to halve the hourly cost.
    Changing this later is just: stop -> apply -> start. No rebuild.
  EOT
  type        = string
  default     = "r7g.4xlarge"
}

variable "root_volume_gb" {
  description = "Root volume (OS + tooling only). Work lives on the separate volume below. Sized for the docker fleet — /var/lib/docker (8× supabase stacks) is the main consumer."
  type        = number
  default     = 300
}

variable "work_volume_gb" {
  description = <<-EOT
    Persistent work volume, mounted at /data (~/work symlinks to it).
    Measured: prsnl_app bare+8 worktrees = 37GB today, ~55GB once all 8 are built.
    300GB leaves room for other repos, caches and builds.
    NOTE: billed 24/7 even while the instance is stopped (~$28/mo at 300GB).
  EOT
  type        = number
  default     = 300
}

variable "username" {
  description = "Login user. 'ubuntu' is the AMI default and already has your SSH key wired up."
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Your SSH public key (e.g. contents of ~/.ssh/id_ed25519.pub, or your 1Password key)."
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = <<-EOT
    CIDRs allowed to reach port 22. Set this to YOUR IP: ["1.2.3.4/32"].
    Do NOT use 0.0.0.0/0. SSM Session Manager is enabled as a fallback if your IP moves.
  EOT
  type        = list(string)
}

variable "idle_stop_minutes" {
  description = <<-EOT
    Stop the box after this many minutes with: no tmux client attached, no Claude
    WORKING, and low load. A Claude that is actively working NEVER gets stopped.
    Touch ~/.devbox-nostop on the box to disable auto-stop entirely.
  EOT
  type        = number
  default     = 30
}
