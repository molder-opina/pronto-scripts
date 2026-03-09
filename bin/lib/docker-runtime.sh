#!/usr/bin/env bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

detect_container_cli() {
  if command_exists docker; then
    echo "docker"
    return 0
  fi
  if command_exists podman; then
    echo "podman"
    return 0
  fi
  return 1
}
