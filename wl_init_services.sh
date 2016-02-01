#!/bin/sh

# CLBJ - 2016- Shell script to check and kill weblogic processes
# Dependency: curl (ex: yum install curl, apt-get install curl)
# $1 weblogic install path
# $2 domain name
# $3 init node manager process
# $4 init admin server process

if ([ "$1" = "" ] || [ "$2" = "" ] || [ "$3" = "" ] || [ "$4" = "" ]); then
	echo "--------------------------------------"
	echo "ERROR: Missing arguments"
	echo "Usage: wl_init_services.sh wl_install_path (ex: /bea/weblogicTest) wl_domain_name (ex: domainTest) init_node_manager (START|STOP|RESTART|NONE) init_admin_server (START|STOP|RESTART|NONE)"
	echo "--------------------------------------"
	exit
fi

WL_INSTALL_PATH=${1}
WL_DOMAIN_NAME=${2}
INIT_NODE_MANAGER=$(echo ${3} | tr '[:lower:]' '[:upper:]')
INIT_ADMIN_SERVER=$(echo ${4} | tr '[:lower:]' '[:upper:]')
PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')
PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
PID_MANAGED_SERVER=$(ps -ef  | grep "wlserver/server -Dweblogic.management.server" | grep -v grep | awk '{print $2}')
SLEEP_TIME=3
OVERALL_STOP_STATUS=true
OVERALL_START_STATUS=true
WL_HTTP_STATUS_CODE=$(curl -I http://127.0.0.1:24500/console/login/LoginForm.jsp 2>/dev/null | head -n 1 | cut -d$' ' -f2)

function stopNodeManager() {
  local time_spent=0
  if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Node Manager process running with PID ${PID_NODE_MANAGER}"
    echo "Killing Weblogic Node Manager process ..."
    echo "---------------------------------------------------------------------"

    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopNodeManager.sh < /dev/null &> /dev/null &

    until [[ "${PID_NODE_MANAGER}" = "" ]]; do
      echo "Still stopping Weblogic Node Manager process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
    done

    if ([ "${PID_NODE_MANAGER}" = "" ]); then
      echo "Successfully stopped Weblogic Node Manager process"
    else
      kill -9 ${PID_NODE_MANAGER}
      sleep ${SLEEP_TIME}
      if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
        echo "Could not stop Weblogic Node Manager process running with PID ${PID_NODE_MANAGER} manual shutdown is needed!"
        OVERALL_STOP_STATUS=false
      fi
    fi
  else
    echo "Weblogic Node Manager process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

function startNodeManager() {
  local time_spent=0
  echo "-----------------------------------------------------------------------"
	echo "Checking state of Weblogic Node Manager process"
	echo "-----------------------------------------------------------------------"

  if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
    stopNodeManager
  fi

  echo "-----------------------------------------------------------------------"
  echo "Starting Weblogic Node Manager process in background ..."
  echo "-----------------------------------------------------------------------"

  . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/startNodeManager.sh < /dev/null &> /dev/null &

  while [[ "${PID_NODE_MANAGER}" = "" ]]; do
    echo "Still starting Weblogic Node Manager process in background ..."
    sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
    echo "Time spent so far to start process: ${time_spent} seconds"
    PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
  done
  echo "-----------------------------------------------------------------------"
  echo "Weblogic Node Manager process started successfully with PID ${PID_NODE_MANAGER}"
  echo "-----------------------------------------------------------------------"
}

function stopManagedServer() {
  local time_spent=0
  echo "-----------------------------------------------------------------------"
	echo "Checking state of Weblogic Managed Server process"
	echo "-----------------------------------------------------------------------"

  if ! ([ "${PID_MANAGED_SERVER}" = "" ]); then
    echo "Weblogic Node Managed Server running with PID ${PID_MANAGED_SERVER}"
    echo "Killing Weblogic Managed Server process ..."
    echo "---------------------------------------------------------------------"
    kill -9 ${PID_MANAGED_SERVER}

    until [[ "${PID_MANAGED_SERVER}" = "" ]]; do
      echo "Still stopping Weblogic Managed Server process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_MANAGED_SERVER=$(ps -ef  | grep "wlserver/server -Dweblogic.management.server" | grep -v grep | awk '{print $2}')
    done

    if ([ "${PID_MANAGED_SERVER}" = "" ]); then
      echo "Successfully stopped Weblogic Managed Server process"
    else
      echo "Could not stop Weblogic Managed Server process running with PID ${PID_MANAGED_SERVER} manual shutdown is needed!"
      OVERALL_STOP_STATUS=false
    fi
  else
    echo "Weblogic Managed Server process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

function stopAdminServer() {
  local time_spent=0
  if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Admin Server process running with PID ${PID_ADMIN_SERVER}"
    echo "Killing Weblogic Admin Server process ..."
    echo "---------------------------------------------------------------------"
    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopWebLogic.sh < /dev/null &> /dev/null &

    until [[ "${PID_ADMIN_SERVER}" = "" ]]; do
      echo "Stopping Weblogic Admin Server process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')
    done

    if ([ "${PID_ADMIN_SERVER}" = "" ]); then
      echo "Successfully stopped Weblogic Admin Server process"
    else
      kill -9 ${PID_ADMIN_SERVER}
      sleep ${SLEEP_TIME}
      if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
        echo "Could not stop Weblogic Admin Server process running with PID ${PID_ADMIN_SERVER} manual shutdown is needed!"
        OVERALL_STOP_STATUS=false
      fi
    fi
  else
    echo "Weblogic Admin Server process is NOT running"
  	echo "---------------------------------------------------------------------"
  fi
}

function startAdminServer() {
  local time_spent=0
  echo "-----------------------------------------------------------------------"
	echo "Checking state of Weblogic Admin Server process"
	echo "-----------------------------------------------------------------------"

  if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
    stopAdminServer
  fi

  echo "-----------------------------------------------------------------------"
  echo "Starting Weblogic Admin Server process in background ..."
  echo "-----------------------------------------------------------------------"

  . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/startWebLogic.sh < /dev/null &> /dev/null &

  while ([ "${PID_ADMIN_SERVER}" = "" ] || [ "${WL_HTTP_STATUS_CODE}" -ne 200 ]); do
    echo "Still starting Weblogic Admin Server process in background ..."
    sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
    echo "Time spent so far to start process: ${time_spent} seconds"
    PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')
  done

  while ! ([ "${WL_HTTP_STATUS_CODE}" = "200" ]); do
    echo "Waiting for Weblogic Admin Server console to be ready ..."
    sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
    echo "Time spent so far to start process: ${time_spent} seconds"
    WL_HTTP_STATUS_CODE=$(curl -I http://127.0.0.1:24500/console/login/LoginForm.jsp 2>/dev/null | head -n 1 | cut -d$' ' -f2)
  done

  echo "-----------------------------------------------------------------------"
  echo "Weblogic Admin Server process started successfully with PID ${PID_ADMIN_SERVER}"
  echo "-----------------------------------------------------------------------"
}

function init() {
  if ([ "${INIT_NODE_MANAGER}" = "STOP" ]); then
    stopNodeManager
    stopManagedServer
  elif ([ "${INIT_NODE_MANAGER}" = "START" ] || [ "${INIT_NODE_MANAGER}" = "RESTART" ]); then
    startNodeManager
  elif ([ "${INIT_NODE_MANAGER}" = "NONE" ]); then
    echo "---------------------------------------------------------------------"
    echo "INFO: No action for Node Manager process"
    echo "---------------------------------------------------------------------"
  else
    echo "---------------------------------------------------------------------"
    echo "ERROR: Invalid init parameter for Node Manager"
    echo "---------------------------------------------------------------------"
    exit
  fi

  if ([ "${INIT_ADMIN_SERVER}" = "STOP" ]); then
    stopAdminServer
  elif ([ "${INIT_ADMIN_SERVER}" = "START" ] || [ "${INIT_ADMIN_SERVER}" = "RESTART" ]); then
    startAdminServer
  elif ([ "${INIT_ADMIN_SERVER}" = "NONE" ]); then
    echo "---------------------------------------------------------------------"
    echo "INFO: No action for Admin Server process"
    echo "---------------------------------------------------------------------"
  else
    echo "---------------------------------------------------------------------"
    echo "ERROR: Invalid init parameter for Admin Server"
    echo "---------------------------------------------------------------------"
    exit
  fi

  if ! ([ ${OVERALL_STOP_STATUS} ]); then
    echo "---------------------------------------------------------------------"
    echo "ERROR: Could not executed some stopping tasks."
    echo "---------------------------------------------------------------------"
  fi

  if ! ([ ${OVERALL_START_STATUS} ]); then
    echo "---------------------------------------------------------------------"
    echo "ERROR: Could not executed some starting tasks."
    echo "---------------------------------------------------------------------"
  fi

  echo "-----------------------------------------------------------------------"
  echo "INFO: Finished executing script wl_init_services.sh ${1} ${2} ${3} ${4}"
  echo "-----------------------------------------------------------------------"
  exit 0
}

init
