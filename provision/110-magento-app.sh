#!/bin/bash

# ------------------------------------- #
# Fast VM - Magento2                    #
#                                       #
# Author: zepgram                       #
# Git: https://github.com/zepgram/      #
# ------------------------------------- #

export DEBIAN_FRONTEND=noninteractive

echo '--- Magento installation sequence ---'

# Prepare directory
DIRECTORY_BUILD="/srv"
if [ "$PROJECT_MOUNT_PATH" == "app" ]; then
	DIRECTORY_BUILD="/tmp"
fi
PROJECT_BUILD="$DIRECTORY_BUILD/$PROJECT_NAME"
rm -rf "$PROJECT_BUILD" &> /dev/null
chmod -R 777 /srv /tmp
mkdir -p "$PROJECT_BUILD"
chown -fR "$PROJECT_SETUP_OWNER":"$PROJECT_SETUP_OWNER" "$PROJECT_BUILD"

# Get installation files from source
if [ "$PROJECT_SOURCE" == "composer" ]; then
	# Install from magento
	sudo -u "$PROJECT_SETUP_OWNER" composer create-project --no-interaction --no-install --no-progress \
		--repository=https://repo.magento.com/ magento/project-"$PROJECT_EDITION"-edition="$PROJECT_VERSION" "$PROJECT_NAME" -d "$DIRECTORY_BUILD"
	# Install sample data
	if [ "$PROJECT_SAMPLE" == "true" ]; then
		sudo -u "$PROJECT_SETUP_OWNER" composer require -d "$PROJECT_BUILD" \
		magento/module-bundle-sample-data magento/module-widget-sample-data \
		magento/module-theme-sample-data magento/module-catalog-sample-data \
		magento/module-customer-sample-data magento/module-cms-sample-data \
		magento/module-catalog-rule-sample-data magento/module-sales-rule-sample-data \
		magento/module-review-sample-data magento/module-tax-sample-data \
		magento/module-sales-sample-data magento/module-grouped-product-sample-data \
		magento/module-downloadable-sample-data magento/module-msrp-sample-data \
		magento/module-configurable-sample-data magento/module-product-links-sample-data \
		magento/module-wishlist-sample-data magento/module-swatches-sample-data \
		magento/sample-data-media magento/module-offline-shipping-sample-data
	fi
else
	# Install from git
	sudo -u "$PROJECT_SETUP_OWNER" git clone "$PROJECT_REPOSITORY" "$PROJECT_BUILD"
	cd "$PROJECT_BUILD"; sudo -u "$PROJECT_SETUP_OWNER" git fetch --all; git checkout "$PROJECT_SOURCE" --force;
fi

# Composer install
sudo -u "$PROJECT_SETUP_OWNER" composer install -d "$PROJECT_BUILD" --no-progress --no-interaction --no-suggest

# Rsync directory
if [ "$PROJECT_BUILD" != "$PROJECT_PATH" ]; then
	rsync -a --remove-source-files "$PROJECT_BUILD"/ "$PROJECT_PATH"/ || true
fi

# Symlink
rm -rf /var/www/"$PROJECT_NAME"
ln -sfn /srv/"$PROJECT_NAME" /var/www/"$PROJECT_NAME"

# Apply basic rights on regular mount
if [ "$PROJECT_MOUNT" == "default" ] || [ "$PROJECT_MOUNT_PATH" == "app" ]; then
	chown -fR "$PROJECT_SETUP_OWNER":www-data "$PROJECT_PATH"
fi

# Run install
chmod +x "$PROJECT_PATH"/bin/magento
sudo -u "$PROJECT_SETUP_OWNER" "$PROJECT_PATH"/bin/magento setup:uninstall -n -q
sudo -u "$PROJECT_SETUP_OWNER" "$PROJECT_PATH"/bin/magento setup:install \
--base-url="http://${PROJECT_URL}/" \
--base-url-secure="https://${PROJECT_URL}/" \
--db-host="localhost"  \
--db-name="${PROJECT_NAME}" \
--db-user="vagrant" \
--db-password="vagrant" \
--admin-firstname="admin" \
--admin-lastname="admin" \
--admin-email="${PROJECT_GIT_EMAIL}" \
--admin-user="admin" \
--admin-password="admin123" \
--language="${PROJECT_LANGUAGE}" \
--currency="${PROJECT_CURRENCY}" \
--timezone="${PROJECT_TIME_ZONE}" \
--use-rewrites="1" \
--backend-frontname="admin"
