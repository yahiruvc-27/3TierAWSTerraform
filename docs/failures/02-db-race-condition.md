# Failure 02 — Distributed DB Schema Initialization Race Condition

Adding multi AZ ASG deployments brings resiliency, fault tolerance, scalability but also introduces complexity on initialization logic and can "break" or cause unexpected beheaviorus on other system dependencies

Context

- Backend runs in an Auto Scaling Group (Multiple instances)
- My DB schema script runs at instance boot (user data)

Problem: Each instance attempts DB schema initialization (Duplicate table creation attempts, error prone and in general this does not scale)

## Root Cause

ASG introduces concurrent execution.
Schema initialization was not protected against parallel runs.

This is a distributed systems problem(script), not a database bug.

# Note
s
For this MVP version 1.0, I intentionally started Db schema on EC2 startup ->  to force myself to deal with distributed env issues. 

I am aware (of other configuration tools) that for production, this (one time job) will be handled by a separate script or ideally pipeline step to decouple ASG provisioning from database schema and start up.
