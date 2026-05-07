# OCP-Sanity-Check-Gather

Welcome to the ocp-sanity-check-gather tool page!

This is an automated sanity check from Openshift external load balancer. As load balancer checks are responsability of reliability team and not from kubernetes operators, this code performs required checks to determine if the LB is healthy or not. 

Note: It is recommended to run the script within clusters with external load balancer installed.

### Requirements

- Linux OS
- dig
- curl
- column
- Openshift client (oc)
- jq

### Usage

- Configure your KUBECONFIG to connect to the cluster 
- Ensure that the required applications are installed in your server
- Run the script. The attempt times can be controlled with number after script. See example:

  ~~~
  $ curl -O https://raw.githubusercontent.com/brunogomes011/OCP-Sanity-Check-Gather/refs/heads/main/ocp-sanity-check-gather.sh && chmod u+x ocp-sanity-check-gather.sh
  $ ./ocp-sanity-check-gather.sh 3 # The number represents the quantity of connection attempts that the script will do
  ~~~

- Additionally, the script can be also performed within OCP node side:

  ~~~
  $ oc debug node/<node-name>
  $ chroot /host
  $ cd /tmp
  $ export KUBECONFIG=<kubeconfig-file> # oc login also works
  $ curl -O https://raw.githubusercontent.com/brunogomes011/OCP-Sanity-Check-Gather/refs/heads/main/ocp-sanity-check-gather.sh && chmod u+x ocp-sanity-check-gather.sh
  $ ./ocp-sanity-check-gather.sh 3 # The number represents the quantity of connection attempts that the script will do
  ~~~

### Outputs

- The outputs are provided in outputs directory in json or txt format. It is possible to run jq queries to consume the data:

  ~~~
  $ cat ocp_checks/result_ocp-sanity-check-gather-*.json | jq .
  ~~~

### Contributing

Feel free to contribute and send any PR to improve it.
