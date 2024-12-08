#!/bin/bash


BASE_DOMAIN=$(oc get dns/cluster -oyaml | grep baseDomain | awk '{print $2}')
API=api.$BASE_DOMAIN
API_INT=api-int.$BASE_DOMAIN
INGRESS_URL="*.apps."$BASE_DOMAIN
ROUTERS_IPS=$(oc get pod -n openshift-ingress -owide | grep -v NAME | awk '{print $6}')
DNS_UPSTREAMS=$(oc debug -q node/$(oc get nodes | grep 'Ready ' | head -n1| awk '{print $1}') -- chroot /host cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
ALL_URLS=("$API" "$API_INT" "$INGRESS_URL")
ALL_OCP_ROUTES=("oauth-openshift.apps.$BASE_DOMAIN" "console-openshift-console.apps.$BASE_DOMAIN" "canary-openshift-ingress-canary.apps.$BASE_DOMAIN" )
USER_CUSTOM_ATTEMPT=$1
CONN_ATTEMPT="${USER_CUSTOM_ATTEMPT:=1}"
TEST_POD_NS=openshift-ingress-operator
TEST_POD_CONTAINER=ingress-operator
TEST_POD=$(oc get pod -n $TEST_POD_NS | grep -v NAME | awk '{print $1}')
TIMEOUT=10


function check_dns_resolution_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "URL DNS resolution is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for URL in ${ALL_URLS[@]}
    do
        printf '#######\n'
        date
        printf "Ensuring that the DNS resolution is working for $URL \n"
        printf '####### \n'
        printf "Find the DNS answer \n"
        RESULT=$(dig $URL +noall +answer)
        printf "${RESULT:="NOK!"} \n"
        printf '####### \n'
        printf "Find the DNS stats details \n"
        RESULT=$(dig $URL +noall +stats )
        printf "${RESULT:="NOK!"} \n"
        printf '####### \n\n'
        sleep 0.5
    done
    sleep 0.5
    done

}


function check_dns_resolution_per_upstream_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "URL DNS resolution is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for URL in ${ALL_URLS[@]}
    do
            for DNS in ${DNS_UPSTREAMS[@]}
            do
                printf '####### \n'
                date
                printf "Ensuring that the DNS resolution is working for $URL against DNS upstream $DNS \n"
                printf '####### \n'
                printf "Find the DNS answer against DNS upstream $DNS \n"
                RESULT=$(dig $URL @$DNS +noall +answer)
                printf "${RESULT:="NOK!"} \n"
                printf '####### \n'
                printf "Find the DNS stats details against DNS upstream $DNS \n"
                RESULT=$(dig $URL @$DNS +noall +stats )
                printf "${RESULT:="NOK!"} \n"               
                printf '####### \n\n'
                sleep 0.5
            done
    done
    sleep 0.5
    done

}


function check_dns_resolution_incluster {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '#######'
    printf "URL DNS resolution is going to be tested $ATTEMPT time(s)"
    printf '#######'
    for URL in ${ALL_URLS[@]}
    do
        printf '####### \n'
        date
        printf "Ensuring that the DNS resolution is working for $URL within pod $TEST_POD and namespace $TEST_POD_NS \n"
        printf '####### \n'
        printf "Find the DNS answer \n"
        printf "oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL +noall +answer \n"
        RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL +noall +answer)
        printf "${RESULT:="NOK!"} \n"
        printf '####### \n'
        printf "Find the DNS stats details \n"
        printf "oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL +noall +stats \n"
        RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL +noall +stats)
        printf "${RESULT:="NOK!"} \n"
        printf '####### \n\n'
        sleep 0.5
    done
    sleep 0.5
    done

}


function check_dns_resolution_per_upstream_incluster  {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### '
    printf "URL DNS resolution is going to be tested $ATTEMPT time(s) \n"
    printf '#######'
    for URL in ${ALL_URLS[@]}
    do
            for DNS in ${DNS_UPSTREAMS[@]}
            do
                printf '####### \n'
                date
                printf "Ensuring that the DNS resolution is working for $URL against DNS upstream $DNS within pod $TEST_POD and namespace $TEST_POD_NS \n"
                printf '####### \n'
                printf "Find the DNS answer against DNS upstream $DNS \n"
                RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL @$DNS +noall +answer )
                printf "${RESULT:="NOK!"} \n"
                printf '####### \n'
                printf "Find the DNS stats details against DNS upstream $DNS \n"
                RESULT=$(oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- dig $URL @$DNS +noall +stats)
                printf "${RESULT:="NOK!"} \n"             
                printf '####### \n\n'
                sleep 0.5
            done
    done
    sleep 0.5
    done

}

function check_ocp_routes_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "The OCP routes check inbastion is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        printf '####### \n'
        date
        printf "Testing the connectivity against the route $ROUTE \n"
        curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" 
        printf '####### \n\n'
    done
    sleep 0.5
    done

}

function check_ocp_routes_routers_inbastion {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "The OCP routes check inbastion with resolve is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                printf '####### \n'
                date
                printf "Testing the connectivity against the route $ROUTE with router IP $ROUTER_IP \n"
                curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP" 
                printf '####### \n\n'
            done
    done
    sleep 0.5
    done

}

function check_ocp_routes_incluster {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "The OCP routes check in cluster is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
        printf '####### \n'
        date
        printf "Testing the connectivity against the route $ROUTE within pod $TEST_POD and namespace $TEST_POD_NS \n"
        oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" 
        printf '####### \n\n'
    done
    sleep 0.5
    done

}

function check_ocp_routes_routers_incluster {

    for (( ATTEMPT=$CONN_ATTEMPT; ATTEMPT >= 1; ATTEMPT-- ))
    do 
    printf '####### \n'
    printf "The OCP routes check incluster with resolve is going to be tested $ATTEMPT time(s) \n"
    printf '####### \n\n'
    for ROUTE in ${ALL_OCP_ROUTES[@]}
    do
            for ROUTER_IP in ${ROUTERS_IPS[@]}
            do
                printf '####### \n'
                date
                printf "Testing the connectivity against the route $ROUTE with router IP $ROUTER_IP within pod $TEST_POD and namespace $TEST_POD_NS \n"
                oc exec -c $TEST_POD_CONTAINER -n $TEST_POD_NS $TEST_POD -- curl --connect-timeout $TIMEOUT --noproxy '*' -k -w "dnslookup: %{time_namelookup} | connect: %{time_connect} | appconnect: %{time_appconnect} | pretransfer: %{time_pretransfer} | starttransfer: %{time_starttransfer} | total: %{time_total} | size: %{size_download} | response: %{response_code} | local-port: %{local_port}\n" -o /dev/null -s "https://$ROUTE/healthz" --resolve "$ROUTE:443:$ROUTER_IP" 
                printf '####### \n\n'
            done
    done
    sleep 0.5
    done

}


printf "Starting the ocp-sanity-check-gather script... All tests are going to run $CONN_ATTEMPT time(s)  \n"
check_dns_resolution_inbastion
check_dns_resolution_incluster 
check_dns_resolution_per_upstream_inbastion
check_dns_resolution_per_upstream_incluster
check_ocp_routes_inbastion
check_ocp_routes_routers_inbastion
check_ocp_routes_incluster
check_ocp_routes_routers_incluster


