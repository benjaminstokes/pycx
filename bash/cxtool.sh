#!/bin/bash
set -x

###############################################################################
#
#  ./cxtool.sh conf-file github_url git_ref
#
#
#
# cxtool.sh will
#   1. Clone a repo from github.com
#   2. Check out a branch of interest
#   3. Scan that branch via Cx CLI
#   4. Parse the Cx CLI XML report to generate summary report
#   5. Email the summary report to a configurable list of emails
#   6. Cleanup
#
# Requirements:
#   1. bash
#   2. git
#   3. xpath
#   4. access to /tmp - used as a cache and working directory
#   5. Cx CLI
#   6. mail - and OS is configured to send outgoing email via whatever
#             server is needed
#
#

# Check if tools required are available or exit
if ! [ -x "$(command -v git)" ]; then
  echo "Error: git is not installed but is required."
  exit 1
fi

if ! [ -x "$(command -v xpath)" ]; then
  echo "Error: xpath is not installed but is required."
  exit 1
fi

if ! [ -x "$(command -v mail)" ]; then
  echo "Error: mail is not installed but is required."
  exit 1
fi

if ! [ -x "$(command -v runCxConsole.sh)" ]; then
  echo "Error: runCxConsole.sh is not installed but is required."
  exit 1
fi

# Load in the conf file and apply arg overrides
if [[ -z "$1" ]]; then
  echo "Warning: no conf file provided"
fi
source "$1"
if ! [[ -z "$2" ]]; then
  GITHUB_REPO="$2"
fi
if ! [[ -z "$3" ]]; then
  GIT_REF="$3"
fi

# Set up some environment and check inputs
GIT_REPO_NAME=$(basename "$GITHUB_REPO")
TEMP_DIR=/tmp/cxscan
CxComment="Scanning $GITHUB_REPO#$GIT_REF via cxtool.sh"
CxLocationPath="$TEMP_DIR/$GIT_REPO_NAME"

if [[ -z "$GITHUB_REPO" ]]; then
    echo "GITHUB_REPO env variable must be set" 1>&2
    exit 1
fi

if [[ -z "$GIT_REF" ]]; then
    echo "GIT_REF environment variable must be set. This ref will scanned." 1>&2
    exit 1
fi

if [[ -z "$CxProjectName" ]]; then
    echo "CxProjectName environment variable must be set" 1>&2
    exit 1
fi
if [[ -z "$CxServer" ]]; then
    echo "CxServer environment variable must be set." 1>&2
    exit 1
fi
if [[ -z "$CxUser" ]]; then
    echo "CxUser environment variable must bet set. " 1>&2
    exit 1
fi
if [[ -z "$CxPassword" ]]; then
    echo "CxPassword environment variable must be set." 1>&2
    exit 1
fi
if [[ -z "$REPORT_XML" ]]; then
  echo "REPORT_XML environment variable must be set." 1>&2
  exit 1
fi
if [[ -z "$EMAIL_CONF" ]]; then
  echo "EMAIL_CONF  environment variable must be set." 1>&2
  exit 1
fi

###
### Get the code from github and checkout the target branch
###
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"
git clone "$GITHUB_REPO"
cd "$GIT_REPO_NAME"
git checkout "$GIT_REF"

# Run CxSAST via CLI
runCxConsole.sh scan -ProjectName "$CxProjectName" -CxServer "$CxServer" -cxUser "$CxUser" -cxPassword "$CxPassword" -locationType "folder" -locationPath "$CxLocationPath" -preset Default -v -comment "$CxComment" -SASTHigh 1 -SASTMedium 2 -SASTLow 3 -Log "$TEMP_DIR/cx.log" -ReportXML "report.xml" -ReportPDF "report.pdf" -ReportCSV "report.csv" -ReportRTF "report.rtf"

# Analyze XML results using xpath tool
# $TEMP_DIR/scan-report.html will contain html report that is generated during
# analysis steps. 

count_total=$(xpath -e 'count(//Query/Result)' "$REPORT_XML" 2>/dev/null )
count_severity_high=$(xpath -e 'count(//Query/Result[@Severity="High"])' "$REPORT_XML" 2>/dev/null)
count_severity_medium=$(xpath -e 'count(//Query/Result[@Severity="Medium"])' "$REPORT_XML" 2>/dev/null)
count_severity_low=$(xpath -e 'count(//Query/Result[@Severity="Low"])' "$REPORT_XML" 2>/dev/null)

echo "Found $count_total total issues."
echo "  High:   $count_severity_high"
echo "  Medium: $count_severity_medium"
echo "  Low:    $count_severity_low"

touch "$TEMP_DIR/scan-report.html"
echo "<html><head><title>Scan summary for $GITHUB_REPO#$GIT_REF</title></head>" > "$TEMP_DIR/scan-report.html"
echo "<body><h1>Scan summary for $GITHUB_REPO#$GIT_REF</h1>" >> "$TEMP_DIR/scan-report.html"
echo "<h2>Results per severity</h2>" >> "$TEMP_DIR/scan-report.html"
echo "<table><tr><th>Total</th><th>High</th><th>Medium</th><th>Low</th></tr>" >> "$TEMP_DIR/scan-report.html"
echo "<tr><td>$count_total</td><td>$count_severity_high</td><td>$count_severity_medium</td><td>$count_severity_low</td></tr></table>" >> "$TEMP_DIR/scan-report.html"

echo "<h2>Results per vulnerability</h2>" >> "$TEMP_DIR/scan-report.html"
echo "<table><tr><th>Vulnerability</th><th>Count</th></tr>" >> "$TEMP_DIR/scan-report.html"


echo " "
echo "Findings by type:"
query_count=$(xpath -e "count(//Query)" "$REPORT_XML" 2>/dev/null)
for i in $(seq 1 $query_count); do 
  type_name=$(xpath -e "string(//Query[$i]/@name)" "$REPORT_XML" 2>/dev/null)
  type_cweId=$(xpath -e "string(//Query[$i]/@cweId)" "$REPORT_XML" 2>/dev/null)
  type_count=$(xpath -e "count(//Query[$i]/Result)" "$REPORT_XML" 2>/dev/null)
  echo "  $type_count  - CWE $type_cweId $type_name"
  echo "<tr><td>CWE $type_cweId $type_name</td><td>$type_count</td></tr>" >> "$TEMP_DIR/scan-report.html"
done

echo "</table></body></html>" >> "$TEMP_DIR/scan-report.html"


# Send Email
while read email
do
  mail --append="Content-type: text/html" -s "Scan results" $email < /tmp/cxscan/scan-report.html
  echo "email sent to $email"
done < "$EMAIL_CONF"
 
