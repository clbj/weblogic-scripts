#!/bin/sh

# CLBJ - 2016- Shell script to check and kill weblogic processes
# Dependency: netstat
# https://github.com/clbj/weblogic-scripts
# $1 weblogic install path
# $2 domain name
# $3 Weblogic Node Manager port ex: 5556
# $4 init mode for Node Manager (STOP|START|RESTART|NONE)
# $5 Weblogic Admin server port ex: 7001
# $6 init mode for Admin Server (STOP|START|RESTART|NONE)

if ([ "$1" = "" ] || [ "$2" = "" ] || [ "$3" = "" ] || [ "$4" = "" ] || [ "$5" = "" ] || [ "$6" = "" ]); then
	echo "------------------------------------------------------------------------"
	echo "ERROR: Missing arguments"
	echo "Usage: wl_init_services.sh wl_install_path (ex: /bea/weblogicTest) "
	echo "			 domain_name (ex: domainTest) node_manager_port (ex: 5556) admin_server (ex: 7001)"
	echo "			 node_manager_mode (START|STOP|RESTART|NONE) admin_server_mode (START|STOP|RESTART|NONE)"
	echo "-----------------------------------------------------------------------"
	exit
fi

SLEEP_TIME=3
LONG_TIME=240
WL_INSTALL_PATH=${1}
WL_DOMAIN_NAME=${2}
NODE_MANAGER_PORT=${3}
NODE_MANAGER_MODE=$(echo ${4} | tr '[:lower:]' '[:upper:]')
ADMIN_SERVER_PORT=${5}
ADMIN_SERVER_MODE=$(echo ${6} | tr '[:lower:]' '[:upper:]')
PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')
PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
PID_MANAGED_SERVER=$(ps -ef  | grep "wlserver/server -Dweblogic.management.server" | grep -v grep | awk '{print $2}')
OVERALL_STOP_STATUS=true
OVERALL_START_STATUS=true
NETSTAT_ADMIN_SERVER=$(netstat -ln | grep :"$ADMIN_SERVER_PORT" | grep 'LISTEN')
NETSTAT_NODE_MANAGER=$(netstat -ln | grep :"$NODE_MANAGER_PORT" | grep 'LISTEN')

