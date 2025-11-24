# Task Group B (Part 3): Monitoring & Alerting Implementation

## 1. Objective
Ensuring high availability and performance requires proactive monitoring. The objective of this task was to implement an automated alerting system that notifies administrators via email whenever the CPU utilization of the EC2 instances exceeds a critical threshold of **50%**.

This mechanism allows the operations team to react immediately to performance bottlenecks or potential Denial of Service (DoS) attacks before they impact the user experience.

---

## 2. Technical Architecture: CloudWatch & SNS

We leveraged AWS-native observability tools to build this solution without the need for third-party agents. The architecture consists of three components:

1.  **Metric Source:** AWS EC2 sends infrastructure metrics (CPU, Network, Disk) to **CloudWatch** by default every 5 minutes (Basic Monitoring).
2.  **Alarm Logic:** A CloudWatch Alarm evaluates the `CPUUtilization` metric against the defined threshold.
3.  **Notification Channel:** **Amazon SNS (Simple Notification Service)** acts as the delivery mechanism, pushing the alert to an email endpoint.

### Architecture Flow
> **EC2 Instance** (Metrics) ➡️ **CloudWatch Alarm** (Evaluation) ➡️ **SNS Topic** (Trigger) ➡️ **Email** (Notification)

---

## 3. Implementation Details (Terraform)

The entire monitoring stack was provisioned as code using Terraform (`monitoring.tf`), ensuring that monitoring is enabled from the moment the infrastructure is born.

### 3.1 SNS Topic Configuration
*   **Resource:** `aws_sns_topic`
*   **Name:** `obelion-cpu-high-alerts`
*   **Subscription:** Email protocol subscribed to the topic.
*   **Verification:** AWS mandates that email subscriptions be confirmed. Upon creation, a confirmation link was sent to the provided email address, which was manually validated.

### 3.2 CloudWatch Alarm Configuration
We defined a `aws_cloudwatch_metric_alarm` with the following rigorous parameters to prevent false positives (flapping):

| Parameter | Value | Justification |
| :--- | :--- | :--- |
| **Metric Name** | `CPUUtilization` | The primary indicator of compute load. |
| **Threshold** | `50` (%) | As per task requirements. |
| **Comparison** | `GreaterThanThreshold` | Triggers when usage > 50%. |
| **Period** | `120` (seconds) | Metric granularity. |
| **Evaluation Periods** | `2` | **Critical:** The CPU must remain high for 2 consecutive periods (4 minutes total) to trigger the alarm. This avoids alerts for momentary spikes during application startup. |
| **Statistic** | `Average` | Uses the average CPU usage across the period. |

---

## 4. Testing & Validation (Stress Test)

To prove the efficacy of the alerting system, we performed a controlled **Stress Test** on the Frontend Server. Since the infrastructure was idle, we needed to artificially induce load.

### 4.1 Methodology
We utilized the Linux `stress` utility to maximize CPU load on the `t3.micro` instance.

**Steps Executed:**
1.  Connected to the Frontend server via SSH: `make ssh-frontend`.
2.  Installed the utility: `sudo apt-get install stress -y`.
3.  Executed the stress command targeting both vCPUs (since `t3.micro` has 2 threads):
    ```bash
    stress --cpu 2 --timeout 600
    ```
    *This command forces the CPU to run at 100% capacity for 10 minutes.*

### 4.2 Evidence of Detection (CloudWatch)
Within approximately 4-5 minutes (due to the evaluation period), the CloudWatch console registered the spike. The alarm state transitioned from `OK` to `ALARM`.

The graph below, captured from the AWS Console, clearly shows the CPU utilization flatlining near 0%, then spiking to 100% during our test, crossing the red 50% threshold line.

![CloudWatch CPU Graph](./images/cloudwatch-cpu-graph.png)

### 4.3 Evidence of Notification (Email)
Simultaneously with the alarm state change, Amazon SNS dispatched an email notification. The screenshot below shows the actual email received, containing details such as the Alarm Name (`frontend-cpu-high`), the specific instance ID, and the timestamp.

![SNS Email Alert](./images/sns-email-alert.png)

---

## 5. Operational Response Plan
In a production environment, receiving this email would trigger the following incident response workflow:

1.  **Acknowledge:** The on-call engineer acknowledges the alert.
2.  **Investigate:**
    *   Log into the server via SSH.
    *   Run `top` or `htop` to identify the process consuming CPU.
    *   Check application logs (`/var/log/nginx/error.log` or `docker logs`).
3.  **Remediate:**
    *   If valid traffic: Consider scaling up the instance size (Vertical Scaling) or adding more instances behind a Load Balancer (Horizontal Scaling).
    *   If malicious/bug: Kill the process or block the attacking IP.
4.  **Resolve:** Once CPU drops below 50%, the CloudWatch Alarm automatically returns to `OK` state, and a recovery email is sent (if configured).

---

## 6. Conclusion
The monitoring implementation successfully meets the requirement. We have established a closed-loop feedback system where infrastructure health is continuously observed, and deviations are instantly communicated to stakeholders, ensuring rapid Time-To-Resolution (TTR).