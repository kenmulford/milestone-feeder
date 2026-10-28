# milestone-feeder: Codex apply_patch target parsing and lexical path
# normalization, sourced by no-source-edit.sh. Same contract as
# milestone-driver's hooks/patch-input.sh (the plugins ship independently, so
# this is a copy, not a reference).

# read_codex_patch <command>: sets PATCH_PATHS to every Add/Update/Delete target
# and every Update's Move-to destination between `*** Begin Patch` and
# `*** End Patch`. Hunk lines carry a +, - or space prefix, so their content is
# never read as an operation header.
read_codex_patch() {
  PATCH_PATHS=()
  local line mode='' active=0 target
  while IFS= read -r line || [ -n "$line" ]; do
    # Every trailing CR: jq on Windows writes a CRLF patch as \r\r\n.
    while [ "${line%$'\r'}" != "$line" ]; do line="${line%$'\r'}"; done
    if [ "$active" = 0 ]; then
      [ "$line" = '*** Begin Patch' ] && active=1
      continue
    fi
    [ "$line" = '*** End Patch' ] && break
    target=''
    case "$line" in
      '*** Add File: '*) mode=Add; target="${line#'*** Add File: '}" ;;
      '*** Update File: '*) mode=Update; target="${line#'*** Update File: '}" ;;
      '*** Delete File: '*) mode=Delete; target="${line#'*** Delete File: '}" ;;
      '*** Move to: '*) [ "$mode" = Update ] && target="${line#'*** Move to: '}" ;;
    esac
    target="${target#"${target%%[![:space:]]*}"}"
    target="${target%"${target##*[![:space:]]}"}"
    [ -n "$target" ] && PATCH_PATHS+=("$target")
  done <<< "$1"
}

# normalize_hook_path <path> <base>: lexical only, so new and deleted paths need
# not exist. Backslashes become slashes; drive, UNC and root prefixes survive.
normalize_hook_path() {
  local path="${1//\\//}" base="$2" prefix='' part result='' i
  local parts=() stack=()
  case "$path" in /*|[A-Za-z]:/*) ;; *) path="$base/$path" ;; esac
  case "$path" in
    [A-Za-z]:/*) prefix="${path:0:3}"; path="${path:3}" ;;
    //*) prefix='//'; path="${path:2}" ;;
    /*) prefix='/'; path="${path:1}" ;;
  esac
  IFS='/' read -r -a parts <<< "$path"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) i=${#stack[@]}; [ "$i" -gt 0 ] && unset 'stack[i-1]' ;;
      *) stack+=("$part") ;;
    esac
  done
  for part in "${stack[@]}"; do result="${result:+$result/}$part"; done
  printf '%s' "$prefix$result"
}
