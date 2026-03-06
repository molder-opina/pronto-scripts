#!/usr/bin/env bash

detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "darwin"
      ;;
    Linux*)
      echo "linux"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

sed_inplace() {
  local expression="$1"
  local target_file="$2"
  local os_name
  os_name="$(detect_os)"

  if [[ "$os_name" == "darwin" ]]; then
    sed -i '' "$expression" "$target_file"
  else
    sed -i "$expression" "$target_file"
  fi
}