stopNodeManager() {
  local time_spent=0
  if ! ([ "${PID_NODE_MANAGER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Node Manager process running with PID ${PID_NODE_MANAGER}"
    echo "Killing Weblogic Node Manager process ..."
    echo "---------------------------------------------------------------------"

    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopNodeManager.sh < /dev/null &> /dev/null &

    until ([ "${PID_NODE_MANAGER}" = "" ]); do
      echo "Still stopping Weblogic Node Manager process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
    done

    if ([ "${PID_NODE_MANAGER}" = "" ]); then
      echo "Successfully stopped Weblogic Node Manager process"
    else
      kill -9 "${PID_NODE_MANAGER}"
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

startNodeManager() {
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

  while ([ "${PID_NODE_MANAGER}" = "" ]); do
    echo "Still starting Weblogic Node Manager process in background ..."
    sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
    echo "Time spent so far to start process: ${time_spent} seconds"
    PID_NODE_MANAGER=$(ps -ef  | grep "weblogic.NodeManager" | grep -v grep | awk '{print $2}')
  done

	while ([ "${NETSTAT_NODE_MANAGER}" = "" ]); do
		echo "Wating for Weblogic Node Manager service to be avaliable ..."
		local netstat_node_manager_5556=$(netstat -ln | grep ':5556' | grep 'LISTEN')
		local netstat_node_manager_12556=$(netstat -ln | grep ':12556' | grep 'LISTEN')

		if ! ([ "${netstat_node_manager_5556}" = "" ]); then
			echo "INFO: Weblogic Node Manager seems to be running at port 5556"
			NETSTAT_NODE_MANAGER=netstat_node_manager_5556
		elif ! ([ "${netstat_node_manager_12556}" = "" ]); then
			echo "INFO: Weblogic Node Manager seems to be running at port 12556"
			NETSTAT_NODE_MANAGER=netstat_node_manager_12556
		else
			NETSTAT_NODE_MANAGER=$(netstat -ln | grep :"$NODE_MANAGER_PORT" | grep 'LISTEN')
		fi
		sleep ${SLEEP_TIME}
    time_spent=$(( time_spent + ${SLEEP_TIME} ))
		echo "Time spent so far to start process: ${time_spent} seconds"
	done

  echo "-----------------------------------------------------------------------"
  echo "Weblogic Node Manager process started successfully with PID ${PID_NODE_MANAGER}"
  echo "-----------------------------------------------------------------------"
}

stopManagedServer() {
  local time_spent=0
  echo "-----------------------------------------------------------------------"
	echo "Checking state of Weblogic Managed Server process"
	echo "-----------------------------------------------------------------------"

  if ! ([ "${PID_MANAGED_SERVER}" = "" ]); then
    echo "Weblogic Node Managed Server running with PID ${PID_MANAGED_SERVER}"
    echo "Killing Weblogic Managed Server process ..."
    echo "---------------------------------------------------------------------"
    kill -9 "${PID_MANAGED_SERVER}"

    until ([ "${PID_MANAGED_SERVER}" = "" ]); do
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

stopAdminServer() {
  local time_spent=0
  if ! ([ "${PID_ADMIN_SERVER}" = "" ]); then
    echo "---------------------------------------------------------------------"
    echo "Weblogic Admin Server process running with PID ${PID_ADMIN_SERVER}"
    echo "Killing Weblogic Admin Server process ..."
    echo "---------------------------------------------------------------------"
    . /${WL_INSTALL_PATH}/user_projects/domains/${WL_DOMAIN_NAME}/bin/stopWebLogic.sh < /dev/null &> /dev/null &

    until ([ "${PID_ADMIN_SERVER}" = "" ]); do
      echo "Stopping Weblogic Admin Server process ..."
      sleep ${SLEEP_TIME}
      time_spent=$(( time_spent + ${SLEEP_TIME} ))
      echo "Time spent so far to stop process: ${time_spent} seconds"
      PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')
    done

    if ([ "${PID_ADMIN_SERVER}" = "" ]); then
      echo "Successfully stopped Weblogic Admin Server process"
    else
      kill -9 "${PID_ADMIN_SERVER}"
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

startAdminServer() {
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

	while ([ "${PID_ADMIN_SERVER}" = "" ]); do
	  echo "Still starting Weblogic Admin Server process in background ..."
	  sleep ${SLEEP_TIME}
	  time_spent=$(( time_spent + ${SLEEP_TIME} ))
	  echo "Time spent so far to start process: ${time_spent} seconds"
	  PID_ADMIN_SERVER=$(ps -ef | grep "weblogic.Name=AdminServer -Djava.security.policy=${WL_INSTALL_PATH}" | grep -v grep|awk '{print $2}')

		if ( time_spent > ${LONG_TIME} ); then
			echo "WARNING: Operation is taking too much to finish. Check Node Manager port parameter value."
			echo "Check Node Manager port parameter value."
		fi
	done

	while ([ "${NETSTAT_ADMIN_SERVER}" = "" ]); do
		echo "Waiting for Weblogic Admin Server service to be avaliable ..."
		local netstat_admin_server_7001=$(netstat -ln | grep ':7001' | grep 'LISTEN')

		if ! ([ "${netstat_admin_server_7001}" = "" ]); then
			echo "INFO: Weblogic Admin Server seems to be running at port 7001"
			NETSTAT_ADMIN_SERVER=netstat_admin_server_7001
		else
			NETSTAT_ADMIN_SERVER=$(netstat -ln | grep :"$ADMIN_SERVER_PORT" | grep 'LISTEN')
		fi
		sleep ${SLEEP_TIME}
		time_spent=$(( time_spent + ${SLEEP_TIME} ))
		echo "Time spent so far to start process: ${time_spent} seconds"
	done

  echo "-----------------------------------------------------------------------"
  echo "Weblogic Admin Server process started successfully with PID ${PID_ADMIN_SERVER}"
  echo "-----------------------------------------------------------------------"
}

init() {
  if ([ "${NODE_MANAGER_MODE}" = "STOP" ]); then
    stopNodeManager
    stopManagedServer
  elif ([ "${NODE_MANAGER_MODE}" = "START" ] || [ "${NODE_MANAGER_MODE}" = "RESTART" ]); then
		startNodeManager
	elif ([ "${NODE_MANAGER_MODE}" = "RESTART" ]); then
		# if is also requested an AdminServer stop is a good idea to stop it first
  	if ([ "${ADMIN_SERVER_MODE}" = "RESTART" ]); then
  		stopAdminServer
  	fi
		startNodeManager
  elif ([ "${NODE_MANAGER_MODE}" = "NONE" ]); then
    echo "---------------------------------------------------------------------"
    echo "INFO: No action for Node Manager process"
    echo "---------------------------------------------------------------------"
  else
    echo "---------------------------------------------------------------------"
    echo "ERROR: Invalid init parameter for Node Manager"
    echo "---------------------------------------------------------------------"
    exit
  fi

  if ([ "${ADMIN_SERVER_MODE}" = "STOP" ]); then
    stopAdminServer
  elif ([ "${ADMIN_SERVER_MODE}" = "START" ] || [ "${ADMIN_SERVER_MODE}" = "RESTART" ]); then
    startAdminServer
  elif ([ "${ADMIN_SERVER_MODE}" = "NONE" ]); then
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
  echo "INFO: Finished executing script wl_init_services.sh ${1} ${2} ${3} ${4} ${5} ${6}"
  echo "-----------------------------------------------------------------------"
  exit 0
}

init
