{
  writeTextFile,
  shellcheck,
}:
# Sourced by our scripts: `source ${shell-lib}`.
writeTextFile {
  name = "shell-lib.sh";
  text = builtins.readFile ./shell-lib.sh;
  checkPhase = ''
    ${shellcheck}/bin/shellcheck --shell=bash "$target"

    # Each case is a script named like the tool it stands for.
    run() {
      local name="$1" body="$2"
      mkdir -p bin
      printf 'source %s\n%s\n' "$target" "$body" >"bin/$name"
      bash "bin/$name"
    }
    expect() {
      local what="$1" want="$2" got="$3"
      [ "$got" = "$want" ] || { echo "$what: expected '$want', got '$got'" >&2; exit 1; }
    }

    expect "log writes to stderr only" "" "$(run tool 'log hi' 2>/dev/null)"
    expect "log" "hi" "$(run tool 'log hi' 2>&1)"
    expect "warn names the tool" "tool: careful" "$(run tool 'warn careful' 2>&1)"
    expect "warn names a wrapped tool" "tool: careful" "$(run .tool-wrapped 'warn careful' 2>&1)"
    expect "die exits 1" 1 "$(run tool 'die no' 2>/dev/null || echo $?)"
    expect "die stops the script" "tool: no" "$(run tool 'die no; log after' 2>&1)"
    expect "confirm takes the typed name" "ok" \
      "$(echo host | run tool 'confirm "Sure?" host; log ok' 2>&1 | tail -1)"
    expect "confirm refuses another" "tool: not confirmed" \
      "$(echo other | run tool 'confirm "Sure?" host; log ok' 2>&1 | tail -1)"
  '';
  meta.description = "Logging and confirmation helpers our scripts source";
}
