#!/bin/bash

#Colors

RED="\e[31m"
GREEN="\e[32m"
BOLDGREEN="\e[1;${GREEN}m"
MAGENTA="\e[35m"
ENDCOLOR="\e[0m"

# Attempt variables 
USER_CUSTOM_ATTEMPT=$1
CONN_ATTEMPT="${USER_CUSTOM_ATTEMPT:=1}"

function build_env_vars {

    BASE_DOMAIN=$(oc get dns/cluster -ojson | jq -r .spec.baseDomain)
    API=api.$BASE_DOMAIN
    API_INT=api-int.$BASE_DOMAIN
    INGRESS_URL="*.apps."$BASE_DOMAIN
    ROUTERS_IPS=$(oc get pod -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -o=jsonpath="{.items[*]['status.podIP']}")
    DNS_UPSTREAMS_INCLUSTER=$(for POD in $(oc get pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default --no-headers | awk '{print $1}'); do oc exec -n openshift-dns -q $POD -c dns -- cat /etc/resolv.conf| grep nameserver | awk '{print $2}';done | sort | uniq -c | awk '{print $2}')
    ALL_URLS=("$API" "$API_INT" "$INGRESS_URL")
    ALL_OCP_ROUTES=("oauth-openshift.apps.$BASE_DOMAIN" "console-openshift-console.apps.$BASE_DOMAIN" "canary-openshift-ingress-canary.apps.$BASE_DOMAIN" )
    TEST_POD_NS=openshift-ingress-operator
    TEST_POD_CONTAINER=ingress-operator
    TEST_POD=$(oc get pod -n $TEST_POD_NS | grep -v NAME | awk '{print $1}')
    TIMEOUT=10
    TIMESTAMP=$(date +%d_%m_%Y-%H_%M_%S-%Z) 
    OUTPUT_FILE=result_ocp-sanity-check-gather
    FILE_FORMAT=json
    OUTPUT_DIR=outputs

}

function check_dns_resolution_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for URL in ${ALL_URLS[@]}
    do
        if [[ $URL == *"api-int"* ]]; then 
            continue
        fi
        DIG_OUTPUT=$(dig $URL A)
        DIG_SERVER=$(echo $DIG_OUTPUT  | tr -s ';' '\n' | grep 'SERVER' | awk '{print $2}')
        DIG_ANSWER=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'ANSWER SECTION' | awk '{print $7}')
        DIG_STATUS=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'status:' | cut -d "," -f2 | awk '{print $2}')
        DIG_TIME=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'Query time' | awk '{print $3 " " $4}')
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);bastion;$URL;${DIG_ANSWER:="NOK!"};${DIG_SERVER:="NOK!"};${DIG_STATUS:="NOK!"};${DIG_TIME:="NOK!"} \n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-device","target-url","dns-answer","dns-server","query-status","query-time" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json
}

function check_dns_resolution_per_upstream_incluster  {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for URL in ${ALL_URLS[@]}
    do
            for DNS in ${DNS_UPSTREAMS_INCLUSTER[@]}
            do
                DIG_OUTPUT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig @$DNS $URL A 2> /dev/null)
                DIG_SERVER=$(echo $DIG_OUTPUT  | tr -s ';' '\n' | grep 'SERVER' | awk '{print $2}')
                DIG_ANSWER=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'ANSWER SECTION' | awk '{print $7}')
                DIG_STATUS=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'status:' | cut -d "," -f2 | awk '{print $2}')
                DIG_TIME=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'Query time' | awk '{print $3 " " $4}')
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);$TEST_POD;$URL;${DIG_ANSWER:="NOK!"};${DIG_SERVER:="NOK!"};${DIG_STATUS:="NOK!"};${DIG_TIME:="NOK!"}\n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
                sleep 0.5
            done
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-pod","target-url","dns-answer","dns-server","query-status","query-time" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json
}

function check_ocp_routes_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        RESULT=$(curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "%{time_namelookup};%{time_connect};%{time_total};%{response_code};%{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz") 
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);bastion;$ROUTE;$RESULT \n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-device","target-route","dns-lookup","connect-time","time-total","response-code","local-port" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json

}

function check_ocp_routes_routers_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                RESULT=$(curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "%{time_namelookup};%{time_connect};%{time_total};%{response_code};%{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP") 
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);bastion;$ROUTE;$ROUTER_IP;$RESULT \n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
                sleep 0.5
            done
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-device","target-route","router-ip","dns-lookup","connect-time","time-total","response-code","local-port" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json
}

function check_ocp_routes_incluster {
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "%{time_namelookup};%{time_connect};%{time_total};%{response_code};%{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz") 
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);$TEST_POD;$ROUTE;$RESULT \n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-device","target-route","dns-lookup","connect-time","time-total","response-code","local-port" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json
}

function check_ocp_routes_routers_incluster {
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "%{time_namelookup};%{time_connect};%{time_total};%{response_code};%{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP") 
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z);$TEST_POD;$ROUTE;$ROUTER_IP;$RESULT \n" >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP
            done
    done
    printf "\n"
    sleep 0.5
    done
    cat $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP | column -s";" --table-columns "timestamp","source-device","target-route","router-ip","dns-lookup","connect-time","time-total","response-code","local-port" -t -n ${FUNCNAME[0]} -J  >> $OUTPUT_DIR/${FUNCNAME[0]}_$TIMESTAMP.json


}

printf "Starting the ocp-sanity-check-gather script... All tests are going to run ${MAGENTA}$CONN_ATTEMPT${ENDCOLOR} time(s) \U1F916 \n"
printf "Building environment variables... \U1F941 \n"
build_env_vars 2> errors.txt
if [[ -s errors.txt ]]; then
    echo "Not possible to build required env vars"
    cat errors.txt
    rm -f errors.txt
    exit 1;
fi

printf "Check DNS resolution in the target OCP cluster... \U1F9E0 \n"
check_dns_resolution_inbastion &
check_dns_resolution_per_upstream_incluster &
printf "Route checks in the involved routes... \U1F680 \n"
check_ocp_routes_inbastion &
check_ocp_routes_routers_inbastion &
check_ocp_routes_incluster &
check_ocp_routes_routers_incluster &
wait
cat $OUTPUT_DIR/*$TIMESTAMP.json >> $OUTPUT_DIR/$OUTPUT_FILE-$TIMESTAMP.$FILE_FORMAT
printf "All checks have been finished \U1F9D9 Check results in file ${GREEN}$OUTPUT_DIR/$OUTPUT_FILE-$TIMESTAMP.$FILE_FORMAT${ENDCOLOR} \U1F48E \n"
rm -f $OUTPUT_DIR/check*$TIMESTAMP.json $OUTPUT_DIR/check*$TIMESTAMP*
rm -f errors.txt

