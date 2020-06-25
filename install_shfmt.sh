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
docker run -i --rm -v "$(pwd)":/sh -w /sh shfmt "$@"
EOF

#docker run -i --rm -v "$(pwd)":/sh -w /sh shfmt -i 6 -ci -bn -sr -s -f -w "$@"


sudo chmod +x /tmp/shfmt
sudo install /tmp/shfmt /usr/local/bin/
