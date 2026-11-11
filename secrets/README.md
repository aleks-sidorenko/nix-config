Encrypted secrets, one file per audience: the machines that can decrypt it.
A secret lives in the narrowest file that covers every machine reading it, so
nothing is copied between files. Recipients are the rules in `../.sops.yaml`.

- `server.yaml`: the home server.
