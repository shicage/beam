#!/bin/bash
#
#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

# Generates requirements files, which list PyPI dependencies to install in
# Apache Beam Python SDK container images. To generate the list,
# we use two sources of information:
# 1) Requirements of Apache Beam itself, as defined by setup.py.
# 2) A list of dependencies from base_image_requirements_manual.txt, which we
# maintain manually.

# It is recommended to run this script via gradle commands such as:
# ./gradlew :sdks:python:container:generatePythonRequirementsAll
# ./gradlew :sdks:python:container:py38:generatePythonRequirements

# You will need Python interpreters for all versions supported by Beam, see:
# https://s.apache.org/beam-python-dev-wiki

if [[ $# -lt 2 ]]; then
  printf "Example usage: \n$> ./sdks/python/container/run_generate_requirements.sh 3.8 <sdk_tarball>"
  printf "\n\where 3.8 is the Python major.minor version."
  exit 1
fi

PY_VERSION=$1
SDK_TARBALL=$2
REQUIREMENTS_FILE_NAME=$3
EXTRAS=$4
# Use the PIP_EXTRA_OPTIONS environment variable to pass additional flags to the pip install command.
# For example, you can include the --pre flag in $PIP_EXTRA_OPTIONS to download pre-release versions of packages.
# Note that you can modify the behavior of the pip install command in this script by passing in your own $PIP_EXTRA_OPTIONS.
PIP_EXTRA_OPTIONS=$5

if ! python"$PY_VERSION" --version > /dev/null 2>&1 ; then
  echo "Please install a python${PY_VERSION} interpreter. See s.apache.org/beam-python-dev-wiki for Python installation tips."
  exit 1
fi

if ! python"$PY_VERSION" -m venv --help > /dev/null 2>&1 ; then
  echo "Your python${PY_VERSION} installation does not have a required venv module. See s.apache.org/beam-python-dev-wiki for Python installation tips."
  exit 1
fi

if [ -z "$REQUIREMENTS_FILE_NAME" ]; then
  REQUIREMENTS_FILE_NAME="base_image_requirements.txt"
fi

if [ -z "$EXTRAS" ]; then
  EXTRAS="[gcp,dataframe,test]"
fi

set -ex

ENV_PATH="$PWD/build/python${PY_VERSION/./}_requirements_gen"
rm -rf "$ENV_PATH" 2>/dev/null || true
python"${PY_VERSION}" -m venv "$ENV_PATH"
source "$ENV_PATH"/bin/activate
pip install --upgrade pip setuptools wheel

# Install gcp extra deps since these deps are commonly used with Apache Beam.
# Install dataframe deps to add have Dataframe support in released images.
# Install test deps since some integration tests need dependencies,
# such as pytest, installed in the runner environment.
pip install ${PIP_EXTRA_OPTIONS:+"$PIP_EXTRA_OPTIONS"}  --no-cache-dir "$SDK_TARBALL""$EXTRAS"
pip install ${PIP_EXTRA_OPTIONS:+"$PIP_EXTRA_OPTIONS"}  --no-cache-dir -r "$PWD"/sdks/python/container/base_image_requirements_manual.txt

pip uninstall -y apache-beam
echo "Checking for broken dependencies:"
pip check
echo "Installed dependencies:"
pip freeze --all

PY_IMAGE="py${PY_VERSION//.}"
REQUIREMENTS_FILE=$PWD/sdks/python/container/$PY_IMAGE/$REQUIREMENTS_FILE_NAME
cat <<EOT > "$REQUIREMENTS_FILE"
#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Autogenerated requirements file for Apache Beam $PY_IMAGE container image.
# Run ./gradlew :sdks:python:container:generatePythonRequirementsAll to update.
# Do not edit manually, adjust ../base_image_requirements_manual.txt or
# Apache Beam's setup.py instead, and regenerate the list.
# You will need Python interpreters for all versions supported by Beam, see:
# https://s.apache.org/beam-python-dev-wiki
# Reach out to a committer if you need help.

EOT
# Remove pkg_resources to guard against
# https://stackoverflow.com/questions/39577984/what-is-pkg-resources-0-0-0-in-output-of-pip-freeze-command
pip freeze --all | grep -v pkg_resources >> "$REQUIREMENTS_FILE"

if grep -q "tensorflow==" "$REQUIREMENTS_FILE"; then
  # Get the version of tensorflow from the .txt file.
  TF_VERSION=$(grep -Po "tensorflow==\K[^;]+" "$REQUIREMENTS_FILE")
  TF_ENTRY="tensorflow==${TF_VERSION}"
  TF_AARCH64_ENTRY="tensorflow-cpu-aws==${TF_VERSION};platform_machine==\"aarch64\""
  sed -i "s/${TF_ENTRY}/${TF_ENTRY}\n${TF_AARCH64_ENTRY}/g" $REQUIREMENTS_FILE
fi

rm -rf "$ENV_PATH"
