# This project's aim is to shutdown unused QA environments in order to save AWS workload costs.

## Requirements
* AWS Account/s
* GitHub + GitHub Actions
* Dynamodb
* ECS
Based on usage of Terragrunt

## Structure
### environment_protection job:
Is ran manually by a user intending to protect an environment he's user and requires the user to select an environment name from a list and provide a protection end date.
Once the job is started, it updates a dynamodb table, setting the environment and it end protection date in the table.

### nightly_scale_down_qa_envs job:
Runs automatically every evening at 20:00.
It first identifies the environments that are unprotected (and intended to go down for the night) and also verifies if the environment is currently running or not.
There are 3 different options to this check:
1. If an environment is set as protected.
2. If an environment is set as not protected and running.
3. If an environment is set as not protected and is not running.
Only if the 3rd rule applies, then the environment is marked for shutting down, otherwise it is ignored.
Since the customer where this project was applied is using two different AWS accounts, the logic is running on any of these accounts.
In order to make sure all relevant (per environment) services are considered, even when new ones are created (without adding any of them manually), the services repository is checked out and the logic gets the most updated list of services based on each service's directory.
It then:
1. Gets current ECS desired values from all services terragrunt.hcl files and updates the dynamodb table.
2. Gets current AutoScaling Groups desired values from all services terragrunt.hcl files and updates the dynamodb table.
3. Updates each ECS service desired value to 0 in terragrunt.hcl files.
4. Updates each service's ASG desired value to 0 in terragrunt.hcl files.
5. Updates special-service's capacity provider scale in and out desired values to 0 in terragrunt.hcl file.
6. Disables repository branch protection.
7. Commits each environments updated files, sleeps a random time interval (to avoid race conditions), pushes the updated files, creates a matrix from the commit ids and marks each environment as off (also updating the dynamodb table).
8. Re-enables repository branch protection.
9. Then the workflow monitors the commits matrix, waiting for all environments terragrunt runs to complete.
10. Once all terragrunt runs complete, a relevant notification is sent to a relevant slack channel - showing which environment have been taken down and whether they completed successfully or not.

The images can show some of the progress, so feel free to check them.

### environments_protection_dynamodb.py
This is the code relevant for all the dynamodb related operations (read, update, get current information)


### DynamoDB_table_creation directory
Contains the required files to create the DynamoDB table and to populate it with initial values.



Project by Itai Ganot, 2022