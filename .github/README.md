# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for continuous integration and deployment of the Nix configuration.

## Workflows

### 🔄 CI (`ci.yml`)
**Triggers:** Push/PR to main/master branches

Comprehensive CI pipeline that:
- ✅ Validates flake syntax and checks
- 🎨 Checks code formatting with `nix fmt`
- 🏗️ Builds all NixOS system configurations (desktop, vm, server, minimal)
- 🏠 Builds all Home Manager configurations 
- 📦 Builds custom packages (nvim, install, wallpapers)
- 🚀 Validates deployment configurations
- 🛡️ Runs security scans with Trivy
- 📊 Provides comprehensive summary

### 🔄 Cache (`cache.yml`)
**Triggers:** Push to main, daily schedule, manual dispatch

Builds and caches frequently used configurations:
- Desktop and VM NixOS systems
- Home Manager configurations
- Custom packages (nvim)
- Install ISO (on schedule/manual only)

### 📈 Updates (`update.yml`)
**Triggers:** Weekly schedule (Sundays), manual dispatch

Automated dependency management:
- Updates all flake inputs
- Tests updated configuration
- Creates PR with changes if updates available
- Includes proper testing and validation

### 🚀 Deploy Check (`deploy-check.yml`)
**Triggers:** Push/PR affecting system configurations

Validates deployment readiness:
- Checks deploy-rs configuration
- Validates system configurations
- Checks for secrets, SSH, and networking setup
- Provides deployment readiness assessment

## Features

### Caching Strategy
- Uses Determinate Systems Magic Nix Cache for optimal performance
- Parallel builds with fail-fast disabled for comprehensive testing
- Smart caching of commonly used configurations

### Security
- Automated vulnerability scanning with Trivy
- Results uploaded to GitHub Security tab
- SARIF format for integration with security tools

### Automation
- Automatic dependency updates via PRs
- Comprehensive test coverage before merging
- Build summaries and status reporting

### Matrix Builds
- Tests multiple system architectures (x86_64-linux, aarch64-linux)
- Validates all system and home configurations
- Parallel execution for faster feedback

## Configuration

### Required Secrets
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

### Optional Enhancements
To enable additional features, you can add these secrets:

- Custom cache endpoints
- Deployment credentials
- Notification webhooks

## Usage

### Manual Triggers
All workflows support manual triggering via `workflow_dispatch`:

```bash
# Trigger CI manually
gh workflow run ci.yml

# Update dependencies
gh workflow run update.yml

# Rebuild cache
gh workflow run cache.yml
```

### Monitoring
- Check workflow status in the Actions tab
- Review build summaries in workflow runs
- Monitor security alerts in the Security tab

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check flake syntax with `nix flake check`
   - Verify formatting with `nix fmt`
   - Test locally before pushing

2. **Cache Misses**
   - Cache workflow runs daily to keep builds warm
   - Manual trigger available for immediate cache refresh

3. **Update Failures**
   - Updates may fail if breaking changes occur in inputs
   - Review generated PR carefully before merging
   - Test updated configurations locally

### Local Testing
```bash
# Run the same checks locally
nix flake check --all-systems --show-trace
nix fmt -- --check .

# Build specific configurations
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#homeConfigurations."alexander@desktop".activationPackage
```

## Contributing

When modifying workflows:
1. Test changes in a fork first
2. Use proper YAML formatting
3. Follow existing patterns and naming
4. Update this documentation as needed
5. Consider impact on build times and cache efficiency
