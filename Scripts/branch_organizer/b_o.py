#!/usr/bin/env python3
# Script by Itai Ganot, lel@lel.bz

"""
This script contacts Gitlab API to find all branches of REPO repo where no commits have been pushed to for over 6 months
and sends an email to rnd@company.com, letting developers know that their branches will be deleted within a week if they
don't explicitly add them to the white.list file (currently done by emailing cicd-team@company.com).

If you want to protect some branches, meaning that the script won't even process them then add them to the
PROTECTED_BRANCHES list in the variables section.
If there are branches that are considered unwanted, meaning that if the script bumps into them, they will be added to
the database and will be deleted on the spot then add them to the unwanted_branches list in the variables section.

The script expects the user to provide arguments for database password and Gitlab private token.

The script requires a single table on a MySql database, use the following mysql queries to create the required table
for the script:

CREATE TABLE branches_to_delete (
    source_control varchar(10),
    branch_name varchar(255),
    last_committer varchar(255),
    status varchar(10),
    insert_date datetime DEFAULT CURRENT_TIMESTAMP);

ALTER TABLE `branches_to_delete` ADD UNIQUE INDEX `unique_branch_name` (`branch_name`);
"""


import gitlab
from datetime import date
from datetime import datetime
from dateutil.relativedelta import relativedelta
import urllib3
import smtplib
import mysql.connector
import argparse
import re
from os import path
from os import getcwd
from email.message import Message


PROTECTED_BRANCHES = ["^reponame-R*", "final-*", "master", "^remotes/*", "^origin/pegasus$"]  # Allows regex
unwanted_branches = ["^auto_feature/*"] # Allows regex
gitlab_reponame_project_id = '4'
gitlab_host = 'https://gitlab.company.com'
reponame_repo = 'git@gitlab.company.com:RnD/reponame.git'
white_list_file = 'white.list'
db_host = 'DATABASE_HOST'
db_user = 'DATABASE_USER'
db_name = 'DATABASE_NAME'
db_table = 'TABLE_NAME'
smtp_server = 'SMTP_SERVER_ADDRESS'
cicd_team_email = 'cicd-team@company.com'
from_email = 'jenkins@company.com'
to_email = ['itai.ganot@company.com','rnd@company.com']
all_branches = []
excluded = []
branches_to_delete = {}
date_today = date.today()
since_date_interval = 6   # In months
since_date = (date_today - relativedelta(months=since_date_interval)).isoformat()
first_notice_delta = (date_today - relativedelta(weeks=1)).isoformat()
s_date = datetime.strptime(since_date, "%Y-%m-%d")
n_date = datetime.strptime(str(date_today), "%Y-%m-%d")
number_of_days = (n_date - s_date).days
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class Color:
    BLUE = '\033[1;34;48m'
    GREEN = '\033[1;32;48m'
    YELLOW = '\033[1;33;48m'
    RED = '\033[1;31;48m'
    UNDERLINE = '\033[4;37;48m'
    END = '\033[1;37;0m'


def test_white_list_file():
    if path.isfile('{}/{}'.format(getcwd(),
                                  white_list_file)):
        try:
            with open(white_list_file) as f:
                for line in f.readlines():
                    excluded.append(line.strip())
                else:
                    print('white.list file is empty!')
        except Exception as e:
            print('{}Unable to find {} file in {}, exiting! {}'.format(Color.RED,
                                                                       white_list_file,
                                                                       getcwd(),
                                                                       Color.END))
            exit(1)
    else:
        print("white.list file couldn't be found")


def identify_old_branches(db_password, gitlab_private_token):
    gl = gitlab.Gitlab(gitlab_host,
                       private_token=gitlab_private_token,
                       api_version=4,
                       ssl_verify=False)
    project = gl.projects.get(gitlab_reponame_project_id)
    for branch in project.branches.list(all=True):
        if any([re.match(pattern, branch.name) for pattern in PROTECTED_BRANCHES]):
            continue
        if any([re.match(unwanted_branch, branch.name) for unwanted_branch in unwanted_branches]):
            print('{}Removing unwanted branch: {}{}'.format(Color.YELLOW, branch, Color.END))
            insert_deleted_data(db_password, branch.name)
            delete_branch_from_gitlab(branch.name, gitlab_private_token)
            continue
        if branch.name in excluded:
            print("{}Branch '{}' is in excluded list! skipping...  {}".format(
                Color.RED, branch.name, Color.END))
            continue
        if not project.commits.list(ref_name=branch.name, since=since_date):
            committer_list = project.commits.list(ref_name=branch.name)
            last_committer = committer_list[0].committer_email if committer_list else None
            branches_to_delete[branch.name] = last_committer


def display_results(db_passwd):
    print("{}A Total of {} branches are going to be deleted:{}".format(Color.BLUE,
                                                                       len(branches_to_delete),
                                                                       Color.END))
    print("\n".join(branches_to_delete).strip("\'"))
    print('{}Inserting branches to be deleted to database... This may take some time {}'.format(Color.UNDERLINE,
                                                                                                Color.END))
    for branch_name,committer_email in branches_to_delete.items():
        insert_data(db_passwd, branch_name, committer_email)


