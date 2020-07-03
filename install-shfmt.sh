#!/bin/bash

set -ex

mkdir -p ~/projects
cd ~/projects

[ ! -d ~/projects/sh ] && git clone https://github.com/mvdan/sh.git

cd sh
git pull

docker build -t shfmt -f cmd/shfmt/Dockerfile .

cat - <<'EOF' > /tmp/shfmt
#!/bin/sh
docker run -i --rm -v "$(pwd)":/sh --user $(id -u):$(id -g) -w /sh shfmt "$@"
EOF

sudo chmod +x /tmp/shfmt
sudo install /tmp/shfmt /usr/local/bin/
