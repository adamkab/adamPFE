#!/bin/bash

PORT=$(kubectl -n default get svc ${serviceName} -o json | jq .spec.ports[].nodePort)

# Create reports directory in workspace
mkdir -p ${WORKSPACE}/owasp-zap-report

# Give proper permissions
chmod 777 ${WORKSPACE}/owasp-zap-report
echo $(id -u):$(id -g)

# Run ZAP scan with custom rules
docker run -v ${WORKSPACE}:/zap/wrk/:rw -t ghcr.io/zaproxy/zaproxy:stable zap-api-scan.py \
    -t $applicationURL:$PORT/v3/api-docs \
    -f openapi \
    -c zap_rules \
    -r owasp-zap-report/zap_report.html

exit_code=$?

# Verify report was created
if [ -f "${WORKSPACE}/owasp-zap-report/zap_report.html" ]; then
    echo "OWASP ZAP report generated successfully"
    # Set proper permissions for Jenkins to read
    chmod -R 755 ${WORKSPACE}/owasp-zap-report
else
    echo "ERROR: OWASP ZAP report was not generated"
    exit 1
fi

echo "Exit Code : $exit_code"

if [[ ${exit_code} -ne 0 ]]; then
    echo "WARNING: OWASP ZAP Report has either Low/Medium/High Risk. Please check the HTML Report"
    echo "Continuing build despite vulnerabilities found..."
else
    echo "OWASP ZAP did not report any Risk"
fi

# Always exit with success to continue the pipeline
exit 0