ddef compile_email():
    email_message = """
Hi,
The following branches ({}) have not been committed to for over {} months (or {} days) and will be deleted within a week:
-------------------------------------------------------------------------------------------------------
{}
-------------------------------------------------------------------------------------------------------
If you believe any of these branches should be saved, please send an email to {} requesting them to add these branches \
to the white.list file.
Thanks
DevOps team
""".format(len(branches_to_delete), since_date_interval, number_of_days,'\n'.join(['Branch: {},'
                                                                                   'Last committer: {}'.format(k,
                                                                                                               v)
                                                                                   for k,
                                                                                       v in branches_to_delete.items()]
                                                                                  ), cicd_team_email)
    print("len branches_to_delete: {}".format(len(branches_to_delete)))
    if len(branches_to_delete) > 0:
        print("{}The following message is going to be mailed:{} {}".format(Color.YELLOW, Color.END, email_message))
        send_mail(email_message)
    else:
        print('No branches to delete, not sending email!')


def send_mail(msg):
    m = Message()
    m['From'] = from_email
    m['To'] = ', '.join(to_email)
    m['X-Priority'] = '2'
    m['Subject'] = 'Urgent! Branch Cleanup for: {} {}'.format(reponame_repo, date_today)
    m.set_payload(msg)
    server = smtplib.SMTP(host=smtp_server)
    try:
        server.sendmail(from_email, to_email, m.as_string())
    except Exception as sendmail_exception:
        print('Error: {}'.format(sendmail_exception))


def insert_data(db_passwd, branch_name, last_committer):
    try:
        connection = mysql.connector.connect(user=db_user,
                                             host=db_host,
                                             database=db_name,
                                             passwd=db_passwd)
        cursor = connection.cursor(buffered=True)
        cursor.execute(f"""
INSERT INTO {db_table} (
`branch_name`,
`source_control`,
`status`,
`last_committer`
) SELECT
%s,
'gitlab',
'to_delete',
%s
where not exists (select 1 from {db_table} where branch_name = %s and status = 'to_delete')""", (branch_name,
                                                                                                 last_committer,
                                                                                                 branch_name),
                       multi=True)
        connection.commit()
    except Exception as Ex:
        print(Ex)
    finally:
        cursor.close()
        connection.close()


def insert_deleted_data(db_passwd, branch_name):
    try:
        connection = mysql.connector.connect(user=db_user,
                                             host=db_host,
                                             database=db_name,
                                             passwd=db_passwd)
        cursor = connection.cursor(buffered=True)
        cursor.execute(f"""
INSERT INTO {db_table} (`branch_name`, `source_control`, `status`) VALUES (%s,'gitlab', 'deleted')""",
                       (branch_name,), multi=True)
        connection.commit()
    except mysql.connector.IntegrityError:
        pass
    finally:
        cursor.close()
        connection.close()


def delete_branch_from_gitlab(branch, gitlab_private_token):
    gl = gitlab.Gitlab(gitlab_host,
                       private_token=gitlab_private_token,
                       api_version=4,
                       ssl_verify=False)
    project = gl.projects.get(gitlab_reponame_project_id)
    print('{}Removing branch: {} from gitlab {}'.format(Color.YELLOW, branch, Color.END))
    project.branches.delete(branch)


def delete_branch(db_passwd, gitlab_private_token):
    connection = mysql.connector.connect(user=db_user,
                                         host=db_host,
                                         database=db_name,
                                         passwd=db_passwd)
    cursor = connection.cursor(buffered=True)
    cursor.execute(f"""
select branch_name from {db_table} where DATE(insert_date) = %s and status = 'to_delete'""",
                   (first_notice_delta,), multi=1)
    records = cursor.fetchall()
    if records:
        print('{}The following branches are going to be deleted:{}'.format(Color.GREEN,
                                                                           Color.END))
        for record in records:
            branch_name = record[0]
            if branch_name not in branches_to_delete:
                print('{}Branch name {} exists only in database{}'.format(Color.YELLOW,
                                                                          branch_name,
                                                                          Color.END))
                continue
            else:
                delete_branch_from_gitlab(branch_name, gitlab_private_token)
                try:
                    cursor.execute(f"""
update {db_table} set status = 'deleted' where branch_name = %s and status = 'to_delete'""",(branch_name,), multi=1)
                    connection.commit()
                except Exception as delete_exception:
                    print(delete_exception)
    else:
        print('No branches have been marked for deletion yet! ')
        exit(0)


def main(process, delete, db_password, gitlab_private_token):
    print("{}Looking for branches with last commit date older than: {} {}".format(Color.BLUE,
                                                                                 since_date,
                                                                                 Color.END))
    try:
        test_white_list_file()
        identify_old_branches(db_password, gitlab_private_token)
        if process:
            display_results(db_password)
            compile_email()
        elif delete:
            print('{}Finding branches that have been marked for deletion last week and deleting them{}'.format(
                Color.GREEN,
                Color.END))
            delete_branch(db_password, gitlab_private_token)
    except KeyboardInterrupt:
        print('Cancelled by user!')
    finally:
        print('Done')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Gitlab - branch cleaner for reponame repo')
    mutual_group = parser.add_argument_group(
        'mutually exclusive action arguments')
    mutually_exclusive_actions = mutual_group.add_mutually_exclusive_group()
    mutually_exclusive_actions.add_argument('-p',
                                            '--process',
                                            help='process',
                                            action='store_true')
    mutually_exclusive_actions.add_argument('-d',
                                            '--delete',
                                            help='delete',
                                            action='store_true')
    parser.add_argument('--db-password',
                        help='database password',
                        required=True)
    parser.add_argument('--gitlab-token',
                        help='Gitlab private token',
                        required=True)
    args = parser.parse_args()
    main(
        args.process,
        args.delete,
        args.db_password,
        args.gitlab_token
    )
