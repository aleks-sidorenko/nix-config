[![CI](https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml)
[![Update Dependencies](https://github.com/aleks-sidorenko/nix-config/actions/workflows/update.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/update.yml)
[![Deploy Check](https://github.com/aleks-sidorenko/nix-config/actions/workflows/deploy-check.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/deploy-check.yml)

## 🚀 Features

Some features of my config:

- Structured with **snowfall** 
- Declarative disk layout with **disko**
- **Custom** live ISO for installing NixOS, including SD image for Rasbperry PI
- **Styling** with stylix
- **Opt-in persistance** through **impermanence** + blank snapshot
- **Encrypted BTRFS partition**
- **sops-nix** for secrets management
- Different environments like **hyprland** and **gnome**
- Custom **Neovim** setup declaratively using **nixvim**
- Homelab all configured in nix.
- **Automated CI/CD** with GitHub Actions for testing and validation


## 💽 Usage

### Prepare
#### Set up environment
```bash
export GITHUB_USER=aleks-sidorenko
export NIX_CONFIG_REPO_NAME=nix-config
export FLAKE_DIR=$HOME/.nix-config

git clone git@github.com:$GITHUB_USER/$NIX_CONFIG_REPO_NAME.git ~/$FLAKE_DIR/
cd $FLAKE_DIR

```
### Deploy/update
#### Locally
```bash
# To build system configuration (uses hostname to build flake)
nh os switch

# To build user configuration (uses hostname and username to build flake)
nh home switch
```

### Remotely
```bash
# Deploy config to VM (using SSH)
deploy .#vm --hostname vm --ssh-opts="-p 2222" --skip-checks

# Deploy config to server (using SSH)
deploy .#server --hostname server --ssh-user nixos --skip-checks
```

### Bootstrap
[Bootstrap](./docs/howto.md)


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
- Rasbperry PI 4 https://github.com/Stunkymonkey/nixos

### Resources

- https://snowfall.org/guides/lib/modules/
- https://nixos.wiki/wiki/NixOS_modules
- https://nix.dev/tutorials/module-system/deep-dive
- https://nixos.asia/en/nix-modules
- https://github.com/Stunkymonkey/nixos
- https://github.com/nix-community/nixos-anywhere/
- https://github.com/nix-community/disko
- https://github.com/Mic92/sops-nix
