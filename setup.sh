echo "CROWDFUNDING SETUP SCRIPT"

echo "[*] INSERT HOSTNAME (e.g crowdfund.particl.io)"
read HOSTNAME
HOSTNAME=${HOSTNAME:-localhost}

echo "[*] INSERT FRONT REPO URL (e.g https://github.com/particl/ccs-front)"
read FRONT_REPO_URL
FRONT_REPO_URL=${FRONT_REPO_URL:-https://github.com/kewde/ccs-front}
echo "$FRONT_REPO_URL"
# Check if the directory exist, else clone it.
D=./data/nginx/ccs-front
if [ -f "$D" ]; then
    echo "$D already exists, aborting."
    exit
else 
   echo "[*] CLONING FRONTEND REPO"
   git clone "$FRONT_REPO_URL" "$D"
fi

echo "[*] INSERT BACK REPO URL (e.g https://github.com/particl/ccs-back)"
read BACK_REPO_URL
BACK_REPO_URL=${BACK_REPO_URL:-https://github.com/kewde/ccs-back}
# Check if the directory exist, else clone it.
D=./data/nginx/ccs-back
if [ -f "$D" ]; then
    echo "$D already exists, aborting."
    exit
else 
   echo "[*] CLONING BACKEND REPO"
   git clone "$BACK_REPO_URL" "$D"
fi


echo "[*] INSERT PROPOSALS REPO URL (e.g https://github.com/particl/ccs-proposals)"
read PROP_REPO_URL
PROP_REPO_URL=${PROP_REPO_URL:-https://github.com/kewde/ccs-proposals}
# Check if the directory exist, else clone it.
D=./data/nginx/ccs-back/storage/app/proposals
if [ -f "$D" ]; then
    echo "$D already exists, aborting."
    exit
else 
   echo "[*] CLONING PROPOSAL REPO"
   git clone "$PROP_REPO_URL" "$D"
fi

echo "[*] INSERT GITHUB ACCESS TOKEN (retrieve public_repo token from GitHub)"
read GITHUB_ACCESS_TOKEN
GITHUB_ACCESS_TOKEN=${GITHUB_ACCESS_TOKEN:-SECRET}

echo "[*] GENERATE SECRETS"
echo "      [*] GENERATING MYSQL ROOT PASSWORD"
MYSQL_ROOT_PASSWORD=$(tr -dc '[:alnum:]' < /dev/urandom | head -c20)
echo "          MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}"

echo "      [*] GENERATING MYSQL USER PASSWORD"
MYSQL_USER_PASSWORD=$(tr -dc '[:alnum:]' < /dev/urandom | head -c20)
echo "          MYSQL_USER_PASSWORD=${MYSQL_USER_PASSWORD}"

echo "      [*] GENERATING PARTICLD USER PASSWORD"
PARTICLD_USER_PASSWORD=$(tr -dc '[:alnum:]' < /dev/urandom | head -c20)
echo "          PARTICLD_USER_PASSWORD=${PARTICLD_USER_PASSWORD}"

echo "[*] GENERATING CCS.ENV FILE"
cat >./ccs.env <<EOL
APP_URL=http://${HOSTNAME}

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=crowdfund
DB_USERNAME=crowdfunduser
DB_PASSWORD=${MYSQL_USER_PASSWORD}

RPC_URL=http://watcher-particl-core:51935/
RPC_USER=crowdfunduser
RPC_PASSWORD=${PARTICLD_USER_PASSWORD}

COIN=particl

REPOSITORY_URL=${PROP_REPO_URL}
GITHUB_ACCESS_TOKEN=${GITHUB_ACCESS_TOKEN}
EOL


echo "[*] GENERATING MYSQL.ENV FILE"
cat >./mysql.env <<EOL
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=crowdfund
MYSQL_USER=crowdfunduser
MYSQL_PASSWORD=${MYSQL_USER_PASSWORD}
EOL

echo "[*] GENERATING NGINX FILE"
cat >./ccs.nginx <<EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html/ccs-front/_site/;
    index index.php index.html;
    server_name ${HOSTNAME};

    location / {
        try_files \$uri \$uri/ /index.php?$query_string;
    }

    # pass the PHP scripts to FastCGI server
    #

    location ~ \.php$ {
        root /var/www/html/ccs-back/public/;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock; # change to correct version
    }
}
EOL

echo "[*] GENERATING PARTICLD CONF FILE"
cat >./data/particld/particl.conf <<EOL
testnet=1
[test]
rpcuser=crowdfunduser
rpcpassword=${PARTICLD_USER_PASSWORD}
rpcbind=0.0.0.0
rpcallowip=::/0
rpcport=51935
printtoconsole=1
EOL

echo "MANUAL: place wallet file in ./data/particld and hit enter"
read WALLET_ENTERED
FILE=./data/particld/testnet/wallet.dat
if [ -f "$FILE" ]; then
    echo "$FILE exists."
else 
    echo "$FILE does not exist. Exiting."
    exit 
fi

touch data/nginx/ccs-back/storage/app/complete.json
touch data/nginx/ccs-back/storage/app/proposals.json
echo "[*] DONE!"