#!/bin/bash

[ "$DEBUG" = "true" ] && set -x

# If asked, we'll ensure that the www is set to the same uid/gid as the
# mounted volume.  This works around permission issues with virtualbox shared
# folders.
if [[ "$UPDATE_UID_GID" = "true" ]]; then
    echo "Updating www uid and gid"

    DOCKER_UID=`stat -c "%u" $MAGENTO_ROOT`
    DOCKER_GID=`stat -c "%g" $MAGENTO_ROOT`

    INCUMBENT_USER=`getent passwd $DOCKER_UID | cut -d: -f1`
    INCUMBENT_GROUP=`getent group $DOCKER_GID | cut -d: -f1`

    echo "Docker: uid = $DOCKER_UID, gid = $DOCKER_GID"
    echo "Incumbent: user = $INCUMBENT_USER, group = $INCUMBENT_GROUP"

    # Once we've established the ids and incumbent ids then we need to free them
    # up (if necessary) and then make the change to www.

    [ ! -z "${INCUMBENT_USER}" ] && usermod -u 99$DOCKER_UID $INCUMBENT_USER
    usermod -u $DOCKER_UID www

    [ ! -z "${INCUMBENT_GROUP}" ] && groupmod -g 99$DOCKER_GID $INCUMBENT_GROUP
    groupmod -g $DOCKER_GID www
fi

# Ensure our Magento directory exists
mkdir -p $MAGENTO_ROOT

# Configure Sendmail if required
if [ "$ENABLE_SENDMAIL" == "true" ]; then
    /etc/init.d/sendmail start
fi

# Enable PHP extensions
PHP_EXT_DIR=/usr/local/etc/php/conf.d
PHP_EXT_COM_ON=docker-php-ext-enable

[ -d ${PHP_EXT_DIR} ] && rm -f ${PHP_EXT_DIR}/docker-php-ext-*.ini

if [ -x "$(command -v ${PHP_EXT_COM_ON})" ] && [ ! -z "${PHP_EXTENSIONS}" ]; then
      ${PHP_EXT_COM_ON} ${PHP_EXTENSIONS}
fi

# Substitute in php.ini values
[ ! -z "${PHP_MEMORY_LIMIT}" ] && sed -i "s/!PHP_MEMORY_LIMIT!/${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/zz-magento.ini
[ ! -z "${UPLOAD_MAX_FILESIZE}" ] && sed -i "s/!UPLOAD_MAX_FILESIZE!/${UPLOAD_MAX_FILESIZE}/" /usr/local/etc/php/conf.d/zz-magento.ini

# Configure PHP-FPM
[ ! -z "${MAGENTO_RUN_MODE}" ] && sed -i "s/!MAGENTO_RUN_MODE!/${MAGENTO_RUN_MODE}/" /usr/local/etc/php-fpm.conf

chown -R www:www $MAGENTO_ROOT > /dev/null 2>&1

exec "$@"
