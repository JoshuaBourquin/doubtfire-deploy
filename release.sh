#!/bin/sh

# Check for standard-version
if ! command -v standard-version &> /dev/null
then
  echo "standard-version could not be found, install it via npm i -g standard-version"
  exit
fi

APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`

cd "${APP_PATH}"

echo "## Generate Release Notes and Push to Release Branch"

echo
echo "### Step 1: Build"
echo

cd "${APP_PATH}"
"${APP_PATH}/build.sh"

if [ $? -ne 0 ]; then
  echo "Ensure that everything builds";
  exit 1
fi

echo
echo "### Step 2. Update version tags"
echo 

echo "Doubtfire is at version `git describe --abbrev=0 --tags`"

select answer in "Full" "Prerelease"; do
  case $answer in
    Full)
      break;
      ;;
    Prerelease)
      PRERELEASE="--prerelease"
      break;
      ;;
  esac
done

SKIP=0

select answer in "Skip" "Auto" "Major" "Minor" "Patch"; do
  case $answer in
    Skip)
      SKIP=1
      break;
      ;;
    Auto)
      RELEASE_AS=
      break;
      ;;
    Major)
      RELEASE_AS="--release-as major"
      break;
      ;;
    Minor)
      RELEASE_AS="--release-as minor"
      break;
      ;;
    Patch)
      RELEASE_AS="--release-as patch"
      break;
      ;;
  esac
done

  function prepare_release {
    PROJECT=$1
    PROJECT_PATH=$2

    cd "${PROJECT_PATH}"
    standard-version $RELEASE_AS $PRERELEASE

    CURRENT_BRANCH=$(git branch --show-current)
    RELEASE_VERSION=`git describe --abbrev=0 --tags`

    while [ ${CURRENT_BRANCH%.x} != ${${RELEASE_VERSION#v}%.*} ]; do
      echo "$PROJECT does not match release branch naming: $CURRENT_BRANCH != $RELEASE_VERSION"
      read -p "Fix then press enter to continue (or break to quit)"

      CURRENT_BRANCH=$(git branch --show-current)
      RELEASE_VERSION=`git describe --abbrev=0 --tags`
    done
    echo
  }

  prepare_release 'doubtfire-web' "${APP_PATH}/doubtfire-web"
  WEB_VERSION=$(git describe --abbrev=0 --tags)

  prepare_release 'doubtfire-api' "${APP_PATH}/doubtfire-api"
  API_VERSION=$(git describe --abbrev=0 --tags)

  prepare_release 'doubtfire-overseer' "${APP_PATH}/doubtfire-overseer"
  OVERSEER_VERSION=$(git describe --abbrev=0 --tags)

  echo
  echo "### Step 3: Prepare deploy for release"
  echo

  cd "${APP_PATH}/releases"
  DATE_WITH_TIME=`date "+%Y-%m%d-%H%M"`
  mkdir $DATE_WITH_TIME
  echo "$API_VERSION" > "${DATE_WITH_TIME}/.apiversion"
  echo "$WEB_VERSION" > "${DATE_WITH_TIME}/.webversion"
  echo "$OVERSEER_VERSION" > "${DATE_WITH_TIME}/.overseer"
  cp -r ./release-template/. ./${DATE_WITH_TIME}
  echo "https://github.com/doubtfire-lms/doubtfire-web/blob/${WEB_VERSION}/CHANGELOG.md" > ${DATE_WITH_TIME}/WEB_CHANGELOG.md
  echo "https://github.com/doubtfire-lms/doubtfire-api/blob/${API_VERSION}/CHANGELOG.md" > ${DATE_WITH_TIME}/API_CHANGELOG.md
  echo "https://github.com/doubtfire-lms/doubtfire-api/blob/${OVERSEER_VERSION}/CHANGELOG.md" > ${DATE_WITH_TIME}/OVERSEER_CHANGELOG.md

  echo
  echo "Please update release notes, and push them to origin before continuing here..."

  prepare_release 'doubtfire-deploy' "${APP_PATH}"
  DEPLOY_VERSION=$(git describe --abbrev=0 --tags)
done

echo
echo "### Step 4: Push releases"
echo

echo "What's the name of the remote to push to (doubtfire-lms)"
read -p "Remote: (eg origin/upstream): " REMOTE

function push_release {
  PROJECT=$1
  PROJECT_PATH=$2

  cd "${PROJECT_PATH}"
  CURRENT_BRANCH=$(git branch --show-current)
  git push --follow-tags $REMOTE ${CURRENT_BRANCH}:releases
  if [ $? -ne 0 ]; then
    echo "Oh no... fix up this mess please";
    exit 1
  fi
}

echo "Push new releases to GitHub?"
select answer in "Skip" "Push"; do
  case $answer in
    Skip)
      echo "Not pushing releases"
      break;
      ;;
    Push)
      push_release 'doubtfire-web' "${APP_PATH}/doubtfire-web"
      push_release 'doubtfire-api' "${APP_PATH}/doubtfire-api"
      push_release 'doubtfire-overseer' "${APP_PATH}/doubtfire-overseer"
      push_release 'doubtfire-deploy' "${APP_PATH}"
      break;
      ;;
  esac
done

