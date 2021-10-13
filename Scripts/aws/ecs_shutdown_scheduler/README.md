#ECS_shutdown_scheduler

This lambda function runs at night and morning setting ECS services desired count down to a (configureable) minimal value or back to the previously retained values.

###How does it act?

If a capacity provider is attached to the cluster, the services are not touched and the capacity provider is updated instead.
If no capacity provider is present, the lambda runs through each service, setting it down to minimal values or back up to previous values.
If an ECS cluster has both a capacity provider and container instances from another autoscaling group (other than the one attached to the capacity provider),
only the other autoscaling group minimum and desired values are updated.

###Installation

1. Create an IAM role for the lambda.
2. Add the "AWSLambdaBasicExecutionRole" policy to the role in addition to the [inline\_policy_document] (https://github.com/geek-kb/DevopsStuff/tree/master/Scripts/aws/ecs_shutdown_schedule/lambda_inline_policy.json) file which can be found in this directory.
3. Create 2 CloudWatch events, rules and targets and point them to the function. Name one event "StartUp" and the other "Shutdown". configure the rule as Cron and set the relevant schedule_expression (Example: `"cron(0 8 * * ? *)"` for StartUp and `"cron(0 23 * * ? *)"` for ShutDown.
4. Under "Asynchronous invocation", configure "0" retry attempts.
5. Under "Environment Variables", create a new variable: `LOG_LEVEL: INFO`.
6. Once the triggers are configured, edit each one of them, under "Select targets -> configure input; check Constant (JSON text) and for the StartUp trigger add: `{ "Task": "Start"}` and for the Shutdown trigger add: `{ "Task": "Shutdown"}`.
