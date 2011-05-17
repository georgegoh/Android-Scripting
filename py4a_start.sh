#!/bin/bash

# ADB
# The path to the Android Debugger program.
# By default, we use the one detected in the environment.
# This can be overridden below.
ADB=`which adb`
# FORWARDED_PORT
# SL4A RPC calls sent via FORWARDED_PORT on the localhost
# are forwarded to the SL4A server on the Android device.
FORWARDED_PORT=9999
# MAX_SERVER_RETRIES
# Max number of retries to detect the port number that
# the SL4A server is using on the Android device.
MAX_SERVER_RETRIES=3
SLEEP_TIME_BETWEEN_RETRIES=1

sanity_checks()
{
  if test -z "$ADB"
  then
    echo "The Android Debugger program (adb) was not found in your path."
    echo "Please check your Android SDK installation and your PATH envronment."
    exit 1
  fi

  PYTHON_SHELL=`which ipython`
  if test -z "$PYTHON_SHELL"
  then
    PYTHON_SHELL=`which python`
  fi

  if test -z "$PYTHON_SHELL"
  then
    echo "The Python interpreter was not found in your path."
    echo "Please check your installation and your PATH envronment."
    exit 1
  fi
}


start_private_server()
{
  echo "Starting Scripting Layer for Android(SL4A) private server."
  ${ADB} shell am start -a com.googlecode.android_scripting.action.LAUNCH_SERVER -n com.googlecode.android_scripting/.activity.ScriptingLayerServiceLauncher
  echo "Waiting for ${SLEEP_TIME_BETWEEN_RETRIES}s to let server settle."
  sleep ${SLEEP_TIME_BETWEEN_RETRIES}
}


get_private_server_port()
{
  # Android's netstat app seems to be crippled. It does not accept
  # standard netstat switches like -l and -p. A normal 'netstat -lp'
  # command would return the list of listening ports AND their
  # associated PIDs. Because Android's netstat doesn't return this
  # info, the code simply assumes that the SL4A server on the first
  # port that listens on localhost.
  # I'd welcome any suggestions for improvement here.
  SERVER_PORT=`${ADB} shell netstat | grep "127.0.0.1.*LISTEN" | awk -F "[ :]*" '{ print $6 }' | head -n 1`
  retries=0
  while test -z "$SERVER_PORT" && (( retries < $MAX_SERVER_RETRIES))
  do
    echo "Server port not detected. Sleeping for ${SLEEP_TIME_BETWEEN_RETRIES}s."
    sleep ${SLEEP_TIME_BETWEEN_RETRIES}
    (( retries += 1 ))
    echo "Retry ${retries} of ${MAX_SERVER_RETRIES}."
    SERVER_PORT=`${ADB} shell netstat | grep "127.0.0.1.*LISTEN" | awk -F "[ :]*" '{ print $6 }' | head -n 1`
  done

  if test -z "$SERVER_PORT"
  then
    echo "Server port not detected. Please check your SL4A installation."
    exit 1
  fi

  echo "Found server serving on port: ${SERVER_PORT}"
}


setup_remote_control_environment()
{
  echo "Forwarding to SL4A client requests to port: ${FORWARDED_PORT}"
  ${ADB} forward tcp:${FORWARDED_PORT} tcp:${SERVER_PORT}
  AP_PORT=${FORWARDED_PORT}
}


sanity_checks
start_private_server
get_private_server_port
setup_remote_control_environment
echo "Starting python interpreter..."
$PYTHON_SHELL
echo "Remember to stop the SL4A server on your Android device."
