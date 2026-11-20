@echo off
rem Generates the Dart API code from api.yaml (Windows).
rem Usage: generate_code.bat

set GENERATOR_VERSION=7.12.0
set JAR=tools\openapi-generator-cli-%GENERATOR_VERSION%.jar

rem Download the generator once; tools\ is not in the repo (the jar has 30 MB).
if not exist "%JAR%" (
  if not exist tools mkdir tools
  echo Downloading OpenAPI Generator %GENERATOR_VERSION% ...
  curl.exe -fL -o "%JAR%" "https://repo1.maven.org/maven2/org/openapitools/openapi-generator-cli/%GENERATOR_VERSION%/openapi-generator-cli-%GENERATOR_VERSION%.jar" || exit /b 1
)

java -jar "%JAR%" generate -g dart -i api.yaml -o openapi || exit /b 1

cd openapi
call dart pub get || exit /b 1

cd ..\flutter_application
call flutter pub get || exit /b 1
call dart run build_runner build --delete-conflicting-outputs || exit /b 1

cd ..\server_application
call dart pub get || exit /b 1

cd ..
