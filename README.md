# OCP-Sanity-Check-Gather

Welcome to the ocp-sanity-check-gather tool page!

This script/tool runs a set of connectivity tests against the OCP components from OCP's administrator working machine (bastion host). The tool also connects to the ingress operator pod to run tests within the cluster to provide a better perspective of the potential failures from cluster's clusterNetwork. In case of any failure in the API or Ingress components, this script can be a good starting to investigate a potential network issue inside or outside the OCP cluster. 

In summary, the tool collects all crucial URLs from kube-apiserver and default ingress controller components to test DNS and https connections. The general objective is trying to identify which components are able to connect each one with an unique test.

### Application requirements

- Linux distribution machine
- dig
- curl
- column command
- git 
- Openshift client (oc)
- jq

### Usage

- Configure your KUBECONFIG to connect to the cluster 
- Clone the repository 
- Run the script. The attempt times can be controlled with number after script. See example:

  ~~~
  $ git clone https://github.com/brunogomes011/OCP-Sanity-Check-Gather.git
  $ cd OCP-Sanity-Check-Gather && chmod u+x ocp-sanity-check-gather.sh
  $ ./ocp-sanity-check-gather.sh 2
  ~~~

### Outputs

- The outputs are provided in outputs directory in json format. It is possible to run jq queris to consume the data:

  ~~~
  $ cat outputs/result_ocp-sanity-check-gather-*.json | jq .
  ~~~


- Enjoy

### Contributing

Feel free to contribute and send any PR to improve it.
