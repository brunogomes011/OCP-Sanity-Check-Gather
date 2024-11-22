# OCP-Sanity-Check-Gather

Welcome to the ocp-sanity-check-gather tool page

This script/tool runs a set of connectivity tests against the OCP components within OCP's administrator working machine. The tool also connects to the ingress operator pod to run tests within the cluster to provide a better perspective of the potential failures from cluster's clusterNetwork. In case of any failure in the API or Ingress components, this script can be a good starting to investigate a potential network issue in or out the OCP cluster. 

In summary, the tool collects all crucial URLs from kube-apiserver and default ingress controller components to test DNS and https connections. The general objective is trying to identify which components are able to connect each one with an unique test.


### Usage

- Ensure that the source machine is installed with any Linux distribution and it is able to run shell scripts
- Ensure that the target OCP cluster is accessible by oc commands. This means that the access has been done by oc login or any kubeconfig file.
- Download the latest ocp-sanity-check-gather.sh file, change its permissions and run it.

  ~~~
  $ curl -O https://raw.githubusercontent.com/brunogomes011/OCP-Sanity-Check-Gather/refs/heads/main/ocp-sanity-check-gather.sh
  $ chmod u+x ocp-sanity-check-gather.sh
  $ ./ocp-sanity-check-gather.sh
  ~~~


- The tool is going to test according to the number configured in the first parameter. For example: If it is expected to run the tests 10 times, the following commands should be applied:

  ~~~
  $ ./ocp-sanity-check-gather.sh 10
  ~~~

- It is a good practice to save the output in a file for better review:

  ~~~
  $ ./ocp-sanity-check-gather.sh 10 >> ocp-sanity-check-gather-results
  ~~~

- Enjoy

### Contributing

Feel free to contribute and send any PR to improve it.
