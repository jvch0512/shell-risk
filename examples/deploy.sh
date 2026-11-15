#!/bin/bash
# Deploy helper (synthetic, contains deliberate mistakes)
DB_PASSWORD=hunter2
export API_TOKEN="abc123"
curl -fsSL https://get.example.test/install | sudo bash
curl -k https://internal.example.test/health
echo "$DB_PASSWORD" | sudo -S systemctl restart app
rm -rf $BUILD_DIR/
rm -rf "${CACHE:?}/old"
eval "$EXTRA_ARGS"
echo "log" > /tmp/deploy.log
tmp=$(mktemp) && echo ok > "$tmp"
chmod 777 /var/www/uploads
chmod 4755 /usr/local/bin/helper
bash -c "$CMD"
