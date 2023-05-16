
docker kill test-app
docker rm test-app
docker run -td --name test-app -v $(pwd):/test  membraneframeworklabs/docker_membrane:latest
docker exec test-app sh -c "cd /test && mix coveralls.json --warnings-as-errors"