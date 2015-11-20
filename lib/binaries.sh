needs_resolution() {
  local semver=$1
  if ! [[ "$semver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  else
    return 1
  fi
}

install_nodejs() {
  local version="$1"
  local dir="$2"

  if needs_resolution "$version"; then
    echo "Resolving node version ${version:-(latest stable)} via semver.io..."
    local version=$(curl --silent --get --data-urlencode "range=${version}" https://semver.herokuapp.com/node/resolve)
  fi

  echo "Downloading and installing node $version..."
  local download_url="http://s3pository.heroku.com/node/v$version/node-v$version-$os-$cpu.tar.gz"
  curl "$download_url" --silent --fail -o /tmp/node.tar.gz || (echo "Unable to download node $version; does it exist?" && false)
  tar xzf /tmp/node.tar.gz -C /tmp
  rm -rf $dir/*
  mv /tmp/node-v$version-$os-$cpu/* $dir
  chmod +x $dir/bin/*
}

install_iojs() {
  local version="$1"
  local dir="$2"

  if needs_resolution "$version"; then
    echo "Resolving iojs version ${version:-(latest stable)} via semver.io..."
    version=$(curl --silent --get --data-urlencode "range=${version}" https://semver.herokuapp.com/iojs/resolve)
  fi

  echo "Downloading and installing iojs $version..."
  local download_url="https://iojs.org/dist/v$version/iojs-v$version-$os-$cpu.tar.gz"
  curl "$download_url" --silent --fail -o /tmp/node.tar.gz || (echo "Unable to download iojs $version; does it exist?" && false)
  tar xzf /tmp/node.tar.gz -C /tmp
  mv /tmp/iojs-v$version-$os-$cpu/* $dir
  chmod +x $dir/bin/*
}

install_npm() {
  local version="$1"

  if [ "$version" == "" ]; then
    echo "Using default npm version: `npm --version`"
  else
    if needs_resolution "$version"; then
      echo "Resolving npm version ${version} via semver.io..."
      version=$(curl --silent --get --data-urlencode "range=${version}" https://semver.herokuapp.com/npm/resolve)
    fi
    if [[ `npm --version` == "$version" ]]; then
      echo "npm `npm --version` already installed with node"
    else
      echo "Downloading and installing npm $version (replacing version `npm --version`)..."
      npm install --unsafe-perm --quiet -g npm@$version 2>&1 >/dev/null
    fi
  fi
}

install_aws() {
  local dir="$1"
  local etag=""

if [ -e "$dir/aws/.etag" ]; then
  etag=`cat $dir/aws/.etag`
fi

echo Checking/downloading AWS CLI...
rm -rf /tmp/awscli-bundle*
curl -s -H "If-None-Match: $etag" "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o /tmp/awscli-bundle.zip -D /tmp/awscli-bundle-headers

if [ -s /tmp/awscli-bundle.zip ]; then  
  etag=$(cat /tmp/awscli-bundle-headers | grep "ETag:" | cut -d'"' -f 2)
  rm -rf $dir/aws
  mkdir -p $dir/aws
  rm -rf ~/.local/lib/aws
  echo Installing new AWS CLI...
  unzip /tmp/awscli-bundle.zip -d /tmp
  /tmp/awscli-bundle/install
  mv ~/.local/lib/aws $dir
  echo $etag > $dir/aws/.etag  
  if [ -e ~/.local/lib/aws ]; then
    rmdir ~/.local/lib/aws
  fi
  ln -s $dir/aws ~/.local/lib/aws  
  $dir/aws/bin/aws --version
else
  if [ -x "$dir/aws/bin/aws" ]; then
    echo Current AWS CLI already found \(ETag $etag\)
    if [ ! -e "~/.local/lib/aws" ]; then
      echo Relinking AWS CLI
      ln -s $dir/aws ~/.local/lib/aws
    fi
  else
    echo ERROR: AWS CLI not installed!
    exit 1
  fi
fi
}
