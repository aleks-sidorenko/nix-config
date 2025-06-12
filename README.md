
## 💽 Usage

### Prepare
#### Set up environment
```bash
export GITHUB_USER=aleks-sidorenko
export NIX_CONFIG_REPO_NAME=nix-config
export FLAKE_DIR=$HOME/.nix-config
```

#### Enabled SSH
#### VM
VM is provisioned via Vagrant and has SSH enabled already with keys copied from GitHub.
```
vagrant up
vagrant ssh-config >> .ssh.config
```
#### Non-VM
You will need to be able to SSH to the target machine from where this command will be run. Load nix installer ISO if
no OS on the device. You need to copy ssh keys onto the target machine 
```bash
mkdir -p ~/.ssh && curl https://github.com/$GITHUB_USER.keys > ~/.ssh/authorized_keys
```
In my case I can copy them from GitHub.


### Install

To install NixOS on any of my devices I now use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/no-os.md).

```bash
git clone git@github.com:$GITHUB_USER/$NIX_CONFIG_REPO_NAME.git ~/$FLAKE_DIR/
cd $FLAKE_DIR

nix develop

nixos-anywhere --flake '.#desktop' nixos@192.168.1.8 # Replace with your IP
```

After building it you can copy the ISO from the `result` folder to your USB.
Then run `nix_installer`, which will then ask you which host you would like to install.

### Building

To build my config for a specific host you can do something like:

```bash
git clone git@github.com:$GITHUB_USER/$NIX_CONFIG_REPO_NAME.git ~/$FLAKE_DIR/
cd $FLAKE_DIR

nix develop

# To build system configuration (uses hostname to build flake)
nh os switch

# To build user configuration (uses hostname and username to build flake)
nh home switch

# Build ISO in result/ folder
c

# Deploy config to VM (using SSH)
deploy .#vm --hostname vm --ssh-opts="-p 2222" --skip-checks

# Deploy config to server (using SSH)
deploy .#server --hostname server --ssh-user nixos --skip-checks

```

## 🚀 Features

Some features of my config:

- Structured to allow multiple **NixOS configurations**, including **desktop**, **laptop** and **homelab**
- **Custom** live ISO for installing NixOS
- **Styling** with stylix
- **Opt-in persistance** through impermanence + blank snapshot
- **Encrypted BTRFS partition**
- **sops-nix** for secrets management
- Different environments like **hyprland** and **gnome**
- Custom **Neovim** setup declaratively using **nixvim**
- Homelab all configured in nix.

## 🏠 Configurations


| Hostname  |                Board                |                                 CPU                                 |  RAM  |              Primary GPU              | Role  |  OS   | State |
| :-------: | :---------------------------------: | :-----------------------------------------------------------------: | :---: | :-----------------------------------: | :---: | :---: | :---: |
| `desktop` | ASUS P8P67 PRO (REV 3.0) P67/ s1155 |                         Intel Core i7-2600K                         | 32GB  | Asus PCI-Ex GeForce GTX 560 Ti 1024MB |   🖥️   |   ❄️   |   ✅   |
| `server`  |        Rasberry PI 4 model B        | Broadcom BCM2711, Quad core Cortex-A72 (ARM v8) 64-bit SoC @ 1.8GHz |  8GB  |              Integrated               |   ☁️   |   ❄️   |   ✅   |


**Key**

- 🖥️ : Desktop
- 💻️ : Laptop
- 🎮️ : Games Machine
- 🐄 : Virtual Machine
- ☁️ : Server


## Appendix

- <a href="https://www.flaticon.com/free-icons/dot" title="dot icons">Dot icons created by Roundicons - Flaticon</a>
- [Wallpaper From Catppuccin Discord](https://discord.com/channels/907385605422448742/1199293891392852009)
  - Galaxy: https://discord.com/channels/907385605422448742/1199293891392852009
  - Old Catppuccin wallpaper: https://github.com/Gingeh/wallpapers
  - Catppuccino: https://discord.com/channels/907385605422448742/1130546126374838342
  - Catppuccino: https://discord.com/channels/907385605422448742/1130546126374838342

### Inspired By

- hmajid2301 config, snowfall based https://github.com/hmajid2301/nixicle
- jakehamilton config, snowfall based, mature config with big amount of modules https://github.com/jakehamilton/config/tree/main
- 8bitbuddhist config, snowfall based https://github.com/8bitbuddhist/nix-configuration
- Misterio77 config https://github.com/Misterio77/nix-config
- EmergentMind config https://github.com/EmergentMind/nix-config
- Nice nixvim config https://github.com/dc-tec/nixvim

