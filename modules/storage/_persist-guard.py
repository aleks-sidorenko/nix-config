import argparse
import json
import os
import stat
import sys


class Guard:
    def __init__(self, root, persisted, ignore):
        # Paths are as on the host; `root` only maps them onto the disk.
        self.root = root
        self.declared = set(persisted) | set(ignore)

    def has_declared_below(self, path):
        prefix = path.rstrip("/") + "/"
        return any(d.startswith(prefix) for d in self.declared)

    def failures(self, path, links=frozenset(), collapse=True):
        """The paths under `path` holding state nothing declares."""
        if path in self.declared:
            return []
        real = self.root + path
        try:
            st = os.lstat(real)
        except FileNotFoundError:
            return []
        if stat.S_ISLNK(st.st_mode):
            # A link loop holds no state.
            if path in links:
                return []
            target = os.path.normpath(
                os.path.join(os.path.dirname(path), os.readlink(real))
            )
            if self.failures(target, links | {path}):
                return [path]
            return []
        if stat.S_ISDIR(st.st_mode):
            try:
                entries = sorted(os.listdir(real))
            except FileNotFoundError:
                return []
            failing = [
                f
                for e in entries
                for f in self.failures(os.path.join(path, e), links)
            ]
            # Name the directory a service owns, not each file in it.
            if failing and collapse and not self.has_declared_below(path):
                return [path]
            return failing
        return [path] if st.st_size else []


def main():
    parser = argparse.ArgumentParser(
        description="List state that nothing persists or ignores."
    )
    parser.add_argument("config")
    parser.add_argument("--root", default="", help="prefix for every path")
    args = parser.parse_args()
    with open(args.config) as f:
        config = json.load(f)
    guard = Guard(args.root.rstrip("/"), config["persisted"], config["ignore"])
    failing = [
        f for w in config["walk"] for f in guard.failures(w, collapse=False)
    ]
    for path in failing:
        print(path)
    sys.exit(1 if failing else 0)


main()
