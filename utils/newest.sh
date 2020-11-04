#!/bin/bash

newest() {
  find ./* -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2- | xargs -I{} vim {}
}

export -f newest

newest
