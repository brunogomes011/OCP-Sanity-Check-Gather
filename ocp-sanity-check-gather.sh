#!/bin/bash

function build_env_vars {

    BASE_DOMAIN=$(oc get dns/cluster -ojson | jq -r .spec.baseDomain)
    API=api.$BASE_DOMAIN
    API_INT=api-int.$BASE_DOMAIN
    INGRESS_URL="*.apps."$BASE_DOMAIN
    ROUTERS_IPS=$(oc get pod -n openshift-ingress -l ingresscontroller.operator.openshift.io/deployment-ingresscontroller=default -o=jsonpath="{.items[*]['status.podIP']}")
    DNS_UPSTREAMS_INCLUSTER=$(for POD in $(oc get pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default --no-headers | awk '{print $1}'); do oc exec -n openshift-dns -q $POD -c dns -- cat /etc/resolv.conf| grep nameserver | awk '{print $2}';done | sort | uniq -c | awk '{print $2}')
    ALL_URLS=("$API" "$API_INT" "$INGRESS_URL")
    ALL_OCP_ROUTES=("oauth-openshift.apps.$BASE_DOMAIN" "console-openshift-console.apps.$BASE_DOMAIN" "canary-openshift-ingress-canary.apps.$BASE_DOMAIN" )
    USER_CUSTOM_ATTEMPT=$1
    CONN_ATTEMPT="${USER_CUSTOM_ATTEMPT:=1}"
    TEST_POD_NS=openshift-ingress-operator
    TEST_POD_CONTAINER=ingress-operator
    TEST_POD=$(oc get pod -n $TEST_POD_NS | grep -v NAME | awk '{print $1}')
    TIMEOUT=10
    TIMESTAMP=$(date +%d_%m_%Y-%H_%M_%S-%Z).log 
    OUTPUT_FILE=output_result

}

function check_dns_resolution_inbastion {
    printf "DNS resolution check within bastion host  \n" >> ${FUNCNAME[0]}_$TIMESTAMP
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
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source device - bastion | Target URL - $URL | DNS answer - ${DIG_ANSWER:="NOK!"} | DNS server - ${DIG_SERVER:="NOK!"} | Query status - ${DIG_STATUS:="NOK!"} | Query time - ${DIG_TIME:="NOK!"} \n" >> ${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done

}

function check_dns_resolution_per_upstream_incluster  {
    printf "DNS resolution check within the test pod $TEST_POD_NS/$TEST_POD \n" >> ${FUNCNAME[0]}_$TIMESTAMP
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for URL in ${ALL_URLS[@]}
    do
            for DNS in ${DNS_UPSTREAMS_INCLUSTER[@]}
            do
                DIG_OUTPUT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig @$DNS $URL A )
                DIG_SERVER=$(echo $DIG_OUTPUT  | tr -s ';' '\n' | grep 'SERVER' | awk '{print $2}')
                DIG_ANSWER=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'ANSWER SECTION' | awk '{print $7}')
                DIG_STATUS=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'status:' | cut -d "," -f2 | awk '{print $2}')
                DIG_TIME=$(echo $DIG_OUTPUT | tr -s ';' '\n' | grep 'Query time' | awk '{print $3 " " $4}')
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source POD $TEST_POD | Target URL - $URL | DNS answer - ${DIG_ANSWER:="NOK!"} | DNS server - ${DIG_SERVER:="NOK!"} | Query status - ${DIG_STATUS:="NOK!"} | Query time - ${DIG_TIME:="NOK!"} \n" >> ${FUNCNAME[0]}_$TIMESTAMP
                sleep 0.5
            done
    done
    printf "\n"
    sleep 0.5
    done

}

function check_ocp_routes_inbastion {
    printf "Route sanity check within bastion host \n" >> ${FUNCNAME[0]}_$TIMESTAMP
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        RESULT=$(curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz") 
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source device - bastion | Target - $ROUTE | $RESULT \n" >> ${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done

}

function check_ocp_routes_routers_inbastion {
    printf "Route sanity check within bastion host against router pods \n" >> ${FUNCNAME[0]}_$TIMESTAMP
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                RESULT=$(curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP") 
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source device - bastion | Target - $ROUTE | Target router IP - $ROUTER_IP | $RESULT \n" >> ${FUNCNAME[0]}_$TIMESTAMP
                sleep 0.5
            done
    done
    printf "\n"
    sleep 0.5
    done

}

function check_ocp_routes_incluster {
    printf "Route sanity check within test pod $TEST_POD_NS/$TEST_POD \n" >> ${FUNCNAME[0]}_$TIMESTAMP
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz") 
        printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source device - $TEST_POD | Target - $ROUTE | $RESULT \n" >> ${FUNCNAME[0]}_$TIMESTAMP
        sleep 0.5
    done
    printf "\n"
    sleep 0.5
    done

}

function check_ocp_routes_routers_incluster {
    printf "Route sanity check within test pod $TEST_POD_NS/$TEST_POD against router pods \n" >> ${FUNCNAME[0]}_$TIMESTAMP
    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP") 
                printf "$(date +%Y-%m-%dT%H:%M:%S.%3NZ%:z) | Source device - $TEST_POD | Target - $ROUTE | Target router IP - $ROUTER_IP |  $RESULT \n" >> ${FUNCNAME[0]}_$TIMESTAMP
            done
    done
    printf "\n"
    sleep 0.5
    done

}

printf "Starting the ocp-sanity-check-gather script... All tests are going to run $CONN_ATTEMPT time(s)  \n"
printf "Building environment variables \n"
build_env_vars 2> errors.txt
if [[ -s errors.txt ]]; then
    echo "Errors found to build the env vars"
    cat errors.txt
    rm -f errors.txt
    exit 1;
fi

printf "DNS resolution checks running...  \n"
check_dns_resolution_inbastion &
check_dns_resolution_per_upstream_incluster &
printf "Route checks running...  \n"
check_ocp_routes_inbastion &
check_ocp_routes_routers_inbastion &
check_ocp_routes_incluster &
check_ocp_routes_routers_incluster &
wait
cat *$TIMESTAMP >> $OUTPUT_FILE-$TIMESTAMP
printf "All checks has been finished...  \n"
rm -f check*$TIMESTAMP
rm -f errors.txt

