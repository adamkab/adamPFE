#!/bin/bash

dockerImageName=$(awk 'NR==1 {print $2}' Dockerfile)
echo $dockerImageName

# Generate HTML report with template
docker run --rm -v $WORKSPACE:/root/.cache/ -v $WORKSPACE:/tmp aquasec/trivy:0.17.2 -q image --format template --template "@html.tpl" -o /tmp/TrivyReport.html --severity CRITICAL,HIGH --light $dockerImageName

# Run scan for exit code check
docker run --rm -v $WORKSPACE:/root/.cache/ aquasec/trivy:0.17.2 -q image --exit-code 1 --severity CRITICAL,HIGH --light $dockerImageName

# Trivy scan result processing
exit_code=$?
echo "Exit Code : $exit_code"

# Check scan results
if [[ "${exit_code}" == 1 ]]; then
    echo "Image scanning failed. Vulnerabilities found"
    exit 1;
else
    echo "Image scanning passed. No CRITICAL vulnerabilities found"
fi;