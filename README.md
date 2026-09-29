```markdown
# Day 2 Operations Lab: Serverless Pipeline Escalation & RCA

## Overview
This repository contains a local cloud emulation lab built to demonstrate Day 2 operational support, incident response, and root cause analysis. Using Terraform and Floci (a local AWS emulator), I provisioned an event-driven pipeline (SQS -> Lambda), simulated a silent production outage, and resolved the escalation.

### Tech Stack
* **Infrastructure as Code:** Terraform
* **Cloud Emulator:** Floci (AWS API mock running on Docker/WSL)
* **Compute & Messaging:** AWS Lambda (Python), Amazon SQS

---

## Incident Report (RCA)

### 1. The Symptom (Silent Outage)
Customer orders were successfully entering the system, but the backend order processing pipeline stalled. Crucially, no application errors or crashes were reported in the logs. This was a "silent" failure.

### 2. Investigation & Troubleshooting Steps
To isolate the issue, I applied a standard troubleshooting framework checking Path (Networking/Connections), Permissions (IAM), and Resources (Capacity).

* **Step 1: Verify the Backlog** 
  I queried the SQS queue attributes using the AWS CLI and confirmed a spike in `ApproximateNumberOfMessages`. Data was piling up.
  ```bash
  aws sqs get-queue-attributes \
    --endpoint-url http://localhost:4566 \
    --queue-url http://localhost:4566/000000000000/day2-lab-order-queue \
    --attribute-names ApproximateNumberOfMessages

```

* **Step 2: Check Compute Logs**
I checked the active container logs for the Lambda executor. There were **zero invocations**. The backend compute was healthy, but it was not being triggered.
```bash
docker logs -f floci-aws

```


* **Step 3: Check The Path (Event Mapping)**
Since the queue had data but the Lambda wasn't firing, the bridge between them was the suspected point of failure. I reviewed the Terraform state and AWS configuration for the pipeline.

### 3. Root Cause

The `aws_lambda_event_source_mapping` resource had been removed from the infrastructure configuration. This severed the physical connection between the SQS queue and the Lambda function, leaving the queue without an active listener.

### 4. Resolution & Validation

1. **The Fix:** Restored the `aws_lambda_event_source_mapping` block within `main.tf` to re-establish the pipeline path.
2. **Deployment:** Executed `terraform apply` to push the corrected infrastructure state.
3. **Validation:** Monitored the live logs to confirm the connection was restored. The Lambda function immediately triggered, successfully draining the backlog and processing the stuck payloads (e.g., "Order 103" and "Order 104").

```