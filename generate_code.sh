#!/bin/bash
# Generates the Dart API code from api.yaml (macOS/Linux and CI).
# Usage: ./generate_code.sh   (once: chmod +x generate_code.sh)
set -e

GENERATOR_VERSION=7.12.0
JAR=tools/openapi-generator-cli-$GENERATOR_VERSION.jar

# Download the generator once; tools/ is not in the repo (the jar has 30 MB).
if [ ! -f "$JAR" ]; then
  mkdir -p tools
  echo "Downloading OpenAPI Generator $GENERATOR_VERSION ..."
  curl -fL -o "$JAR" "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/$GENERATOR_VERSION/openapi-generator-cli-$GENERATOR_VERSION.jar"
fi

# Generate Dart code from api.yaml into openapi/
java -jar "$JAR" generate -g dart -i api.yaml -o openapi

(cd openapi && dart pub get)

# Client: fetch packages and generate the Mockito mocks for the tests
(cd flutter_application && flutter pub get && dart run build_runner build --delete-conflicting-outputs)

(cd server_application && dart pub get)
