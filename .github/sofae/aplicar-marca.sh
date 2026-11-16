#!/usr/bin/env bash
# Aplica a marca Sofae em lib/core/app_config.dart, com os mesmos sed do build_apk.yml.
# Usado pelos jobs do sofae-windows.yml (Windows e APK de teste). Os valores vêm do env do workflow.
set -euo pipefail

to_int() { echo "0xFF$(echo "$1" | sed 's/#//' | tr 'a-f' 'A-F')"; }
F=lib/core/app_config.dart
sed -i "s/static const String appName = .*/static const String appName = '${APP_NAME}';/" $F
sed -i "s/static const String appSubtitle = .*/static const String appSubtitle = '${APP_SUBTITLE}';/" $F
sed -i "s/static const int primaryColor = .*/static const int primaryColor = $(to_int "$PRIMARY_COLOR");/" $F
sed -i "s/static const int backgroundColor = .*/static const int backgroundColor = $(to_int "$BACKGROUND_COLOR");/" $F
sed -i "s/static const int surfaceColor = .*/static const int surfaceColor = $(to_int "$SURFACE_COLOR");/" $F
sed -i "s/static const bool useCustomLogo = .*/static const bool useCustomLogo = true;/" $F
sed -i "s/static const int appTheme = .*/static const int appTheme = ${APP_THEME};/" $F
sed -i "s|static const String bannerUrl = .*|static const String bannerUrl = '${BANNER_URL}';|" $F
sed -i "s|static const String logoUrl = .*|static const String logoUrl = '${LOGO_URL}';|" $F
sed -i "s/static const int buildNumber = .*/static const int buildNumber = ${BUILD_NUMBER};/" $F
sed -i "s/static const String resellerUsername = .*/static const String resellerUsername = '${RESELLER_USERNAME}';/" $F
cat $F
