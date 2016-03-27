# zenhub-extract

Extracts information about issues from GitHub and ZenHub and writes them
to a CSV file for further analysis. Takes a milestone name/number and
a date range to get the tickets for that milestone and/or closed within
that date range.

## Usage

See help message:
```
# bundle exec bin/extract.rb --help

Usage: bin/extract.rb [options]

Script that downloads issue data from GitHub and ZenHub to be able to plot
velocity and burndown. Pulls all issues belonging to the specified milestone,
or which were closed in the specified date range.

    -c, --config FILE                Configuration file
    -o, --output FILE                Output CSV file
    -m, --milestone name             Milestone name
    -s, --start_date date            Start of date range for closed issues
    -e, --end_date date              End of date range for closed issues
```

## Example

```
$ bundle exec bin/extract.rb -m 9 -s '2016-03-16' -e '2016-03-30'
[2016-03-26 17:30:33] Found 68 issues for milestone 9
[2016-03-26 17:30:36] Found 62 issues for date range 2016-03-16T07:00:00+00:00 - 2016-03-30T07:00:00+00:00
[2016-03-26 17:30:37] Downloading Zenhub data for #1088 Big bug ticket
...
[2016-03-26 17:28:43] Writing 207 rows to output.csv
$ head -n 3 output.csv
number,title,state,assignee,labels,milestone,created_at,closed_at,estimate,pipeline
1088,Cool awesome feature,open,joe_coder,"",Sprint 1,2016-03-24T17:03:38Z,,2,In Progress
1089,Bad bug name,closed,joe_coder,"",Sprint 1,2016-03-25T18:13:32,,2,Closed
```
