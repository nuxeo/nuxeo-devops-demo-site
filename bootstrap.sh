#!/bin/bash

REPO="https://github.com/nuxeo/nuxeo-devops-demo-site.git"
BRANCH="master"
DOCKER_PRIVATE="docker-private.packages.nuxeo.com"
NUXEO_IMAGE="${DOCKER_PRIVATE}/nuxeo/nuxeo:2023"
demo_dir="/opt/demo-docker/static"
NUXEO_CLID=$2
NUXEO_ENV=$1

MONGO_VERSION="6.0"
OPENSEARCH_VERSION="1.3.11"

OPENSEARCH_IMAGE="opensearchproject/opensearch:"${OPENSEARCH_VERSION}
OPENSEARCH_DASHBOARDS_IMAGE="opensearchproject/opensearch-dashboards:"${OPENSEARCH_VERSION}

CHECKS=()
# Check for commands used in this script
command -v awk >/dev/null || CHECKS+=("awk")
command -v make >/dev/null || CHECKS+=("make")
command -v envsubst >/dev/null || CHECKS+=("envsubst")
command -v git >/dev/null || CHECKS+=("git")
command -v docker >/dev/null || CHECKS+=("docker")

if [ $CHECKS ]
then
  echo "Please install the following programs for your platform:"
  echo ${CHECKS[@]}
  exit 1
fi

docker info >/dev/null
RUNNING=$?
if [ "${RUNNING}" != "0" ]
then
  echo "Docker does not appear to be running, please start Docker."
  exit 2
fi
FQDN="localhost"

IMAGE_TYPE="LTS"

# Create project folder
echo ""
echo "Cloning configuration: ${PWD}/${demo_dir}"

  git clone ${REPO} $demo_dir

mkdir -p ${demo_dir}/conf
cp ${demo_dir}/conf.d/*.conf ${demo_dir}/conf
echo ""

# Write system configuration
cat << EOF > ${demo_dir}/conf/system.conf
# Host Configuration
session.timeout=600
nuxeo.url=http://${FQDN}:8080/nuxeo

# WebUI
# Enable "select all" by default
nuxeo.selection.selectAllEnabled=true
# Fix WEBUI-976
nuxeo.analytics.documentDistribution.disableThreshold=10000

# Templates
nuxeo.templates=default,mongodb
# Enable CORS
nuxeo.cors.urls=*

# Workaround for NXP-32023
JAVA_OPTS=$JAVA_OPTS -Djdk.util.zip.disableZip64ExtraFieldValidation=true
EOF

# Make sure we always have a UI installed
AUTO_PACKAGES="nuxeo-web-ui"
# Auto install Nuxeo Explorer because the website is unusable
# TODO: Uncomment when platform-explorer is actually available for LTS 2023...
AUTO_PACKAGES="${AUTO_PACKAGES} nuxeo-showcase-content"

# Write environment file
cat << EOF > ${demo_dir}/.env
#APPLICATION_NAME=${NX_STUDIO}
#PROJECT_NAME=${PROJECT_NAME}

NUXEO_IMAGE=${NUXEO_IMAGE}

CONNECT_URL=https://connect.nuxeo.com/nuxeo/site/

#NUXEO_DEV=true
NUXEO_PORT=8080
NUXEO_PACKAGES=${STUDIO_PACKAGE} ${AUTO_PACKAGES}

#INSTALL_RPM=${INSTALL_RPM}
NUXEO_ENV=${NUXEO_ENV}
MONGO_VERSION=${MONGO_VERSION}
OPENSEARCH_IMAGE=${OPENSEARCH_IMAGE}
OPENSEARCH_DASHBOARDS_IMAGE=${OPENSEARCH_DASHBOARDS_IMAGE}

FQDN=${FQDN}
NUXEO_CLID=${NUXEO_CLID}
EOF


cd ${demo_dir}
echo "Please wait, getting things ready..."
docker pull --quiet ${NUXEO_IMAGE}
echo " pulling other services..."
docker compose pull
echo ""

# Build image (may use CLID generated in previous step)
echo "Building your custom image(s)..."
docker compose build
echo ""
# Pull images
echo "Please wait, getting things ready..."
docker compose up -d
