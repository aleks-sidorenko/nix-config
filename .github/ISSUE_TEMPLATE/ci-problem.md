---
name: CI/Build Issue
about: Report problems with GitHub Actions workflows or build failures
title: '[CI] '
labels: ['ci', 'bug']
assignees: []
---

## Build/CI Issue

### Workflow
<!-- Which workflow is failing? -->
- [ ] CI (ci.yml)
- [ ] Update Dependencies (update.yml)
- [ ] Build and Cache (cache.yml)
- [ ] Deploy Check (deploy-check.yml)

### Problem Description
<!-- What is the issue? -->

### Error Messages/Logs
<!-- Paste relevant error messages or link to failed workflow run -->
```
[error logs here]
```

### Expected Behavior
<!-- What should happen instead? -->

### Configuration
<!-- If relevant -->
- System: <!-- desktop/vm/server/etc -->
- Architecture: <!-- x86_64-linux/aarch64-linux -->
- Home Manager config: <!-- alexander@desktop/etc -->

### Reproduction
<!-- Steps to reproduce the issue -->
1. 
2. 
3. 

### Local Testing
<!-- Have you tested this locally? -->
- [ ] `nix flake check` passes locally
- [ ] `nix fmt` shows no issues
- [ ] Configuration builds locally
- [ ] Issue only occurs in CI

### Additional Context
<!-- Any other information that might be helpful -->
