Instructions

cxtool.sh will
  1. Clone a repo from github.com
  2. check out a branch of interest
  3. Scan that branch with Cx CLI
  4. Generate summary report
  5. Email the summary report to a configurable list of recipients

Usage

  ./cxtool.sh conf-file [github_url git_ref]

  Arguments:
    conf-file: Required. The path to the configuration file for this run.

    github_url: Optional. The url to the gitub repo to clone. Overrides conf-file.
  
    git_ref: Optional. A string that can be checked out via git (ie branch name).
             Overrides conf-file.

Configuration
cxtool is configured by file. Create a file and specify these values.

  TEMP_DIR=/tmp/cxscan
  CxProjectName="..."
  CxServer="https://cxprivatecloud.checkmarx.net"
  CxUser="..."
  CxLocationUser="$CxUser"
  CxPassword="..."
  EMAIL_CONF="/path/to/email-recipients.conf"
  REPORT_XML="/path/to/where/CxClie/creates/reports/report.xml"
  GITHUB_REPO=https://github.com/benjaminstokes/WebGoat
  GIT_REF=challenge7

Override for GITHUB_REPO and GIT_REF is built into the cxtool CLI. To override other Cx settings, remove or comment them out from the conf-file and set them via environment variables before invoking cxtool.sh.

The email-recipients.conf file should have one email address per line in it.


Pre-requisites

* The underlying host must be configured to send mail via its smtp server, whatever that may be. cxtool sends mail via 'mail' CLI tool. If emails are not being recieved check that the OS is configured to actually send mail. For demo purposes my machine isconfigured with postfix to send via my gmail account.
* git, xpath, mail, CxCLI, and bash are required. The program checks if these dependencies are avaiable and will exit with error message when not found.
* Access to a TEMP_DIR for scratch space
* A Cx Server account and project you have access to
